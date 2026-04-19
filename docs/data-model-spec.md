# Data Model Specification

This document defines the repeating shape used by every tier 1 knowledge entity in the
application and the relationships between them. Implement these concepts when adding new
entities so the codebase.

The canonical example is `Person` / `PersonDetail`. Everything below generalises
that pattern.

---

## 1. Tier 1 Knowledge Entity

A **tier 1 knowledge entity** is a real-world subject the system tracks (a person, an
organisation, a place, etc.).

**Rules**

- The entity table has **no domain attributes** except the `current_detail_id`
  pointer (see below). It exists only as a stable identity
  (primary key + `created_at` / `updated_at` + `current_detail_id`).
- All facts about the entity live in a companion **Detail** table (see §2).
- The Ruby class is singular (`Person`), the table is Rails-pluralised
  (`people`).
- Model declares `has_many :<entity>_details, dependent: :destroy`.
- Model declares `belongs_to :current_detail, class_name: "<Entity>Detail", optional: true`.
  The entity table carries a nullable FK `current_detail_id` pointing at the
  row in `<entity>_details` that should be treated as the authoritative /
  "now" record. Views and non-historical queries read through this pointer
  rather than sorting by `as_of` on the fly.

**Example**

```ruby
class Person < ApplicationRecord
  has_many :person_details, dependent: :destroy
  belongs_to :current_detail, class_name: "PersonDetail", optional: true
end
```

```ruby
create_table :people do |t|
  t.timestamps
end

add_reference :people, :current_detail,
  foreign_key: { to_table: :person_details }, null: true
```

**Maintaining `current_detail_id`**

The pointer is set explicitly — not inferred on every read. When a new
Detail is inserted with a later `as_of` than the currently-pointed row,
the parent's `current_detail_id` should be updated to point at the new
row. The enforcement mechanism (a callback on the Detail, an explicit
service object, a DB trigger, …) is an application-level choice — pick
one and apply it consistently across all tier 1 entities.

---

## 2. Entity Detail

A **Detail** record is a time-stamped, confidence-scored *assertion* about a
tier 1 entity. An entity may have many details over time and from many sources;
the "current" view of an entity is derived by picking the most recent detail
(usually ordered by `as_of desc`).

**Required columns**

| Column                  | Type       | Purpose                                                        |
|-------------------------|------------|----------------------------------------------------------------|
| `<entity>_id`           | FK, NOT NULL | Reference to the parent entity.                              |
| `additional_attributes` | `jsonb`, NOT NULL, default `{}` | Property bag for open-ended attributes (see §2a). |
| `confidence_tenths`     | `integer`  | Confidence in this assertion, in tenths of a percent. `1` = 0.1%, `1000` = 100%. |
| `as_of`                 | `datetime` | When the assertion is effective (not when it was recorded — `created_at` covers that). |
| `source_processing_report_id` | FK, NOT NULL | The `SourceProcessingReport` that produced this detail — i.e., which skill revision was run against which source to extract these facts. See §2b. |
| `created_at` / `updated_at` | `datetime` | Standard Rails timestamps.                               |

**Typed columns**

Add columns on the Detail table for attributes that are always or often
present and worth querying directly (e.g. `first_name`, `last_name` on
`PersonDetail`). Everything else goes into `additional_attributes`.

### §2a. `additional_attributes` — the property bag

`additional_attributes` has the **same shape on every tier 1 entity's
Detail table**:

- A single `jsonb` column, NOT NULL, default `{}`.
- A **flat map from string keys to scalar values** (string, number, boolean).
  No nested objects. No arrays.
- Keys are lowercase `snake_case`. No leading/trailing whitespace.
- Absence of a key means "unknown", not "null". Do not store explicit
  `null` values — omit the key instead.
- The set of *meaningful* keys for a given Detail is implied by the
  associated type record (e.g. `PersonType#additional_attribute_keys` for
  `PersonDetail`). Extra keys are permitted but not guaranteed to be
  surfaced; missing keys are not an error at the data layer.

Why flat string-scalar maps:

- Uniform handling across entities (same read/write code, same indexing
  strategy, same UI rendering).
- Simple JSONB indexing (e.g. `jsonb_path_ops` GIN indexes) and
  predictable query plans.
- Graduating a frequently-used key to a real column is always a
  mechanical migration — never a schema redesign.

Values that need richer structure are a signal to promote the key to a
typed column (or to a separate relation), not to nest inside the bag.

### §2b. Provenance — `source_processing_report_id`

