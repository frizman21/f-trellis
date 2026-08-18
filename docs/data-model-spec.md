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

### Self-referential relationships (entity ↔ same entity)

When both endpoints are the same tier 1 entity (a marriage between two
people, a partnership between two companies), follow the same pattern
with these adjustments:

- **Naming**: `<entity>_<entity>` for the relationship table — Rails
  inflection turns `person_person` into `person_people`,
  `organization_organization` into `organization_organizations`. The
  detail/type tables follow.
- **FK columns** on the relationship row: `<entity>_a_id` and
  `<entity>_b_id` (both NOT NULL). Use
  `belongs_to :<entity>_a, class_name: "<Entity>"` and
  `belongs_to :<entity>_b, class_name: "<Entity>"` so the same class can
  sit on either side.
- **Symmetric edges**: insert with `(a_id, b_id)` sorted ascending so
  `(A, B)` and `(B, A)` collapse to one row. The unique composite index
  on `(<entity>_a_id, <entity>_b_id)` enforces no duplicate pairs once
  callers honor the sort. (No DB CHECK is added today; future creation
  paths must sort.)
- **Endpoint association**: each entity gets two `has_many` declarations
  (`<rel>s_as_a`, `<rel>s_as_b`) plus a small instance method that
  returns both directions as one relation:

  ```ruby
  def person_people
    PersonPerson.where("person_a_id = :id OR person_b_id = :id", id: id)
  end
  ```

  Use that method on the show page.
- **`other_<entity>(record)` helper** on the relationship model so the
  show page can ask "given me, who is on the other side?":

  ```ruby
  def other_person(person)
    person_a_id == person.id ? person_b : person_a
  end
  ```

- **Show page**: list "Related <entity>s" instead of the cross-entity
  "Other side" — render the `other_<entity>` for each incident edge.
- **Postgres identifier limit (63 chars)** can bite when both sides are
  long words. Example: the conventional join name
  `organization_organization_detail_organization_organization_types`
  is 64 characters and gets rejected. Pick a shortened name explicitly
  (e.g. `org_org_typings`, model `OrgOrgTyping`) — Rails' `has_many
  :through` resolves through the join association name, not the table
  name, so the rest of the model code stays readable.

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
      - **pagination** via `kaminari` (`scope.page(params[:page]).per(N)`)
        with a "Showing X of Y" caption above the table and a
        `<%= paginate @collection %>` block below — search filtering
        composes with pagination (filter first, then page);
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

**LLM tools**

- [ ] `app/tools/upsert_<entity>_tool.rb` —
      `Upsert<Entity>Tool < RubyLLM::Tool`:
      - Required params: the entity's typed key field(s) (e.g.
        `first_name` / `last_name` for Person, `name` for Organization).
        Optional params: `confidence_tenths` (integer, default 800) and
        `additional_attributes` (object, flat string→scalar map).
      - Initialized with the active `SourceProcessingReport`; stored on
        `@report`.
      - Look up the entity case-insensitively by joining
        `<entity>_details` against the typed key column(s) on the
        current detail. When no match, create a fresh entity row.
      - Always insert a new `<Entity>Detail` attached to `@report`,
        set `as_of: Time.current`, clamp confidence to 0–1000, sanitize
        the property bag to scalar-only values, and update the entity's
        `current_detail`.
      - Return `{ <entity>_id:, detail_id:, created: }`. Rescue
        `ActiveRecord::RecordInvalid` and return `{ error: e.message }`
        rather than raising.
- [ ] Tool registered in `app/jobs/process_report_job.rb` inside the
      `chat.with_tools(...)` call so every chat run can use it.

---

## 6. Tier 1 entities

Running list of tier 1 entities implemented in the application. Add a
row here whenever a new tier 1 entity is introduced, and update the
matrix below as items from §5 are completed.

- **Person** (`app/models/person.rb`) — individual people named in sources.
- **Organization** (`app/models/organization.rb`) — companies, agencies, labs, and other legal entities.
- **Facility** (`app/models/facility.rb`) — physical locations; required typed column is `address`.
- **Part** (`app/models/part.rb`) — physical components / assemblies / raw materials; required typed column is `name`.
- **Science** (`app/models/science.rb`) — fields, principles, effects and phenomena; required typed column is `name`, with an optional `summary`.
- **Technology** (`app/models/technology.rb`) — engineered capabilities: methods, materials, classes of device, subsystems; required typed column is `name`, with an optional `summary`.

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

| §5 checklist item                                        | Person | Organization | Facility | Part | Science | Technology |
|----------------------------------------------------------|:------:|:------------:|:--------:|:----:|:-------:|:----------:|
| Entity table (`<entity>s`) migration                     |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| Details table (`<entity>_details`) migration             |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| `current_detail_id` FK migration                         |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| `<entity>_types` migration + unique `name` index         |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| Detail↔Type M2M join table migration                     |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| Entity model + `has_many` details + `belongs_to :current_detail` | ✓ |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| Detail model + `belongs_to :<entity>` + SPR + M2M        |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| Type model + reverse M2M                                 |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| Join model                                               |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| `SourceProcessingReport.has_many :<entity>_details`      |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| Routes: entity index/show + type full CRUD               |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| Index view with search + Matched-on column               |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| Show view with current + attributes + prior              |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| `<Entity>TypesController` full CRUD + form               |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| Sidebar links (Knowledge + Types)                        |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| Seed: multi-detail + real reports + types + current      |   ✓    |      ✓       |    ✓     |  ⚬   |   ✓   |     ✓      |
| Runtime: views use `entity.current_detail`               |   ✓    |      ✓       |    ✓     |  ✓   |   ✓   |     ✓      |
| Runtime: `current_detail_id` auto-maintained on new Detail |  ·   |      ·       |    ·     |  ·   |   ·   |     ·      |
| LLM `Upsert<Entity>Tool` + registered in ProcessReportJob |   ✓    |      ✓       |    ·     |  ·   |   ✓   |     ✓      |

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
- [ ] Sidebar wiring: add a link to the `<Rel>TypesController#index`
      under the **Types** section in
      `app/views/layouts/application.html.erb`, alongside the tier 1
      type links.
