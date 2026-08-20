# Ground truth

One file per source you want scored, named for the number that source carries
through the pipeline: `000-golden.json` is the correct answer for the page in
`01-fetched/000-fetched.html`.

A golden file has exactly the shape a model reply has:

```json
{
  "entities": [
    { "id": "e1", "name": "Albers Aerospace", "type": "Organization",
      "attributes": { "headquarters": "Huntsville, Alabama" } }
  ],
  "relationships": [
    { "type": "Affiliation", "from": "e2", "to": "e1" }
  ]
}
```

The ids are yours and only have to be consistent within the file. `score-json`
resolves every id to the `(type, name)` pair it points at before comparing, so
naming an entity `e1` here and `org-albers` in a reply costs nothing — what is
compared is which things were found and how they were joined, never what they
were called internally.

Comparison is case- and whitespace-insensitive on names and values. It is exact
on everything else: an attribute the golden file records and the reply omits is
missing, and one the reply adds is extra. Both lower the score.

## Producing these

Empty for now, by design — ground truth is per project, and this is the F-DoD
project's. The cheapest honest route is to run the best model available over the
corpus once, then correct its output by hand:

```
docker compose exec web bundle exec ruby script/poc/bin/llm-process --model claude-opus-5 --run golden-draft
cp ../03-extracted/golden-draft/000-extracted.json 000-golden.json
# then edit 000-golden.json against 000-stripped.txt until it is actually right
```

The corrections are the part that matters. A golden file copied from a model
without being read measures how closely other models imitate that one, which is
not the same question and will happily score a shared hallucination as correct.

Score nothing until at least a few of these are real. A scoreboard built on
unchecked goldens is more misleading than no scoreboard, because it looks like
evidence.
