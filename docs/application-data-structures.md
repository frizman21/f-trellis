# Application Data Structures

This document describes the operational data structures that support the
application but are **not** tier 1 knowledge entities. See
`docs/data-model-spec.md` for the tier 1 pattern.

The families here today:

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

### `SourceExclusion` (table: `source_exclusions`)

A URL pattern that link extraction refuses to turn into a `Source`. Standalone
reference data — it has no association with `Source` at all, because a rule
about pages the system should *not* hold cannot be stored on the rows it
prevents from existing.

| Column        | Type     | Notes                                          |
|---------------|----------|------------------------------------------------|
| `pattern`     | `string`, NOT NULL, unique | Absolute URL, `*` for any run of characters. |
| `description` | `text`   | Why these pages are not worth holding.         |
| `is_enabled`  | `boolean`, NOT NULL, default `true` | A disabled rule is kept but not applied. |
| `created_at` / `updated_at` | `datetime` | Standard timestamps.       |

`pattern` is normalized on save by `Source.normalize_url` — the same treatment
a source's URL gets, filling in a missing scheme and dropping a `#fragment`.
This is not cosmetic: links are matched in normalized form, so a pattern that
kept its fragment would match nothing. A pattern that does not resolve to a URL
is rejected.

Matching is a full-string glob, anchored at both ends and case-insensitive:
`*` stands for any run of characters and everything else is literal. So
`https://news.ycombinator.com/item?id=*` excludes every comment page and leaves
the front page alone. A pattern is written as an absolute URL and still catches
the relative hrefs on that host, because `LinkExtractor` resolves every href
against the page it was found on **before** exclusions are applied.

Enforcement is at one point: `SourceDatum#extract_links`. Both callers —
`CrawlJob` and the "Extract links" action — go through it, so there is no path
to the unfiltered list, and an excluded URL is neither created as a source nor
recorded as a `SourceLink` edge. The filtered result carries the rejected URLs
in `LinkExtractor::Result#excluded` rather than dropping them silently, which is
what the "Extract links" page reports.

Deliberately **not** applied to `Source.for_url`, so entering a URL by hand or
adding one to a learning set still works. Exclusions filter what a page
proposes, not what a person asks for. They are also not retroactive: sources
that already exist stay, which is why the index shows how many of them each
pattern covers.

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

## 4. Skill evaluation family

An evaluation asks one question: how does this skill do on these pages, across
these models? It is a rehearsal, not production work — running one never writes
into the knowledge graph.

### `SkillEvaluation`

| Column            | Type         | Notes                                    |
|-------------------|--------------|------------------------------------------|
| `name`            | `string`, NOT NULL | What the comparison is for.        |
| `description`     | `text`       | Free notes.                              |
| `skill_id`        | FK, NOT NULL | The skill under test. Its **latest** revision is what a run uses. |
| `learning_set_id` | FK, NOT NULL | The pages to run against.                |
| `base_model_id`   | FK to `models`, NOT NULL | The model the others are judged against. |

The pages come from a `LearningSet` rather than a list of the evaluation's own,
so two evaluations pointed at the same set stay comparable and a set curated
once stays curated. A page added to the set later is simply part of the next
run. A set cannot be deleted while an evaluation points at it.

`SkillEvaluationModel` joins an evaluation to each `Model` to run, unique on the
pair. Nothing reads `base_model` beyond the UI yet — it is recorded so scoring
can use it.

### `SkillEvaluationResult`

One run of one skill revision, on one page, through one model.

| Column              | Type         | Notes                                  |
|---------------------|--------------|----------------------------------------|
| `skill_evaluation_id` | FK, NOT NULL | Owning evaluation (cascades).        |
| `source_id`         | FK, NOT NULL | The page that was sent.                |
| `model_id`          | FK, NOT NULL | The model that answered.               |
| `skill_revision_id` | FK, NOT NULL | The wording that produced the response.|
| `chat_id`           | FK, nullable | The chat the run went through.         |
| `status`            | `string`, NOT NULL, default `pending` | `pending` / `running` / `complete` / `failed`. |
| `score`             | `decimal`, nullable | **Not computed yet** — how a response is scored is undecided, and a made-up number would be worse than none. |
| `response`          | `text`       | What the model returned.               |
| `error`             | `text`       | Why a failed run failed.               |
| `started_at` / `completed_at` | `datetime` | Run timing.                |

Unique on `[skill_evaluation_id, source_id, model_id, skill_revision_id]`:
pressing Run twice must not pay twice, and editing the skill creates a revision,
which makes every pair runnable again against the new wording.

The evaluation itself has **no** status column. Progress is derived from these
rows — `SkillEvaluation#result_counts` and `#run_status`
(`not_run` / `running` / `incomplete` / `failed` / `complete_with_failures` /
`complete`) — always scoped to the current skill revision, so the number stops
describing runs of a wording that has since been edited. A stored column would
need every job completion to keep it in sync and would drift the moment a job was
dropped. `#stalled?` reports pairs sitting in `pending`/`running` past
`STALE_AFTER`, which is what a dropped job looks like; nothing re-queues them.

`SkillEvaluationRunner` turns the configuration into pending results plus one
`RunSkillEvaluationJob` each; the job sends the revision as instructions and the
page's extracted text as the message, with **no tools registered**. A failed
pair is recorded on its own row and the rest of the run continues.

---

## 5. `Project`

A named body of work. The application's landing page (`root`) is the list of
projects — the first screen you see is "which body of work am I in".

| Column        | Type     | Notes                          |
|---------------|----------|--------------------------------|
| `name`        | `string`, NOT NULL | Display name. Validated for presence. |
| `created_at` / `updated_at` | `datetime` | Standard timestamps. |

`Project` is deliberately **not** a tier 1 knowledge entity. It is a container
the application organises work into, not a real-world subject extracted from a
source by a skill, so it carries `name` directly on the table rather than
through a versioned, confidence-scored `ProjectDetail` with
`source_processing_report_id` provenance.

It owns nothing yet: no other record belongs to a project. Scoping the rest of
the application to a selected project is separate work.

The projects screens render full width with no sidebar, by setting
`content_for :full_width`, which the layout reads through the `sidebar?` helper.
They sit outside the knowledge and research navigation the sidebar offers.

---

## 5. Relationship map

```
Source ─┬─< SourceDatum
        ├─< SourceProcessingReport >─ SkillRevision >─ Skill
        ├─< Source (child_sources, via parent_source_id)
        ├─< SourceLink >─ Source   (from_source / to_source)
        ├─< LearningSetSource >─ LearningSet
        └─< SkillEvaluationResult >─ SkillEvaluation

SourceExclusion              (standalone — consulted when links become Sources)

SkillEvaluation ─┬─ Skill
                 ├─ LearningSet
                 ├─ Model (base_model)
                 ├─< SkillEvaluationModel >─ Model
                 └─< SkillEvaluationResult >─ SkillRevision
```

- A `Source` has zero-or-more `SourceDatum` rows (raw payload chunks) and
  zero-or-more `SourceProcessingReport` rows (processing outcomes).
- A `Skill` has zero-or-more `SkillRevision` rows.
- Each `SourceProcessingReport` joins one `Source` to one `SkillRevision`.
