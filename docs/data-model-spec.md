# Data Model Specification

This document defines the repeating shape used by every tier 1 entity in the
application and the relationships between them. Follow it when adding new
entities so the codebase stays consistent and queries remain predictable.

The canonical example is `Person` / `PersonDetail`. Everything below generalises
that pattern.

---

## 1. Tier 1 Entity

A **tier 1 entity** is a real-world subject the system tracks (a person, an
organisation, a place, etc.).

**Rules**

- The entity table has **no domain attributes**. It exists only as a stable
  identity (primary key + `created_at` / `updated_at`).
- All facts about the entity live in a companion **Detail** table (see §2).
- The Ruby class is singular (`Person`), the table is Rails-pluralised
  (`people`).
- Model declares `has_many :<entity>_details, dependent: :destroy`.

**Example**

```ruby
class Person < ApplicationRecord
  has_many :person_details, dependent: :destroy
end
```

```ruby
create_table :people do |t|
  t.timestamps
end
```

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
| `additional_attributes` | `jsonb`, NOT NULL, default `{}` | Open-ended attributes that aren't (yet) promoted to typed columns. |
| `confidence_tenths`     | `integer`  | Confidence in this assertion, in tenths of a percent. `1` = 0.1%, `1000` = 100%. |
| `as_of`                 | `datetime` | When the assertion is effective (not when it was recorded — `created_at` covers that). |
| `created_at` / `updated_at` | `datetime` | Standard Rails timestamps.                               |

**Typed columns**

Add columns on the Detail table for attributes that are always or often
present and worth querying directly (e.g. `first_name`, `last_name` on
`PersonDetail`). Everything else goes into `additional_attributes`.

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
- [ ] `app/models/<entity>.rb` with `has_many :<entity>_details, dependent: :destroy`.
- [ ] `app/models/<entity>_detail.rb` with `belongs_to :<entity>`.
- [ ] Seed data exercising at least one entity with one detail.
- [ ] Views dereference the current detail via
      `entity.<entity>_details.order(as_of: :desc).first`.