Every Detail record carries a **required** FK to the
`SourceProcessingReport` that produced it. This links an assertion about a
tier 1 entity back to the exact `Source` and `SkillRevision` that generated
its facts, so any detail can answer:

- *Which document did this come from?* → `detail.source_processing_report.source`
- *Which skill revision extracted it?* → `detail.source_processing_report.skill_revision`
- *What raw facts did the run emit?* → `detail.source_processing_report.facts`

Rules:

- The column is **NOT NULL**. Every detail must be attributable to a
  processing run. Manual entries, imports, and seed data must each
  synthesize a `SourceProcessingReport` (with an appropriate `Source` and
  `SkillRevision`) and attach it.
- The column is **always named `source_processing_report_id`**, regardless
  of entity type — every tier 1 Detail shares the same column name.
- On the model: `belongs_to :source_processing_report` (not optional).
- On `SourceProcessingReport`: `has_many :<entity>_details` for each tier 1
  entity whose details it can produce. Do **not** use `dependent: :nullify`,
  since the FK cannot be nulled — choose `:destroy` or `:restrict_with_error`
  based on desired cascade semantics.
- `SourceProcessingReport`, `Source`, and `Skill` / `SkillRevision` are
  application data structures, not tier 1 entities — see
  `docs/application-data-structures.md`.

**Rules**

- The Detail class is singular `<Entity>Detail` (e.g. `PersonDetail`); the
  table is `<entity>_details`.
- Detail `belongs_to :<entity>`.
- Prefer promoting a JSON key to a typed column once it is queried or filtered
  on in the app.
- Never mutate an existing Detail to reflect new information — insert a new
  Detail with a newer `as_of`. Details are append-only in spirit.

**Example**

```ruby
class PersonDetail < ApplicationRecord
  belongs_to :person
  belongs_to :source_processing_report
end
```

```ruby
create_table :person_details do |t|
  t.references :person, null: false, foreign_key: true
  t.string :first_name
  t.string :last_name
  t.jsonb :additional_attributes, null: false, default: {}
  t.integer :confidence_tenths
  t.datetime :as_of
  t.references :source_processing_report, null: false, foreign_key: true
  t.timestamps
end
```

---

## 3. Confidence scale

`confidence_tenths` is an integer in the range **0–1000**.

- `1` = 0.1% confidence
- `500` = 50%
- `1000` = 100% (asserted as ground truth)

Store it as an integer to avoid floating-point drift. Convert to a percentage
only at the presentation layer: `value / 10.0`.

---

## 4. Relationships between tier 1 entities

A **tier 1 relationship** connects two tier 1 entities (e.g. a Person to
an Organization) and follows the entity-plus-detail shape so it inherits
provenance and confidence for free. The canonical example is
`PersonOrganization` (Person ↔ Organization).

Naming convention: `<EntityA><EntityB>` in alphabetical order. Always
the same direction (`PersonOrganization`, never `OrganizationPerson`).

### Tables

1. **`<a>_<b>s`** — the relationship row itself.
   - Two FKs: `<a>_id` (NOT NULL), `<b>_id` (NOT NULL).
   - Unique composite index on `(<a>_id, <b>_id)` — no duplicate edges.
   - Nullable `current_detail_id` FK to `<a>_<b>_details`, mirroring §1.
   - No domain attributes beyond timestamps + the two FKs + the current pointer.

2. **`<a>_<b>_details`** — versioned, confidence-scored assertions about
   the relationship. Same shape as §2 with these columns:
   - `<a>_<b>_id` (FK, NOT NULL) — the parent relationship.
   - `as_of` (datetime).
   - `confidence_tenths` (integer; same scale as §3).
   - `additional_attributes` (`jsonb`, NOT NULL, default `{}`) — same
     property-bag rules as §2a.
   - `source_processing_report_id` (FK, NOT NULL) — same provenance rule
     as §2b.

3. **`<a>_<b>_types`** — type taxonomy for the relationship.
   - `name` (string, unique), `description` (text).
   - `additional_attribute_keys` (text[], NOT NULL, default `[]`) — same
     role as on tier 1 type tables.

4. **M2M join** between `<a>_<b>_details` and `<a>_<b>_types` so a single
   detail can carry multiple types (e.g. both "Affiliation" and
   "Employment" on a single PersonOrganization detail). Same shape as the
   tier 1 detail↔type join: composite unique index on the two FKs.

### Models

