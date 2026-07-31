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
| `parent_source_id` | FK, nullable | The source whose content linked to this one, set at creation time. |
| `created_at` / `updated_at` | `datetime` | Standard timestamps.       |

Associations:

- `belongs_to :parent_source, class_name: "Source", optional: true`
- `has_many :child_sources, class_name: "Source", dependent: :nullify`
- `has_many :outbound_links` / `has_many :inbound_links` (see `SourceLink`)
- `has_many :links_to` / `has_many :linked_from` (the sources on either end)
- `has_many :source_data, dependent: :destroy`
- `has_many :source_processing_reports, dependent: :destroy`

`parent_source` records **origination** — which source caused this one to be
created. It is written by `CrawlJob` and by the "Extract links" action, is
`nil` for sources entered by hand, and is never overwritten once set: a link
to a source that already exists leaves that source's parentage alone. On a
multi-hop crawl the parent is the page the link was actually found on, not
the seed.

### `SourceLink` (table: `source_links`)

One directed edge in the page-link graph: `from_source`'s content contained a
link to `to_source`. Distinct from `parent_source` — parentage is one value
fixed at creation, whereas an edge is recorded for **every** link resolved to
a known source, including links between two sources that already existed.

| Column           | Type         | Notes                              |
|------------------|--------------|------------------------------------|
| `from_source_id` | FK, NOT NULL | The source whose content has the link. |
| `to_source_id`   | FK, NOT NULL | The source being linked to.        |
| `created_at` / `updated_at` | `datetime` | Standard timestamps.  |

A unique index on `[from_source_id, to_source_id]` makes edges idempotent, so
re-crawling or re-extracting a page adds nothing. Self-links are rejected.
Use `SourceLink.record(from:, to:)` rather than creating rows directly — it is
idempotent and returns `nil` for a self-link or a missing end. Both FKs cascade
on delete, so removing a source removes its edges in both directions.

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

### `LearningSet` and `LearningSetSource`

A named collection of sources — the pages you keep coming back to when you want
to know whether something works. A set only groups pages; nothing about it
fetches, crawls or processes them.

| Column        | Type     | Notes                                        |
|---------------|----------|----------------------------------------------|
| `name`        | `string`, NOT NULL, unique | What the set is for.       |
| `description` | `text`   | Why these pages belong together.             |
| `created_at` / `updated_at` | `datetime` | Standard timestamps.       |

`LearningSetSource` joins a set to a source, unique on
`[learning_set_id, source_id]`; `learning_set_id` cascades on delete, so
deleting a set drops its memberships and leaves every source in place.

Pages are added **by URL** through `LearningSet#add_url`, which resolves the URL
with `Source.for_url` — normalising whitespace, a missing scheme and a trailing
`#fragment`, then reusing the existing source when one already has that URL. A
page's identity in this app is its URL; a second row for the same page would
split its fetched content and its processing history in two. Adding a page the
set already has is a reported no-op, not an error.

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
| `applicability` | `text` | Which pages the skill is worth a call on, and which it is not. Read by triage. Required once `is_active`. |
| `url_patterns` | `text[]`, NOT NULL, default `[]` | Regex sources that claim a URL outright. |
| `is_active` | `boolean`, NOT NULL, default `false` | Only active skills should be executed. New skills start inactive until explicitly enabled. |
| `created_at` / `updated_at` | `datetime` | Standard timestamps.         |

Two fields decide when a skill runs, and they answer different questions.
`applicability` is prose for the model to judge against a page's text —
"exhibitor lists and member directories; not prose articles". `url_patterns` is
a list of Ruby regex sources matched against the source's URL, unanchored and
case insensitively (`linkedin\.com/in/`). A pattern match is a fact rather than
a judgement, so it wins outright: `SkillTriage` runs the matching skills, skips
every other skill for that page, and makes no model call at all. Most skills
have no patterns and route by their statement alone.

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
        ├─< SourceProcessingReport >─ SkillRevision >─ Skill
        ├─< Source (child_sources, via parent_source_id)
        ├─< SourceLink >─ Source   (from_source / to_source)
        └─< LearningSetSource >─ LearningSet
```

- A `Source` has zero-or-more `SourceDatum` rows (raw payload chunks) and
  zero-or-more `SourceProcessingReport` rows (processing outcomes).
- A `Skill` has zero-or-more `SkillRevision` rows.
- Each `SourceProcessingReport` joins one `Source` to one `SkillRevision`.