- [ ] `<Rel>Controller#show` view that renders both parties (each
      linked to its own show page), a summary of the current detail
      (`as_of` / confidence / types / linked Source / property-bag
      table), and a **Contributing details** table at the bottom that
      lists *every* `<Rel>Detail` on this edge — current and prior — in
      one chronological list (`order(as_of: :desc, created_at: :desc)`).
      Columns: a "current" badge marking the row whose id matches
      `current_detail_id`, `as_of`, confidence, types, source link, a
      one-line summary of `additional_attributes`, and a per-row "View"
      link to the per-detail show page (next bullet). Eager-load with
      `includes(:<rel>_types, source_processing_report: :source)` to
      keep the query count flat. The "other side" tables on each
      endpoint's show page each get a per-row link to this relationship
      show. **Self-referential relationships need this too**: both
      parties are still distinct records, and the per-edge view exposes
      relationship-only state (the relationship's types, `as_of`,
      confidence, and property bag for *this* edge) that doesn't fit
      cleanly on either endpoint's show page.
- [ ] `<Rel>DetailsController#show` — per-detail provenance page,
      reached from the "View" links in the contributing-details table.
      Route: `resources :<rel>_details, only: [:show]`. The view shows
      the detail id, a "current" badge when this row is the edge's
      current detail, a link back to the relationship show, the
      `as_of` / confidence / types / `created_at`, the linked Source
      and Skill revision (via `source_processing_report.source` and
      `source_processing_report.skill_revision`), and the full
      `additional_attributes` as a key/value table.
- [ ] (Optional, on demand) Browseable `<Rel>` index. Often a
      relationship is reached *through* one of its endpoints; the index
      can be added later as the UI calls for it.

**Seed**

- [ ] At least one `<Rel>` with one or more details attached to a real
      `SourceProcessingReport`, with `current_detail_id` populated.
- [ ] At least one `<Rel>Type` defined; each seeded detail is associated
      with one or more types.

**Runtime invariants**

- [ ] `current_detail_id` on the relationship is maintained whenever a
      newer Detail is created — same callback/service/trigger choice as
      §5.