```ruby
class PersonOrganization < ApplicationRecord
  belongs_to :person
  belongs_to :organization
  belongs_to :current_detail, class_name: "PersonOrganizationDetail", optional: true
  has_many :person_organization_details, dependent: :destroy
end

class PersonOrganizationDetail < ApplicationRecord
  belongs_to :person_organization
  belongs_to :source_processing_report
  has_many :person_organization_detail_person_organization_types, dependent: :destroy
  has_many :person_organization_types,
           through: :person_organization_detail_person_organization_types
end

class PersonOrganizationType < ApplicationRecord
  has_many :person_organization_detail_person_organization_types, dependent: :destroy
  has_many :person_organization_details,
           through: :person_organization_detail_person_organization_types
end
```

Each side of the relationship gets a `has_many :<relationship>s` and a
`has_many :<other_side>, through: :<relationship>s`:

```ruby
class Person < ApplicationRecord
  has_many :person_organizations, dependent: :destroy
  has_many :organizations, through: :person_organizations
end

class Organization < ApplicationRecord
  has_many :person_organizations, dependent: :destroy
  has_many :people, through: :person_organizations
end
```

`SourceProcessingReport` gains
`has_many :<relationship>_details, dependent: :destroy`.

### How a tier 1 relationship differs from a tier 1 entity

- A relationship has **no required typed columns** on its detail beyond
  the parent FK and the provenance FK — the parent FKs already identify
  the subject. All semantic content lives in `additional_attributes` plus
  the attached types.
- The Detail itself has no outward `current_detail_id` — the parent
  relationship row owns the current pointer.
- Otherwise: same `as_of` / `confidence_tenths` / property-bag /
  source-processing-report contract as §2.

---

## 5. Conventions checklist when adding a new tier 1 entity

`<entity>` is the singular snake-case name (e.g. `person`). `<Entity>` is
its CamelCase form. "Type" items follow the `PersonType` / `PersonDetail`
pattern already in the codebase.

**Schema**

- [ ] Migration creating `<entity>s` with only `t.timestamps`.
- [ ] Migration creating `<entity>_details` per §2 (includes
      `additional_attributes jsonb NOT NULL default '{}'`,
      `confidence_tenths`, `as_of`, and
      `source_processing_report_id` NOT NULL).
- [ ] Migration adding nullable `current_detail_id` FK on `<entity>s`
      referencing `<entity>_details`.
- [ ] Migration creating `<entity>_types` with `name`, `description`,
      `additional_attribute_keys` (text[], NOT NULL, default `[]`), and
      a unique index on `name`.
- [ ] Migration creating the many-to-many join table between
      `<entity>_details` and `<entity>_types` with a unique composite index.

**Models**

- [ ] `app/models/<entity>.rb` with
      `has_many :<entity>_details, dependent: :destroy` and
      `belongs_to :current_detail, class_name: "<Entity>Detail", optional: true`.
- [ ] `app/models/<entity>_detail.rb` with `belongs_to :<entity>`,
      `belongs_to :source_processing_report` (required), and
      `has_many :<entity>_types, through: <join model>`.
- [ ] `app/models/<entity>_type.rb` with the reverse `has_many :<entity>_details,
      through: <join model>`.
- [ ] Join model for the detail/type relation.
- [ ] `SourceProcessingReport` updated with `has_many :<entity>_details`
      using a cascade rule that does not nullify the FK
      (e.g. `dependent: :destroy`).

**Routes, controllers, views**

- [ ] Routes: `resources :<entity>s, only: [:index, :show]` and
      `resources :<entity>_types, only: [:index, :new, :create, :edit, :update]`
      (extend entity routes as needed for create/edit flows).
- [ ] `<Entity>Controller#index` view with:
      - a search form (GET `q`) that case-insensitively matches against
        all typed Detail columns *and* every value in
        `additional_attributes`;
      - a results table with Name (linked to show) and Types;
      - while searching, the Types column is replaced with a "Matched on"
        column listing the specific fields/values that caused each row
        to appear (deduplicated per entity);
      - empty/no-match messaging.
- [ ] `<Entity>Controller#show` view with:
      - name / `as_of` / confidence / types derived from
        `entity.current_detail`;
      - `additional_attributes` rendered as a key/value table;
      - a "Prior details" table of non-current details ordered by
        `as_of desc`, including name, `as_of`, confidence, and a summary
        of each detail's `additional_attributes`.
- [ ] `<Entity>TypesController` with `index`, `new`, `create`, `edit`,
      `update` — the type index lists name, description, and
      `additional_attribute_keys`, links each row to edit, and has a
      top-right "New type" button. The form controls `name` (required,
      unique), `description`, and `additional_attribute_keys` (entered
      comma-separated and split into a text[] array in the controller).
