#!/usr/bin/env python3
"""Load an SBIR/STTR award export into a project's ontology. Change request #46.

The CSV is already structured — every field is in a named column — so nothing here
asks a model anything. Sending 219,503 rows through an extraction prompt would pay
real money to recover information that is already explicit.

Run from the host, not the container:

    python3 script/import_award_data.py --limit 1000 --dry-run
    python3 script/import_award_data.py --limit 1000
    python3 script/import_award_data.py

Postgres publishes no port, so the database is reached by piping SQL through
`docker compose exec -T postgres psql`. Standard library only: no driver to install
and no image to rebuild.
"""

import argparse
import csv
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

DEFAULT_PSQL = "docker compose exec -T postgres psql -U postgres -d app_development"

# Names that are a placeholder for a person rather than a person. Recording these
# would put "BLANK BLANK" in the graph as an employee of forty companies.
JUNK_NAMES = {
    "", "blank", "blank blank", "n/a", "na", "none", "tbd", "unknown",
    "afwerx afwerx", "sbir sbir", "sttr sttr", "test test",
}

WHITESPACE = re.compile(r"\s+")


# --------------------------------------------------------------------------- #
# The ontology this import needs. Anything already in the project is reused by
# name; only what is missing is created. Attribute names that already exist on
# F-DoD (identifier, title, start_date, end_date, value_usd, first_name,
# last_name, acronym) are deliberately spelled the same so they are filled
# rather than shadowed by a second column meaning the same thing.
# --------------------------------------------------------------------------- #

ENTITY_TYPES = {
    "Organization": "A company, university, research institution or government body.",
    "Person": "A named individual — a principal investigator, a contact, a point of contact.",
    "Contract": "One award: a funding instrument with a value, a period and a scope of work.",
}

# name -> (value_type, shown on the index table)
ATTRIBUTES = {
    "Organization": {
        "uei": ("string", True),
        "duns": ("string", False),
        "website": ("string", True),
        "street_address": ("string", False),
        "city": ("string", True),
        "state": ("string", True),
        "postal_code": ("string", False),
        "employee_count": ("int", True),
        "hubzone_owned": ("string", False),
        "disadvantaged_owned": ("string", False),
        "woman_owned": ("string", False),
        "organization_kind": ("string", True),
        "import_key": ("string", False),
    },
    "Person": {
        "first_name": ("string", True),
        "last_name": ("string", True),
        "title": ("string", True),
        "phone": ("string", False),
        "email": ("string", True),
        "import_key": ("string", False),
    },
    "Contract": {
        "identifier": ("string", True),
        "title": ("string", False),
        "start_date": ("datetime", True),
        "end_date": ("datetime", True),
        "value_usd": ("float", True),
        "agency_tracking_number": ("string", False),
        "phase": ("string", True),
        "program": ("string", True),
        "solicitation_number": ("string", False),
        "solicitation_year": ("int", False),
        "solicitation_close_date": ("datetime", False),
        "proposal_receipt_date": ("datetime", False),
        "notification_date": ("datetime", False),
        "topic_code": ("string", False),
        "award_year": ("int", True),
        "abstract": ("string", False),
        "import_key": ("string", False),
    },
}

# Whether a thing of this type is the same thing as one already recorded under
# the same name. An organization is: "SLIP ROBOTICS INC." written twice is one
# company, which is also the rule `ExtractionApplier` matches on. An award is
# not: a company's Phase I and Phase II of one project share a title, a contract
# number and a topic, and differ in the two things that matter — the money and
# the period. Merging them on their name lost 22,581 awards on the first run.
MERGE_BY_NAME = {"Organization": True, "Person": True, "Contract": False}

# name -> (from type, to type, description)
RELATIONSHIP_TYPES = {
    "Awardee": ("Contract", "Organization", "The organization the award was made to."),
    "Awarding Agency": ("Contract", "Organization", "The agency or branch that funded the award."),
    "Research Institution": ("Contract", "Organization", "The research institution partnered on the award."),
    "Principal Investigator": ("Contract", "Person", "The person leading the work under the award."),
    "Technical Contact": ("Contract", "Person", "The person named as the technical contact for the award."),
    "Research Contact": ("Contract", "Person", "The research institution's point of contact for the award."),
    "Employment": ("Person", "Organization", "The person works for the organization."),
    "Subsidiary": ("Organization", "Organization", "The organization is a part of the other organization."),
}


