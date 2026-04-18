# Application Data Structures

This document describes the operational data structures that support the
application but are **not** tier 1 knowledge entities. See
`docs/data-model-spec.md` for the tier 1 pattern.

Two families live here today:

- **Sources** — external references the system ingests (URLs, documents),
  along with their raw payload.
- **Skills** — versioned processing capabilities that can be run against a
  source to produce structured output.

A third concept, **SourceProcessingReport**, ties the two together: the
result of running a particular skill revision against a particular source.

---

## 1. Source family

### `Source`

A reference to an external artefact the system knows about.

| Column        | Type     | Notes                                    |
|---------------|----------|------------------------------------------|
| `url`         | `string` | Locator for the artefact.                |
| `description` | `text`   | Human-readable note about the source.    |
| `created_at` / `updated_at` | `datetime` | Standard timestamps.       |

Associations:

- `has_many :source_data, dependent: :destroy`
- `has_many :source_processing_reports, dependent: :destroy`

### `SourceDatum` (table: `source_data`)

Raw binary payload belonging to a source. Kept in the database so payloads
share the same transactional and backup story as the owning rows.

| Column         | Type           | Notes                                 |
|----------------|----------------|---------------------------------------|
| `source_id`    | FK, NOT NULL   | Owning `Source`.                      |
| `content_type` | `string`       | MIME type of the payload.             |
| `data`         | `bytea`        | The bytes themselves.                 |
| `created_at` / `updated_at` | `datetime` | Standard timestamps.    |

Rails inflection note: the model class is `SourceDatum`, the table is
`source_data`. The association on `Source` is `has_many :source_data` — the
`SourceDatum` class is resolved via Rails' built-in `data → datum` inflection.

Active Storage is **not** used. Binary data lives in this table only.

---

## 2. Skill family

A skill is a reusable processing capability (e.g. "Summarize", "Translate").
Its substantive content — prompts, instructions, templates — lives on
revisions so it can evolve without losing history.

### `Skill`

| Column      | Type      | Notes                                              |
|-------------|-----------|----------------------------------------------------|
| `name`      | `string`  | Short identifier.                                  |
| `purpose`   | `string`  | What the skill does, in plain language.            |
| `is_active` | `boolean`, NOT NULL, default `false` | Only active skills should be executed. New skills start inactive until explicitly enabled. |
| `created_at` / `updated_at` | `datetime` | Standard timestamps.         |

Associations:

- `has_many :skill_revisions, dependent: :destroy`

### `SkillRevision`

An immutable-by-convention version of a skill's content. New versions are
added as new rows; old rows are preserved so past processing runs remain
explainable.

| Column      | Type         | Notes                                         |
|-------------|--------------|-----------------------------------------------|
| `skill_id`  | FK, NOT NULL | Owning `Skill`.                               |
| `content`   | `string`     | The body of the revision (prompt / template). |
| `created_at` / `updated_at` | `datetime` | Standard timestamps.        |

Associations:

- `belongs_to :skill`
- `has_many :source_processing_reports, dependent: :destroy`

---

## 3. `SourceProcessingReport`

The output of running one `SkillRevision` against one `Source`. Keeps a
queryable record of what the system has already processed and what it
learned.

| Column              | Type         | Notes                                    |
|---------------------|--------------|------------------------------------------|
| `source_id`         | FK, NOT NULL | The source that was processed.           |
| `skill_revision_id` | FK, NOT NULL | The exact revision that was run.         |
| `facts`             | `jsonb`, NOT NULL, default `{}` | Structured output of the run. |
| `created_at` / `updated_at` | `datetime` | Standard timestamps.       |

Associations:

- `belongs_to :source`
- `belongs_to :skill_revision`

Because the FK is to `SkillRevision` (not `Skill`), a report always
documents the exact wording / logic that produced it — even after the
parent skill's newer revisions supersede it.

---

## 4. Relationship map

```
Source ─┬─< SourceDatum
        └─< SourceProcessingReport >─ SkillRevision >─ Skill
```

- A `Source` has zero-or-more `SourceDatum` rows (raw payload chunks) and
  zero-or-more `SourceProcessingReport` rows (processing outcomes).
- A `Skill` has zero-or-more `SkillRevision` rows.
- Each `SourceProcessingReport` joins one `Source` to one `SkillRevision`.