- [ ] Sidebar wiring in `app/views/layouts/application.html.erb`:
      entity index link under **Knowledge**; type index link under
      **Types**.

**Seed**

- [ ] At least one entity with **multiple** `<Entity>Detail` rows spanning
      different `as_of` values.
- [ ] Every seeded detail attached to a real `SourceProcessingReport`
      (and therefore a `Source` + `SkillRevision`).
- [ ] At least one `<Entity>Type` defined; each seeded detail is
      associated with one or more types.
- [ ] `current_detail_id` populated on every seeded entity.

**Runtime invariants**

- [ ] Views and non-historical queries dereference the current detail via
      `entity.current_detail`, not by sorting on `as_of`.
- [ ] `current_detail_id` is maintained whenever a newer Detail is
      created (callback, service object, or DB trigger — pick one and
      apply it consistently).

---

## 6. Tier 1 entities

Running list of tier 1 entities implemented in the application. Add a
row here whenever a new tier 1 entity is introduced, and update the
matrix below as items from §5 are completed.

- **Person** (`app/models/person.rb`) — individual people named in sources.
- **Organization** (`app/models/organization.rb`) — companies, agencies, labs, and other legal entities.
- **Facility** (`app/models/facility.rb`) — physical locations; required typed column is `address`.

### Completion matrix

**Keep this matrix up to date.** When you:

- **Add a new tier 1 entity**, add a column for it and a bullet to the
  running list above.
- **Finish a §5 checklist item for an existing entity**, flip the cell
  from `·` or `⚬` to `✓`.
- **Add a new §5 checklist item**, add a row here so existing entities
  can be assessed against it.

If the matrix disagrees with the code, the code wins — update the matrix
to match. The matrix is a scoreboard, not a source of truth.

Legend: **✓** done · **⚬** partial · **·** not started.

| §5 checklist item                                        | Person | Organization | Facility |
|----------------------------------------------------------|:------:|:------------:|:--------:|
| Entity table (`<entity>s`) migration                     |   ✓    |      ✓       |    ✓     |
| Details table (`<entity>_details`) migration             |   ✓    |      ✓       |    ✓     |
| `current_detail_id` FK migration                         |   ✓    |      ✓       |    ✓     |
| `<entity>_types` migration + unique `name` index         |   ✓    |      ✓       |    ✓     |
| Detail↔Type M2M join table migration                     |   ✓    |      ✓       |    ✓     |
| Entity model + `has_many` details + `belongs_to :current_detail` | ✓ |      ✓       |    ✓     |
| Detail model + `belongs_to :<entity>` + SPR + M2M        |   ✓    |      ✓       |    ✓     |
| Type model + reverse M2M                                 |   ✓    |      ✓       |    ✓     |
| Join model                                               |   ✓    |      ✓       |    ✓     |
| `SourceProcessingReport.has_many :<entity>_details`      |   ✓    |      ✓       |    ✓     |
| Routes: entity index/show + type full CRUD               |   ✓    |      ✓       |    ✓     |
| Index view with search + Matched-on column               |   ✓    |      ✓       |    ✓     |
| Show view with current + attributes + prior              |   ✓    |      ✓       |    ✓     |
| `<Entity>TypesController` full CRUD + form               |   ✓    |      ✓       |    ✓     |
| Sidebar links (Knowledge + Types)                        |   ✓    |      ✓       |    ✓     |
| Seed: multi-detail + real reports + types + current      |   ✓    |      ✓       |    ✓     |
| Runtime: views use `entity.current_detail`               |   ✓    |      ✓       |    ✓     |
| Runtime: `current_detail_id` auto-maintained on new Detail |  ·   |      ·       |    ·     |

---

## 7. Conventions checklist when adding a new tier 1 relationship

Mirrors §5 for the relationship pattern in §4. Here `<a>` and `<b>` are
the two singular snake-case entity names in alphabetical order
(e.g. `person`, `organization`); `<rel>` is `<a>_<b>` (e.g.
`person_organization`); `<Rel>` is the CamelCase form (e.g.
`PersonOrganization`).

**Schema**

- [ ] Migration creating `<rel>s` with two NOT NULL FKs (`<a>_id`,
      `<b>_id`), `t.timestamps`, and a unique composite index on
      `(<a>_id, <b>_id)`.