**LLM tools**

- [ ] `app/tools/link_<rel>_tool.rb` — `Link<Rel>Tool < RubyLLM::Tool`.
      One generic tool per relationship; the relationship type is
      passed as a parameter rather than baked into the tool.
      - Required params: the two endpoint id params (`<a>_id`, `<b>_id`
        for cross-entity relationships; `<entity>_a_id`,
        `<entity>_b_id` for self-referential ones), and a `type` string
        naming a `<Rel>Type` that must already exist. Optional params:
        `as_of` (ISO 8601 string, defaults to now),
        `confidence_tenths` (integer, default 800), and
        `additional_attributes` (object, flat string→scalar map).
      - Initialized with the active `SourceProcessingReport`; stored on
        `@report`.
      - For self-referential relationships: store the edge with sorted
        ids so the unordered pair dedupes regardless of caller argument
        order; reject same-id calls with an error. For asymmetric types
        (e.g. `Subsidiary`), document the direction-coding keys callers
        must put in `additional_attributes` (e.g.
        `parent_organization_id`, `subsidiary_organization_id`) — the
        edge schema is symmetric, so direction lives in the property
        bag.
      - Look up the named `<Rel>Type` by `name` and return
        `{ error: "<Rel>Type '<name>' is not configured" }` when
        missing. Use `find_or_create_by!` on the edge, create a new
        `<Rel>Detail` attached to `@report`, attach the type via the
        M2M (`detail.<rel>_types = [ relationship_type ]`), and update
        the edge's `current_detail`.
      - Return `{ <rel>_id:, detail_id:, ...endpoint ids..., type: }`.
        Rescue `ActiveRecord::RecordInvalid` and return
        `{ error: e.message }`.
- [ ] Tool registered in `app/jobs/process_report_job.rb` inside the
      `chat.with_tools(...)` call.

---

## 8. Tier 1 relationships

Running list of tier 1 relationships implemented in the application. Add
a row whenever a new relationship is introduced and update the matrix
below as items from §7 are completed.

- **PersonOrganization** (`app/models/person_organization.rb`) — links a
  Person to an Organization (e.g. employment, affiliation).
- **PersonPerson** (`app/models/person_person.rb`) — self-referential
  link between two people (e.g. marriage, friendship, family).
- **OrganizationOrganization** (`app/models/organization_organization.rb`)
  — self-referential link between two organizations (e.g. partnership,
  subsidiary).
- **PartOrganization** (`app/models/part_organization.rb`) — links a Part
  to an Organization (manufacturer, consumer, demand).
- **PartPart** (`app/models/part_part.rb`) — self-referential link
  between two parts (composition).
- **PartTechnology** (`app/models/part_technology.rb`) — links a Part to
  the Technology it implements, embodies or depends on.
- **ScienceTechnology** (`app/models/science_technology.rb`) — links a
  Science to a Technology that applies it or is derived from it.
- **PersonScience** (`app/models/person_science.rb`) — links a Person to
  a Science they research, author in or contribute to.

### Completion matrix

Same maintenance rules as §6: keep this in sync with the code; if the
matrix disagrees with reality, update the matrix.

Legend: **✓** done · **⚬** partial · **·** not started · **—** not applicable
(e.g. cross-entity-only items in self-referential columns).

Column abbreviations: **PO** PersonOrganization · **PP** PersonPerson · **OO** OrganizationOrganization · **PartO** PartOrganization · **PartP** PartPart · **PartT** PartTechnology · **ST** ScienceTechnology · **PS** PersonScience.

