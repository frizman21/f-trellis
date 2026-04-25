# Fixture Promotion: Production → Dev Sync

This app evolves in two places at once: the **dev environment** is where new
tools and skills are validated against unchanging example files (Rails
fixtures, deterministic unit tests), while the **production environment** is
where new capabilities are exercised against real, novel inputs. The two need
to stay in sync without either side calcifying — production should not drift
ahead of what tests exercise, and tests should not lag behind real-world
inputs that have already proven interesting.

The mechanism is **fixture promotion**: production marks records worth
keeping, and a script materializes them into local Rails fixture files.

---

## 1. Flags on `sources` and `skills`

Both `sources` and `skills` carry two boolean columns (NOT NULL, default
`false`):

| Column          | Set by      | Meaning                                                            |
|-----------------|-------------|--------------------------------------------------------------------|
| `is_promotable` | a human or job | "This record is interesting enough to become a test fixture."  |
| `is_fixtured`   | the promotion script | "A fixture file already exists for this record."          |

A record is **eligible for promotion** when `is_promotable = true` and
`is_fixtured = false`. The `Source.promotable_pending` /
`Skill.promotable_pending` scopes return exactly that set.

`is_promotable` is sticky — flipping it on doesn't get reset by promotion.
That way the same record can be re-promoted after edits (set `is_fixtured`
back to `false` and re-run the script).

---

## 2. JSON endpoints

The running app exposes the promotion queue and a flag-flip endpoint as JSON.

| Method | Path                                       | Purpose                                          |
|--------|--------------------------------------------|--------------------------------------------------|
| GET    | `/fixture_promotions.json`                 | List eligible sources + skills (with revisions). |
| PATCH  | `/fixture_promotions/:resource/:id`        | Set `is_fixtured = true`. `:resource` is `sources` or `skills`. |

The endpoints live in `app/controllers/fixture_promotions_controller.rb` and
are intentionally thin — they're the minimum surface the script needs.

---

## 3. The `fixtures:promote` Rake task

```
bin/rails fixtures:promote                          # defaults to http://localhost:3000
bin/rails fixtures:promote HOST=http://localhost:3000
bin/rails fixtures:promote HOST=https://example.com  # eventual production
```

For each eligible record the task:

1. **Reads** the JSON index from `<HOST>/fixture_promotions.json`.
2. **Writes** a YAML entry into `test/fixtures/sources.yml`,
   `test/fixtures/skills.yml`, and `test/fixtures/skill_revisions.yml` under
   the key `promoted_<id>`. Existing entries (manual or previously promoted)
   are preserved; entries with the same `promoted_<id>` key are overwritten
   so re-promotion is idempotent.
3. **PATCHes** `<HOST>/fixture_promotions/<resource>/<id>` to flip
   `is_fixtured = true` so the next run skips it.

Source code: `lib/tasks/fixtures.rake`.

---

## 4. Typical workflows

### Local experimentation

1. In a `rails console` (or via the UI), create a Source or Skill that
   exercises a new edge case.
2. Mark it: `source.update!(is_promotable: true)`.
3. Run `bin/rails fixtures:promote` against the local server.
4. The new YAML entry shows up in `test/fixtures/`. Write or update a unit
   test that depends on it. Commit the test and the fixture together.

### Production trace promotion (eventual)

1. Operators (or an automated job) flip `is_promotable = true` on
   production records that surfaced an interesting bug, edge case, or
   regression.
2. A developer runs `bin/rails fixtures:promote HOST=https://example.com`
   from their workstation.
3. Fixtures land locally, tests can be written against them, and
   `is_fixtured = true` propagates back to production so the same trace
   isn't re-promoted.

---

## 5. Things this deliberately does not do

- **No authentication on the endpoints yet.** Acceptable for localhost; a
  production rollout will need a token or session check on
  `FixturePromotionsController` before the `example.com` host is real.
- **No automatic test generation.** A promoted fixture is raw material — a
  human still writes the test that asserts behavior against it.
- **No cascading promotion.** Promoting a `Source` does not promote its
  `SourceProcessingReport`s. If the surrounding context matters for a test,
  add it explicitly (or extend the controller to include it in the payload).