- [ ] Migration creating `<rel>_details` per §4 (`<rel>_id` NOT NULL,
      `as_of`, `confidence_tenths`, `additional_attributes` jsonb NOT
      NULL default `{}`, `source_processing_report_id` NOT NULL).
- [ ] Migration adding nullable `current_detail_id` FK on `<rel>s`
      referencing `<rel>_details`.
- [ ] Migration creating `<rel>_types` (`name` unique, `description`,
      `additional_attribute_keys` text[] NOT NULL default `[]`).
- [ ] Migration creating the M2M join table between `<rel>_details` and
      `<rel>_types` with a unique composite index.

**Models**

- [ ] `app/models/<rel>.rb` with `belongs_to :<a>`, `belongs_to :<b>`,
      `has_many :<rel>_details, dependent: :destroy`, and
      `belongs_to :current_detail, class_name: "<Rel>Detail", optional: true`.
- [ ] `app/models/<rel>_detail.rb` with `belongs_to :<rel>`,
      `belongs_to :source_processing_report`, and
      `has_many :<rel>_types, through: <join model>`.
- [ ] `app/models/<rel>_type.rb` with reverse `has_many :<rel>_details,
      through: <join model>`.
- [ ] Join model.
- [ ] Each tier 1 entity on either side gains
      `has_many :<rel>s, dependent: :destroy` and
      `has_many :<other>, through: :<rel>s`.
- [ ] `SourceProcessingReport.has_many :<rel>_details, dependent: :destroy`.

**Routes, controllers, views**

- [ ] `<Rel>TypesController` with full CRUD (index, new, create, edit,
      update) and the comma-separated → text[] split for
      `additional_attribute_keys` — same shape as the tier 1 type
      controllers.
- [ ] **Each endpoint's show page lists the other side via this
      relationship.** For `<Rel>` connecting `<a>` and `<b>`, the
      `<a>` show view renders a "Other side" section listing every
      related `<b>` (linked to that `<b>`'s show), the type(s) attached
      to the relationship's current detail, and that detail's `as_of`.
      The `<b>` show view does the symmetric thing. Use eager loading
      (`includes(:<other>, current_detail: :<rel>_types)`) to keep the
      query count flat.
- [ ] (Optional, on demand) Browseable `<Rel>` index/show. Often a
      relationship is reached *through* one of its endpoints — these
      views can be added later as the UI calls for them.

**Seed**

- [ ] At least one `<Rel>` with one or more details attached to a real
      `SourceProcessingReport`, with `current_detail_id` populated.
- [ ] At least one `<Rel>Type` defined; each seeded detail is associated
      with one or more types.

**Runtime invariants**

- [ ] `current_detail_id` on the relationship is maintained whenever a
      newer Detail is created — same callback/service/trigger choice as
      §5.

---

## 8. Tier 1 relationships

Running list of tier 1 relationships implemented in the application. Add
a row whenever a new relationship is introduced and update the matrix
below as items from §7 are completed.

- **PersonOrganization** (`app/models/person_organization.rb`) — links a
  Person to an Organization (e.g. employment, affiliation).

### Completion matrix

Same maintenance rules as §6: keep this in sync with the code; if the
matrix disagrees with reality, update the matrix.

Legend: **✓** done · **⚬** partial · **·** not started.

| §7 checklist item                                             | PersonOrganization |
|---------------------------------------------------------------|:------------------:|
| Relationship table (`<rel>s`) + unique edge index             |         ✓          |
| Detail table (`<rel>_details`)                                |         ✓          |
| `current_detail_id` FK on `<rel>s`                            |         ✓          |
| Type table (`<rel>_types`) + unique `name` index              |         ✓          |
| Detail↔Type M2M join table                                    |         ✓          |
| Relationship model + FKs + `current_detail` + details         |         ✓          |
| Detail model + `<rel>` + SPR + M2M types                      |         ✓          |
| Type model + reverse M2M                                      |         ✓          |
| Join model                                                    |         ✓          |
| Endpoints' `has_many :<rel>s` + `has_many :<other>, through:` |         ✓          |
| `SourceProcessingReport.has_many :<rel>_details`              |         ✓          |
| `<Rel>TypesController` full CRUD + form                       |         ·          |
| Endpoint show pages list the other side via this relationship |         ✓          |
| Seed: one `<Rel>` + details + real report + current populated |         ✓          |
| Seed: at least one `<Rel>Type` attached to each detail        |         ✓          |
| Runtime: `current_detail_id` auto-maintained on new Detail    |         ·          |