# --------------------------------------------------------------------------- #
# Normalizing
# --------------------------------------------------------------------------- #

def clean(value):
    """One line of text with its whitespace collapsed, or ''."""
    if value is None:
        return ""
    return WHITESPACE.sub(" ", value.replace("\x00", "")).strip()


def norm(value):
    """The identity of a name: casefolded, whitespace collapsed.

    The same rule `ExtractionApplier` matches on, so an extraction run later
    lands on what this import wrote instead of duplicating it.
    """
    return clean(value).casefold()


def as_int(value):
    value = clean(value)
    if not value:
        return None
    try:
        return int(float(value))
    except ValueError:
        return None


def as_float(value):
    value = clean(value)
    if not value:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def as_datetime(value):
    """The export writes dates as YYYY-MM-DD; anything else is not a date."""
    value = clean(value)
    if not value:
        return None
    for fmt in ("%Y-%m-%d", "%m/%d/%Y", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(value, fmt).strftime("%Y-%m-%d 00:00:00")
        except ValueError:
            continue
    return None


def as_phone(value):
    """`() -` and `--` are the export's way of writing "no phone"."""
    value = clean(value)
    return "" if not re.search(r"\d", value) else value


def as_email(value):
    value = clean(value).lower()
    return value if "@" in value and not value.startswith("blank.") else ""


def is_person(name):
    return norm(name) not in JUNK_NAMES and len(clean(name)) > 1


def split_name(name):
    """First and last, from a name written as free text.

    The export writes "Christopher  Heffelfi" — first, a doubled space where a
    middle name would be, last. Anything cleverer than first-token/last-token
    would be guessing.
    """
    parts = clean(name).split(" ")
    if len(parts) == 1:
        return parts[0], ""
    return parts[0], parts[-1]


def copy_escape(value):
    """One field for COPY's text format."""
    if value is None:
        return r"\N"
    return (
        str(value)
        .replace("\\", "\\\\")
        .replace("\t", "\\t")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )


# --------------------------------------------------------------------------- #
# Talking to Postgres
# --------------------------------------------------------------------------- #

class Psql:
    def __init__(self, command):
        self.command = command.split()

    def rows(self, sql):
        """Query, as a list of lists of strings. Empty string means NULL."""
        result = subprocess.run(
            self.command + ["-v", "ON_ERROR_STOP=1", "-qAt", "-F", "\t", "-c", sql],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            sys.exit(f"psql failed:\n{result.stderr}")
        return [line.split("\t") for line in result.stdout.splitlines() if line]

    def execute(self, sql):
        self.rows(sql)

    def stream(self, chunks):
        """Feed a SQL script — COPY commands and their inline data — to one psql.

        One process, one transaction: either the whole import lands or none of
        it does, and the COPY data never has to exist as a single string in
        memory.
        """
        process = subprocess.Popen(
            self.command + ["-v", "ON_ERROR_STOP=1", "-q", "-f", "-"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True,
        )
        try:
            for chunk in chunks:
                process.stdin.write(chunk)
        except BrokenPipeError:
            pass
        out, err = process.communicate()
        if process.returncode != 0:
            sys.exit(f"import failed:\n{out}\n{err}")
        return out


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


# --------------------------------------------------------------------------- #
# The ontology, made sure of
# --------------------------------------------------------------------------- #

def ensure_ontology(db, project_id):
    """Create the types and attributes this import needs, if the project lacks them.

    Idempotent: everything is an INSERT ... WHERE NOT EXISTS, matched on the same
    case-insensitive name the models validate uniqueness on.
    """
    statements = []
    for name, description in ENTITY_TYPES.items():
        statements.append(
            f"INSERT INTO entity_types (project_id, name, description, created_at, updated_at) "
            f"SELECT {project_id}, {quote(name)}, {quote(description)}, now(), now() "
            f"WHERE NOT EXISTS (SELECT 1 FROM entity_types WHERE project_id = {project_id} "
            f"AND lower(name) = lower({quote(name)}));"
        )
    db.execute("\n".join(statements))

    types = {name: int(id_) for id_, name in db.rows(
        f"SELECT id, name FROM entity_types WHERE project_id = {project_id}"
    )}

    statements = []
    for type_name, attributes in ATTRIBUTES.items():
        type_id = types[type_name]
        for attr, (value_type, on_index) in attributes.items():
            statements.append(
                f"INSERT INTO entity_type_attributes (project_id, entity_type_id, name, value_type, "
                f"is_disabled, is_displayed_on_index, created_at, updated_at) "
                f"SELECT {project_id}, {type_id}, {quote(attr)}, {quote(value_type)}, false, "
                f"{'true' if on_index else 'false'}, now(), now() "
                f"WHERE NOT EXISTS (SELECT 1 FROM entity_type_attributes "
                f"WHERE entity_type_id = {type_id} AND name = {quote(attr)});"
            )
    for name, (from_type, to_type, description) in RELATIONSHIP_TYPES.items():
        statements.append(
            f"INSERT INTO relationship_types (project_id, name, description, from_entity_type_id, "
            f"to_entity_type_id, created_at, updated_at) "
            f"SELECT {project_id}, {quote(name)}, {quote(description)}, {types[from_type]}, "
            f"{types[to_type]}, now(), now() "
            f"WHERE NOT EXISTS (SELECT 1 FROM relationship_types WHERE project_id = {project_id} "
            f"AND lower(name) = lower({quote(name)}));"
        )
    db.execute("\n".join(statements))

    attribute_ids = {}
    for type_name_id, attr, attr_id in db.rows(
        f"SELECT entity_type_id, name, id FROM entity_type_attributes WHERE project_id = {project_id}"
    ):
        attribute_ids[(int(type_name_id), attr)] = int(attr_id)

    relationship_ids = {name: int(id_) for id_, name in db.rows(
        f"SELECT id, name FROM relationship_types WHERE project_id = {project_id}"
    )}
    return types, attribute_ids, relationship_ids


def load_existing(db, project_id, types, attribute_ids):
    """import_key -> entity id, for everything a previous run wrote.

    This is what makes a second run a no-op rather than a second copy of the
    graph. Entities with no import_key (recorded by hand, or by an extraction
    run) are matched on their normalized name instead, so the import joins onto
    them rather than shadowing them.
    """
    existing = {}
    key_attributes = [attribute_ids[(types[name], "import_key")] for name in ENTITY_TYPES]
    rows = db.rows(
        f"SELECT v.string_value, v.entity_id FROM entity_attribute_values v "
        f"WHERE v.project_id = {project_id} "
        f"AND v.entity_type_attribute_id IN ({','.join(str(i) for i in key_attributes)}) "
        f"AND v.string_value IS NOT NULL"
    )
    for key, entity_id in rows:
        existing[key] = int(entity_id)

    by_name = {}
    for entity_id, type_id, name in db.rows(
        f"SELECT id, entity_type_id, name FROM entities "
        f"WHERE project_id = {project_id} AND deleted_at IS NULL"
    ):
        by_name.setdefault((int(type_id), norm(name)), int(entity_id))
    return existing, by_name


# --------------------------------------------------------------------------- #
# The import itself
# --------------------------------------------------------------------------- #

class Importer:
    def __init__(self, project_id, types, attribute_ids, relationship_ids,
                 existing_keys, existing_names, next_entity_id, out_dir, stamp):
        self.project_id = project_id
        self.stamp = stamp
        self.types = types
        self.attribute_ids = attribute_ids
        self.relationship_ids = relationship_ids
        self.keys = dict(existing_keys)          # import_key -> entity id
        self.by_name = existing_names            # (type id, normalized name) -> entity id
        self.next_id = next_entity_id
        self.created = {name: 0 for name in ENTITY_TYPES}
        self.value_count = 0
        self.relationship_count = 0
        self.seen_relationships = set()

        self.entities_file = open(os.path.join(out_dir, "entities.tsv"), "w", encoding="utf-8")
        self.values_file = open(os.path.join(out_dir, "values.tsv"), "w", encoding="utf-8")
        self.relationships_file = open(os.path.join(out_dir, "relationships.tsv"), "w", encoding="utf-8")

    def close(self):
        for handle in (self.entities_file, self.values_file, self.relationships_file):
            handle.close()

    def entity(self, type_name, key, name, attributes):
        """The id for this thing, creating it and its values the first time.

        A key already seen — in this run or a previous one — returns the same id
        and records nothing further, so the twentieth award for a company does
        not rewrite the company.
        """
        known = self.keys.get(key)
        if known:
            return known

        type_id = self.types[type_name]
        name = clean(name)[:1000] or key
        entity_id = self.by_name.get((type_id, norm(name))) if MERGE_BY_NAME[type_name] else None
        if entity_id is None:
            entity_id = self.next_id
            self.next_id += 1
            self.created[type_name] += 1
            if MERGE_BY_NAME[type_name]:
                self.by_name[(type_id, norm(name))] = entity_id
            self.entities_file.write(
                "\t".join(copy_escape(v) for v in
                          (entity_id, self.project_id, type_id, name,
                           self.stamp, self.stamp)) + "\n"
            )

        self.keys[key] = entity_id
        self.value(type_name, entity_id, "import_key", key)
        for attr, value in attributes.items():
            self.value(type_name, entity_id, attr, value)
        return entity_id

    def value(self, type_name, entity_id, attr, value):
        """One attribute value, in the typed column its declaration names."""
        value_type = ATTRIBUTES[type_name][attr][0]
        columns = [None, None, None, None]  # string, int, float, datetime
        if value_type == "string":
            value = clean(value)
            if not value:
                return
            columns[0] = value
        elif value_type == "int":
            parsed = as_int(value)
            if parsed is None:
                return
            columns[1] = parsed
        elif value_type == "float":
            parsed = as_float(value)
            if parsed is None:
                return
            columns[2] = parsed
        elif value_type == "datetime":
            parsed = as_datetime(value)
            if parsed is None:
                return
            columns[3] = parsed

        attr_id = self.attribute_ids[(self.types[type_name], attr)]
        self.values_file.write(
            "\t".join(copy_escape(v) for v in
                      ([self.project_id, entity_id, attr_id] + columns)) + "\n"
        )
        self.value_count += 1

    def relate(self, type_name, from_id, to_id):
        if not from_id or not to_id or from_id == to_id:
            return
        type_id = self.relationship_ids[type_name]
        edge = (type_id, from_id, to_id)
        if edge in self.seen_relationships:
            return
        self.seen_relationships.add(edge)
        self.relationships_file.write(
            "\t".join(copy_escape(v) for v in (self.project_id, type_id, from_id, to_id)) + "\n"
        )
        self.relationship_count += 1


def survey(path, limit):
    """Pass one: what the second pass needs to know before it can name things.

    - the UEI of a company, so rows that leave it blank still record it
    - the titles that cover more than one award, so those contracts can be told
      apart on screen by more than a name they share
    """
    names_to_uei = {}
    title_counts = {}
    with open(path, newline="", encoding="utf-8-sig") as handle:
        for index, row in enumerate(csv.DictReader(handle)):
            if limit and index >= limit:
                break
            company = norm(row.get("Company"))
            uei = clean(row.get("UEI"))
            if company and uei:
                names_to_uei.setdefault(company, set()).add(uei)
            title = norm(row.get("Award Title"))
            if title:
                title_counts[title] = title_counts.get(title, 0) + 1

    # Only an unambiguous UEI is worth filling in. A name with two of them is a
    # name two companies share, and picking one would attach the wrong company's
    # identifier to half the awards.
    uei_by_name = {name: next(iter(ueis)) for name, ueis in names_to_uei.items() if len(ueis) == 1}
    repeated_titles = {title for title, count in title_counts.items() if count > 1}
    return uei_by_name, repeated_titles


def award_key(row, company_key):
    """What makes one award one award.

    Not the contract number: a quarter of the rows leave it blank and it is
    reused across a company's Phase I and Phase II, which are two awards with
    two amounts. Phase and year are part of identity for that reason.
    """
    # Cleaned as a whole, because the key has to survive a round trip through
    # the database to be worth anything: it is stored as an attribute value, and
    # `value()` cleans what it stores. Cutting the title at 120 characters can
    # leave a trailing space, and a key that comes back one space shorter than it
    # went in matches nothing — which is how a re-run created 1,152 contracts a
    # second time.
    return clean("award:" + "|".join([
        clean(row.get("Contract")),
        clean(row.get("Agency Tracking Number")),
        clean(row.get("Phase")),
        clean(row.get("Award Year")),
        company_key,
        norm(row.get("Award Title"))[:120],
    ]))


def import_rows(path, limit, importer, uei_by_name, repeated_titles, report_every=25000):
    seen_award_keys = {}
    rows_read = 0

    with open(path, newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            if limit and rows_read >= limit:
                break
            rows_read += 1
            if rows_read % report_every == 0:
                print(f"  {rows_read:,} rows read, "
                      f"{sum(importer.created.values()):,} entities, "
                      f"{importer.relationship_count:,} relationships", flush=True)

            # --- the company ------------------------------------------------
            company_name = clean(row.get("Company"))
            if not company_name:
                continue
            company_norm = norm(company_name)
            company_key = "org:name:" + company_norm
            company_id = importer.entity("Organization", company_key, company_name, {
                "uei": clean(row.get("UEI")) or uei_by_name.get(company_norm, ""),
                "duns": clean(row.get("Duns")),
                "website": clean(row.get("Company Website")),
                "street_address": " ".join(
                    p for p in (clean(row.get("Address1")), clean(row.get("Address2"))) if p
                ),
                "city": clean(row.get("City")),
                "state": clean(row.get("State")),
                "postal_code": clean(row.get("Zip")),
                "employee_count": row.get("Number Employees"),
                "hubzone_owned": clean(row.get("HUBZone Owned")),
                "disadvantaged_owned": clean(row.get("Socially and Economically Disadvantaged")),
                "woman_owned": clean(row.get("Woman Owned")),
                "organization_kind": "Company",
            })

            # --- the agency, and the branch under it ------------------------
            agency_name = clean(row.get("Agency"))
            agency_id = None
            if agency_name:
                agency_id = importer.entity(
                    "Organization", "org:agency:" + norm(agency_name), agency_name,
                    {"organization_kind": "Agency"},
                )
            branch_name = clean(row.get("Branch"))
            branch_id = None
            if branch_name and agency_name:
                branch_id = importer.entity(
                    "Organization",
                    f"org:branch:{norm(agency_name)}|{norm(branch_name)}",
                    branch_name, {"organization_kind": "Branch"},
                )
                importer.relate("Subsidiary", branch_id, agency_id)

            # --- the research institution -----------------------------------
            ri_name = clean(row.get("RI Name"))
            ri_id = None
            if ri_name and norm(ri_name) not in JUNK_NAMES:
                ri_id = importer.entity(
                    "Organization", "org:name:" + norm(ri_name), ri_name,
                    {"organization_kind": "Research Institution"},
                )

            # --- the award ---------------------------------------------------
            title = clean(row.get("Award Title")) or "Untitled award"
            identifier = clean(row.get("Contract")) or clean(row.get("Agency Tracking Number"))
            key = award_key(row, company_key)
            # The export repeats an award key on 798 of 219,503 rows. Numbering
            # the repeats keeps a re-run stable, which a random id would not.
            seen_award_keys[key] = seen_award_keys.get(key, 0) + 1
            if seen_award_keys[key] > 1:
                key = f"{key}#{seen_award_keys[key]}"

            display = title
            if norm(title) in repeated_titles:
                # Enough to tell one award from another at a glance. The contract
                # number alone is not: DE-AR0001963 covers a Phase I and two
                # Phase II awards under one title.
                marker = ", ".join(p for p in (
                    identifier, clean(row.get("Phase")), clean(row.get("Award Year"))
                ) if p)
                if marker:
                    display = f"{title} ({marker})"

            contract_id = importer.entity("Contract", key, display, {
                "identifier": identifier,
                "title": title,
                "agency_tracking_number": clean(row.get("Agency Tracking Number")),
                "phase": clean(row.get("Phase")),
                "program": clean(row.get("Program")),
                "start_date": row.get("Proposal Award Date"),
                "end_date": row.get("Contract End Date"),
                "value_usd": row.get("Award Amount"),
                "solicitation_number": clean(row.get("Solicitation Number")),
                "solicitation_year": row.get("Solicitation Year"),
                "solicitation_close_date": row.get("Solicitation Close Date"),
                "proposal_receipt_date": row.get("Proposal Receipt Date"),
                "notification_date": row.get("Date of Notification"),
                "topic_code": clean(row.get("Topic Code")),
                "award_year": row.get("Award Year"),
                "abstract": clean(row.get("Abstract")),
            })

            importer.relate("Awardee", contract_id, company_id)
            if agency_id:
                importer.relate("Awarding Agency", contract_id, agency_id)
            if branch_id:
                importer.relate("Awarding Agency", contract_id, branch_id)
            if ri_id:
                importer.relate("Research Institution", contract_id, ri_id)

            # --- the people --------------------------------------------------
            people = (
                ("PI Name", "PI Title", "PI Phone", "PI Email",
                 "Principal Investigator", company_id),
                ("Contact Name", "Contact Title", "Contact Phone", "Contact Email",
                 "Technical Contact", company_id),
                ("RI POC Name", None, "RI POC Phone", None,
                 "Research Contact", ri_id),
            )
            for name_col, title_col, phone_col, email_col, edge, employer_id in people:
                person_name = clean(row.get(name_col))
                if not is_person(person_name):
                    continue
                email = as_email(row.get(email_col)) if email_col else ""
                first, last = split_name(person_name)
                person_id = importer.entity(
                    "Person", "person:name:" + norm(person_name), person_name,
                    {
                        "first_name": first,
                        "last_name": last,
                        "title": clean(row.get(title_col)) if title_col else "",
                        "phone": as_phone(row.get(phone_col)) if phone_col else "",
                        "email": email,
                    },
                )
                importer.relate(edge, contract_id, person_id)
                if employer_id:
                    importer.relate("Employment", person_id, employer_id)

    return rows_read


# --------------------------------------------------------------------------- #
# Writing
# --------------------------------------------------------------------------- #

def write_stream(project_id, out_dir, entity_count, base_id):
    """The whole write, as one SQL script for one psql, in one transaction.

    COPY carries the bulk; the staged rows then go in set-based, so a value that
    already exists is updated in place and a relationship that already exists is
    not written twice.
    """
    yield "BEGIN;\n"
    yield "SET LOCAL work_mem = '256MB';\n"
    yield ("CREATE TEMP TABLE stg_value (project_id bigint, entity_id bigint, "
           "entity_type_attribute_id bigint, string_value text, int_value integer, "
           "float_value double precision, datetime_value timestamp) ON COMMIT DROP;\n")
    yield ("CREATE TEMP TABLE stg_relationship (project_id bigint, relationship_type_id bigint, "
           "from_entity_id bigint, to_entity_id bigint) ON COMMIT DROP;\n")

    yield ("COPY entities (id, project_id, entity_type_id, name, created_at, updated_at) "
           "FROM stdin;\n")
    with open(os.path.join(out_dir, "entities.tsv"), encoding="utf-8") as handle:
        for line in handle:
            yield line
    yield "\\.\n"

    yield "COPY stg_value FROM stdin;\n"
    with open(os.path.join(out_dir, "values.tsv"), encoding="utf-8") as handle:
        for line in handle:
            yield line
    yield "\\.\n"

    yield "COPY stg_relationship FROM stdin;\n"
    with open(os.path.join(out_dir, "relationships.tsv"), encoding="utf-8") as handle:
        for line in handle:
            yield line
    yield "\\.\n"

    # The last value for an entity and attribute wins, which is the last row of
    # the CSV that mentioned it. DISTINCT ON is what keeps ON CONFLICT from
    # failing on a batch that carries the same pair twice.
    yield """
INSERT INTO entity_attribute_values
  (project_id, entity_id, entity_type_attribute_id,
   string_value, int_value, float_value, datetime_value, created_at, updated_at)
SELECT DISTINCT ON (entity_id, entity_type_attribute_id)
  project_id, entity_id, entity_type_attribute_id,
  string_value, int_value, float_value, datetime_value, now(), now()
FROM stg_value
ORDER BY entity_id, entity_type_attribute_id
ON CONFLICT (entity_id, entity_type_attribute_id) DO UPDATE SET
  string_value = COALESCE(EXCLUDED.string_value, entity_attribute_values.string_value),
  int_value = COALESCE(EXCLUDED.int_value, entity_attribute_values.int_value),
  float_value = COALESCE(EXCLUDED.float_value, entity_attribute_values.float_value),
  datetime_value = COALESCE(EXCLUDED.datetime_value, entity_attribute_values.datetime_value),
  updated_at = now();
"""

    yield """
INSERT INTO relationships
  (project_id, relationship_type_id, from_entity_id, to_entity_id, created_at, updated_at)
SELECT s.project_id, s.relationship_type_id, s.from_entity_id, s.to_entity_id, now(), now()
FROM stg_relationship s
WHERE NOT EXISTS (
  SELECT 1 FROM relationships r
  WHERE r.relationship_type_id = s.relationship_type_id
    AND r.from_entity_id = s.from_entity_id
    AND r.to_entity_id = s.to_entity_id
);
"""

    # Rails carries on from where the import stopped. Without this the next
    # entity created through the app collides with one this script wrote.
    if entity_count:
        yield f"SELECT setval('entities_id_seq', {base_id + entity_count});\n"
    yield "COMMIT;\n"


# --------------------------------------------------------------------------- #

def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--csv", default="tmp/award_data.csv")
    parser.add_argument("--project", default="F-DoD")
    parser.add_argument("--limit", type=int, default=0, help="only the first N award rows")
    parser.add_argument("--dry-run", action="store_true",
                        help="parse and report; writes no entities, values or relationships "
                             "(the project's types and attributes are still created, because "
                             "their ids are what the parse resolves against)")
    parser.add_argument("--psql", default=DEFAULT_PSQL, help=f"default: {DEFAULT_PSQL}")
    args = parser.parse_args()

    csv.field_size_limit(10 ** 9)

    db = Psql(args.psql)
    rows = db.rows(f"SELECT id FROM projects WHERE name = {quote(args.project)}")
    if not rows:
        sys.exit(f"no project named {args.project!r}")
    project_id = int(rows[0][0])
    print(f"project {args.project!r} (#{project_id})")

    types, attribute_ids, relationship_ids = ensure_ontology(db, project_id)
    existing_keys, existing_names = load_existing(db, project_id, types, attribute_ids)
    print(f"ontology ready — {len(existing_keys):,} entities already imported")

    base_id = int(db.rows("SELECT COALESCE(MAX(id), 0) FROM entities")[0][0])

    print("pass 1: surveying the export")
    uei_by_name, repeated_titles = survey(args.csv, args.limit)
    print(f"  {len(uei_by_name):,} companies with an unambiguous UEI, "
          f"{len(repeated_titles):,} titles used more than once")

    with tempfile.TemporaryDirectory(prefix="award-import-") as out_dir:
        # UTC, because that is what every other timestamp in this database is.
        # Stamping local time buried the import five hours in the past.
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
        importer = Importer(project_id, types, attribute_ids, relationship_ids,
                            existing_keys, existing_names, base_id + 1, out_dir, stamp)
        print("pass 2: building entities, values and relationships")
        rows_read = import_rows(args.csv, args.limit, importer, uei_by_name, repeated_titles)
        importer.close()

        created = sum(importer.created.values())
        print(f"\n{rows_read:,} award rows read")
        for name, count in importer.created.items():
            print(f"  {count:>9,} new {name.lower()} entities")
        print(f"  {importer.value_count:>9,} attribute values")
        print(f"  {importer.relationship_count:>9,} relationships")

        if args.dry_run:
            print("\n--dry-run: nothing written")
            return

        print("\nwriting")
        db.stream(write_stream(project_id, out_dir, created, base_id))
        print("done")


if __name__ == "__main__":
    main()
