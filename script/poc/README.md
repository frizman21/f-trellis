# Extraction proof of concept

A script per stage, so the question "which model, given which context, at what
cost, for what quality" can be answered with measurements instead of opinions.

Everything runs in the web container:

```
docker compose exec web bundle exec ruby script/poc/bin/<script> [options]
```

## The numbering scheme

A source is numbered once, by its position in `work/00-input/urls.txt`, and
carries that number through every stage:

```
work/00-input/urls.txt        line 1  ->  000
     01-fetched/000-fetched.html
     02-stripped/000-stripped.txt
     03-extracted/<run>/000-extracted.json
     04-validated/<run>/000-validation.json
     05-scored/<run>/000-score.json
     golden/000-golden.json
```

`grep -r 000 work/` is the whole audit trail for one page. Nothing downstream
parses a URL or slugifies a title to work out what belongs to what — the
filename says so.

Stages that depend on the model nest one directory deeper, under a run label
that defaults to the model id. Two models' answers to source `000` sit side by
side under the same number, which is what makes them diffable:

```
03-extracted/claude-haiku-4-5/000-extracted.json
03-extracted/gpt-5-nano/000-extracted.json
```

`work/manifest.json` is the ledger. Each stage appends what it did to each
number — bytes fetched, reduction achieved, tokens spent, cost, whether the
reply parsed. It is what distinguishes "this stage produced nothing" from "this
stage never ran".

**Append to `urls.txt`, never insert.** Inserting a line renumbers everything
below it, and every fetched page, extraction, golden file and score already
carrying those numbers would silently start describing a different page.
`fetch` refuses to run when it detects this rather than rewriting history;
`--renumber` overrides it, and means throwing the work directory away.

## The stages

| | Script | Reads | Writes |
|---|---|---|---|
| 0a | `seed-model` | the tables inside the script | the `Extraction PoC` project's ontology |
| 0b | `export-model` | a project in the database | `00-input/mental-model.json`, `instructions.md`, `urls.txt` |
| 1 | `fetch` | `urls.txt` | `01-fetched/NNN-fetched.html` |
| 2 | `html-strip` | fetched HTML | `02-stripped/NNN-stripped.txt` |
| 3 | `llm-process` | `instructions.md` + stripped text | `03-extracted/<run>/NNN-extracted.json` |
| 4 | `validate-json` | extractions + `mental-model.json` | `04-validated/<run>/NNN-validation.json` |
| 5 | `score-json` | extractions + `golden/NNN-golden.json` | `05-scored/<run>/NNN-score.json` |
| 6 | `apply-json` | extractions + their validation | records in the project |

## A full pass

```bash
C="docker compose exec web bundle exec ruby script/poc/bin"

$C/seed-model                           # define the ontology under test
$C/export-model --project 6 --force     # mental model + instructions
$C/fetch                                # pull the pages
$C/html-strip                           # HTML -> text

$C/llm-process --model claude-opus-5 --dry-run    # what would this cost?
$C/llm-process --model claude-haiku-4-5
$C/llm-process --model gpt-5-nano
$C/llm-process --model claude-haiku-4-5 --schema --run haiku-schema

$C/validate-json                        # is every reply appliable?
$C/score-json                           # how good is it, and what did it cost?
```

`score-json` finishes with the table the exercise exists to produce: every run,
its score, its precision/recall split, and its cost per source.

## What each stage is deliberately doing

**`seed-model`** defines the ontology under test in two tables in the script
rather than in a console session, because the ontology is the independent
variable: a scoreboard is only comparable across runs if the thing being scored
is written down somewhere that can be diffed. It is idempotent, and `--prune`
deletes types the script no longer declares — soft, so a mis-edit is
recoverable.

It creates its own project rather than reshaping F-DoD. F-DoD holds 352,894
entities and 1,015,988 relationships concentrated in seven relationship types,
two of which run opposite to the ones here, so reshaping it would be a data
migration on 346,175 rows rather than an ontology edit.

**`export-model`** takes the mental model out of the application rather than
restating it. `ExtractionPrompt` already turns a project's structure into
instructions, so the prompt under test is the prompt the application would send.
It writes two files because they have different owners from then on:
`instructions.md` is meant to be edited by hand — finding a better prompt is the
point — and `mental-model.json` is the machine-readable contract the validator
holds replies to. Neither is overwritten without `--force`.

**`html-strip`** uses the application's own `ContentExtractor`, which is what
`SourceDatum` uses, so the text under test is the text the application would
send. `--stripper HtmlStripper` runs the other one in the codebase — currently
unused by the extraction path — because how much that choice is worth is now a
measurable question rather than an assumption.

**`llm-process`** calls RubyLLM directly rather than through the application's
`Chat` record. A sweep should not deposit hundreds of rows in `chats`, and
`ChatCost`'s own comment records that persisted `input_tokens` are wrong — every
chat in the database reports 3 input tokens regardless of prompt size. The
provider's real usage numbers come back on the reply, so those are what get
recorded. `--endpoint NAME` routes through a `ModelEndpoint`, which is how a
locally served model is reached. `--schema` constrains decoding with the same
JSON Schema the prompt describes; whether that is what makes a small model
usable is one of the things the sweep is for.

**`validate-json`** checks more than JSON Schema can. The schema cannot express
that a relationship's `from` and `to` must name entities the reply itself
listed, nor that a relationship may only join the entity types its definition
names — the first is a dangling reference the applier cannot write, the second
is a constraint the database enforces. A reply can be schema-valid and still be
unappliable, so validity here means "the applier would accept this". Failures
are counted by code, because *how* a model fails is more useful than how often.

**`score-json`** compares by identity, never by the ids in a reply — those are
the model's own and differ between two replies that found exactly the same
thing. Everything is resolved to `(type, name)` first, which is also the
identity the database uses, so a score here is a prediction about what would
land in the graph. Four channels are scored separately (entities, their
attributes, relationships, their attributes) because a run that finds every
organization but nothing about any of them and a run that finds half of them
completely can share an overall figure and are not the same result.

Read the precision/recall split, not just the score. A wrong entity written into
a shared graph stays there and has to be found by hand; an entity this source
missed is usually stated again by the next source that mentions it.

**`apply-json`** is the only stage that touches the ontology. It uses the
application's own `ExtractionApplier`, so what lands is what a real extraction
run would land, and it gates on `validate-json`'s verdict rather than forming a
second opinion about validity.

It stores the HTML the proof of concept fetched as the source's newest snapshot,
rather than letting the application re-download the page. A citation pointing at
content the extraction was not made from is a quietly false provenance record.
Several of these URLs already existed from a crawl or another project, holding a
copy fetched on a different day — so the test is whether the newest snapshot's
bytes match the ones that were scored, not whether the source has any content at
all.

## What this cannot tell you yet

Nothing is scored until `work/golden/` has real ground truth in it, and ground
truth is per project — see `work/golden/README.md`. `validate-json` works
without it and is worth running first: a model that cannot produce an appliable
reply does not need to be scored to be ruled out.
