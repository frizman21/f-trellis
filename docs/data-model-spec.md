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

Relationships follow the same entity-plus-detail shape so they inherit
provenance and confidence for free.

1. A **relationship entity** (e.g. `Employment`, `Membership`) joins two tier 1
   entities via two foreign keys and has no other domain attributes.
2. A **`<relationship>_detail`** table holds the typed columns,
   `additional_attributes`, `confidence_tenths`, and `as_of` for the
   relationship — same shape as §2.

This pattern will be locked in when the first relationship is built. Until
then, mirror §1–§2 as closely as possible and update this section with the
concrete example.

---

## 5. Conventions checklist when adding a new tier 1 entity

- [ ] Migration creating `<entity>s` with only `t.timestamps`.
- [ ] Migration creating `<entity>_details` per §2.
- [ ] Migration adding nullable `current_detail_id` FK on `<entity>s`
      referencing `<entity>_details`.
- [ ] `app/models/<entity>.rb` with
      `has_many :<entity>_details, dependent: :destroy` and
      `belongs_to :current_detail, class_name: "<Entity>Detail", optional: true`.
- [ ] `app/models/<entity>_detail.rb` with `belongs_to :<entity>` and
      `belongs_to :source_processing_report` (required).
- [ ] `SourceProcessingReport` updated with
      `has_many :<entity>_details` using a cascade rule that does not
      nullify the FK (e.g. `dependent: :destroy`).
- [ ] Seed data exercising at least one entity with one detail, with
      `current_detail_id` populated.
- [ ] Views dereference the current detail via `entity.current_detail`.
- [ ] `current_detail_id` is maintained whenever a newer Detail is created.
