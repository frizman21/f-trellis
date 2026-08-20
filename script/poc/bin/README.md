# Running the scripts

Every command runs in the web container. The examples below are written out in
full so they can be pasted as they are.

`bundle exec` is not optional — without it Ruby activates its own bundled `json`
gem before Bundler runs and the script dies on a version conflict before it does
anything.

If the repetition grates, a shell function shortens it. Use a function rather
than `export POC=...`: in zsh an unquoted `$POC/fetch` does not word-split, so
the whole string is treated as one command name and nothing runs.

```bash
poc() { docker-compose exec web bundle exec ruby script/poc/bin/"$1" "${@:2}"; }

poc fetch --only 003
```

Run the stages in order the first time. After that each one is independently
re-runnable, and every stage skips work it has already done unless told
otherwise.

---

## 0a. `seed-model` — define the ontology under test

```bash
docker-compose exec web bundle exec ruby script/poc/bin/seed-model
```

Creates or updates the `Extraction PoC` project from the two tables inside the
script. Idempotent: re-running updates definitions in place and leaves ids
alone, so numbers already recorded in `work/` keep pointing at the same types.

```bash
docker-compose exec web bundle exec ruby script/poc/bin/seed-model --prune
```

Also deletes types the script no longer declares. Soft, so a mis-edit of the
tables is recoverable rather than a rebuild.

## 0b. `export-model` — take the mental model out of the application

```bash
docker-compose exec web bundle exec ruby script/poc/bin/export-model --project 6 --force
```

Writes `00-input/mental-model.json` (what the validator and scorer judge against)
and `00-input/instructions.md` (what actually gets sent). `--force` is required
to overwrite, because `instructions.md` is meant to be hand-edited and a silent
re-export would destroy an afternoon of prompt work.

```bash
docker-compose exec web bundle exec ruby script/poc/bin/export-model --project 6 --urls
```

Also writes `urls.txt` from the project's own sources. Leave `--urls` off when
the corpus is curated by hand, which it usually is.

## 1. `fetch` — pull each page

```bash
docker-compose exec web bundle exec ruby script/poc/bin/fetch
```

Fetches every URL in `urls.txt` that has no HTML yet, and stores it raw. Raw
rather than stripped, so a better stripper can be tried later over the same
pages without paying to fetch them again.

```bash
docker-compose exec web bundle exec ruby script/poc/bin/fetch --only 003,005 --force
```

Re-fetch two specific pages — what to reach for after a 403 or a timeout.

> If this refuses to run saying a number was assigned to a different URL, the
> URL list was edited in the middle rather than appended to. That renumbers
> everything below the edit and orphans the fetched pages, extractions, goldens
> and scores already carrying those numbers. Append instead, or clear
> `work/manifest.json` and the numbered directories and start the corpus over.

## 2. `html-strip` — reduce each page to its text

```bash
docker-compose exec web bundle exec ruby script/poc/bin/html-strip
```

Uses the application's own `ContentExtractor`, which is what `SourceDatum` uses,
so the text under test is the text the application would send. Expect around
95% of the bytes to disappear.

```bash
docker-compose exec web bundle exec ruby script/poc/bin/html-strip --stripper HtmlStripper --force
```

Runs the other stripper in the codebase, currently unused by the extraction
path, so the two can be compared rather than assumed equivalent.

## 3. `llm-process` — ask a model

```bash
docker-compose exec web bundle exec ruby script/poc/bin/llm-process --model gpt-5-nano --dry-run
```

**Always worth running first.** Prints the token estimate and cost per source
and calls nothing.

```bash
docker-compose exec web bundle exec ruby script/poc/bin/llm-process --model gpt-5-nano --schema
```

The normal invocation. `--schema` constrains decoding with the mental model's
JSON Schema, so a reply that is not the declared shape becomes unrepresentable
rather than merely unwanted. On the six-source corpus this was worth 4× the
score for less money — leave it on unless the point is to measure its absence.

```bash
docker-compose exec web bundle exec ruby script/poc/bin/llm-process --model claude-haiku-4-5 --schema --run haiku-baseline
```

Each model writes to its own run directory, so answers to the same source sit
side by side under the same number. `--run` names it; the default is the model
id, which makes the same `--model` twice a re-run and two different ones a
comparison.

```bash
docker-compose exec web bundle exec ruby script/poc/bin/llm-process --model qwen3:8b --endpoint ollama --schema
```

Routes through a `ModelEndpoint`, which is how a locally served model is
reached.

```bash
docker-compose exec web bundle exec ruby script/poc/bin/llm-process --model gpt-5-nano --schema --limit 1
```

One call. The cheapest way to find out whether a provider accepts the request at
all before committing to a sweep.

## 4. `validate-json` — would the applier accept these replies?

```bash
docker-compose exec web bundle exec ruby script/poc/bin/validate-json
```

Validates every run found. Free, so run it before scoring: a model that cannot
produce an appliable reply does not need a score to be ruled out.

```bash
docker-compose exec web bundle exec ruby script/poc/bin/validate-json --run haiku-baseline
```

This checks more than JSON Schema can — that a relationship's `from` and `to`
name entities the reply itself listed, and that it joins only the entity types
its definition allows. Failures are counted by code, because how a model fails
is more useful than how often.

## 5. `score-json` — how good, and what did it cost?

```bash
docker-compose exec web bundle exec ruby script/poc/bin/score-json
```

Scores every run against `work/golden/` and finishes with the run-by-run table
of score against cost per source. Needs ground truth — see
`../work/golden/README.md`.

```bash
docker-compose exec web bundle exec ruby script/poc/bin/score-json --run haiku-baseline --only 002
```

One source in one run, when a number looks wrong and you want the per-item
missing/extra lists in `05-scored/<run>/002-score.json`.

Read the precision and recall split, not just the score. A wrong entity written
into a shared graph has to be found again by hand; a missed one is usually
restated by the next source that mentions it.

---

## A full pass, start to finish

```bash
poc() { docker-compose exec web bundle exec ruby script/poc/bin/"$1" "${@:2}"; }

poc seed-model
poc export-model --project 6 --force
poc fetch
poc html-strip
poc llm-process --model gpt-5-nano --schema
poc validate-json
poc score-json
```

## Comparing two models

```bash
poc llm-process --model gpt-5-nano --schema
poc llm-process --model claude-haiku-4-5 --schema
poc validate-json
poc score-json          # both runs, one table
```

Nothing before stage 3 re-runs, so a second model costs only its own calls.

> One run of six sources is not evidence. gpt-5-nano's format failures moved to
> different sources between two runs of the same configuration, which was enough
> to move the overall score four-fold. Repeat a configuration two or three times
> before treating a difference between models as real.