| §7 checklist item                                             | PO | PP | OO | PartO | PartP | PartT | ST | PS |
|---------------------------------------------------------------|:--:|:--:|:--:|:-----:|:-----:|:-----:|:--:|:--:|
| Relationship table (`<rel>s`) + unique edge index             | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Detail table (`<rel>_details`)                                | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| `current_detail_id` FK on `<rel>s`                            | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Type table (`<rel>_types`) + unique `name` index              | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Detail↔Type M2M join table                                    | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Relationship model + FKs + `current_detail` + details         | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Detail model + `<rel>` + SPR + M2M types                      | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Type model + reverse M2M                                      | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Join model                                                    | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Endpoints' `has_many :<rel>s` + `has_many :<other>, through:` | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| `SourceProcessingReport.has_many :<rel>_details`              | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| `<Rel>TypesController` full CRUD + form                       | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Sidebar link to `<Rel>TypesController#index` under Types      | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Endpoint show pages list the other side via this relationship | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| `<Rel>Controller#show` + per-edge link from both endpoints    | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Show: contributing-details table (badge + View link)          | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| `<Rel>DetailsController#show` per-detail provenance page      | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Seed: one `<Rel>` + details + real report + current populated | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Seed: at least one `<Rel>Type` attached to each detail        | ✓  | ✓  | ✓  |   ✓   |   ✓   |   ✓   | ✓  | ✓  |
| Runtime: `current_detail_id` auto-maintained on new Detail    | ·  | ·  | ·  |   ·   |   ·   |   ·   | ·  | ·  |
| LLM `Link<Rel>Tool` (generic, type-as-param) + registered     | ✓  | ·  | ✓  |   ·   |   ·   |   ✓   | ✓  | ✓  |

---

## 9. Measured parameters on a type

`additional_attribute_keys` (§2a) names a key and stops there. That is enough
for a label — `manufacturer_part_number` holds whatever string the page gave —
and not enough for a **measurement**, which is a number *and* a unit. "12 lbs"
in the property bag cannot be sorted, cannot be compared against "5.6 kg", and
two runs writing "12lb" and "12 lbs" record what looks like two different facts.
§2a already anticipates this: a value needing richer structure is a signal to
promote the key out of the bag.

`PartType` is the worked example. Apply the same shape to another tier 1 type
whose instances are measured rather than merely described.

### Tables

1. **`<entity>_type_parameters`** — the schema: what a type is measured by.
   - `<entity>_type_id` (FK, NOT NULL).
   - `name` (string, NOT NULL) — normalised to a lowercase snake_case key.
   - `unit` (string) — the unit every value is stored in. NOT NULL in effect for
     numeric parameters, enforced in the model rather than the database because
     text parameters legitimately have none.
   - `value_type` (string, NOT NULL, default `"number"`) — `number` or `text`.
   - `description` (text).
   - Unique composite index on `(<entity>_type_id, name)`.

2. **`<entity>_detail_parameters`** — the values, one per parameter per Detail.
   - `<entity>_detail_id` (FK, NOT NULL).
   - `<entity>_type_parameter_id` (FK, NOT NULL).
   - `value_number` (decimal) / `value_text` (string) — one is filled, decided by
     the parameter's `value_type`.
   - `as_stated` (string) — the source's own wording, before conversion.
   - `confidence_tenths` (integer; §3 scale).
   - Unique composite index on `(<entity>_detail_id, <entity>_type_parameter_id)`.

### Rules

- A parameter value is **not** a Detail. It is part of the assertion its Detail
  makes, so it inherits that row's `as_of` and `source_processing_report_id`
  rather than carrying its own. Re-processing a page inserts a new Detail with a
  fresh set of values, so §2's append-only rule still holds.
- **Values are stored in the parameter's declared unit**, converted on the way
  in. A column of weights in mixed units compares nothing. Whoever writes the
  value converts; `as_stated` keeps the original so a bad conversion stays
  visible afterwards.
- **A parameter no type declares is refused, not invented.** An undeclared fact
  belongs in `additional_attributes`. Quietly accepting one would make the
  taxonomy meaningless.
- **Types compose rather than inherit.** An entity Detail carries several types
  through the M2M join, and is measured by the union of their parameters. That is
  how "every physical part has a weight" is expressed — a `Physical Part` type
  declaring `weight`, attached alongside whatever else the part is. There is no
  type hierarchy and none is needed.
- An LLM tool that populates these must put the **live taxonomy in its own
  description** — which types exist and what each is measured in — rather than
  relying on a skill's prompt to repeat it. A prompt is a second copy that drifts
  the moment a type gains a parameter. See `UpsertPartContract`.
