# README

## Initializing the local environment

The application runs in Docker. All Rails and database commands below execute inside the `web` container.

### 1. Create a local `.env`

Copy the example file and fill in any values you need to override:

```sh
cp .env.example .env
```

`.env` is gitignored. The default `docker-compose.yml` works without any overrides.

#### Running two checkouts at once

The web container always listens on port 3000 internally; `WEB_PORT` controls
the **host** port it is published on (default `3001`). To run a second checkout
alongside this one, give it a different port — either in its `.env`:

```sh
WEB_PORT=3002
```

or per-command:

```sh
WEB_PORT=3002 docker-compose up -d
```

Compose derives its project name from the directory name, so two checkouts in
differently-named directories already get separate containers, networks, and
volumes. If both live in identically-named directories, set
`COMPOSE_PROJECT_NAME` in one of them as well. Postgres is not published to the
host, so it needs no deconfliction.

### 2. Start the containers

```sh
docker-compose up -d
```

On first boot the `web` container runs `bundle install` followed by `bin/rails db:prepare`, which creates and migrates the **development** database.

### 3. Create the test database

`db:prepare` only touches the current `RAILS_ENV` (development). Create the test database explicitly:

```sh
docker-compose exec web bundle exec rails db:create RAILS_ENV=test
docker-compose exec web bundle exec rails db:schema:load RAILS_ENV=test
```

### 4. Seed development data (optional)

```sh
docker-compose exec web bundle exec rails db:seed
```

### 5. Sign in

The app requires sign-in for every page and public sign-up is disabled. Seeding
creates a development login:

- **Email:** `admin@example.com`
- **Password:** `Password1`

Sign in at <http://localhost:3001/users/sign_in> (or whatever `WEB_PORT` you set).

This user is only seeded in development and test. To create additional users —
or any user in production — use the Rails console:

```sh
docker-compose exec web bundle exec rails console
```

```ruby
User.create!(email: "you@example.com", password: "set-a-good-one")
```

## The LLM model registry

Model pickers (skills, source processing reports) read from the `models` table,
not from a hardcoded list. `app/models/model.rb` is RubyLLM's `acts_as_model`,
so this table *is* the registry RubyLLM resolves against — it only falls back to
the JSON snapshot bundled in the gem when the table is empty.

There are two ways to populate it:

| Command | Source | Network |
| --- | --- | --- |
| `rails ruby_llm:load_models` | The snapshot bundled inside the installed `ruby_llm` gem. Only advances when you bump the gem. | none |
| `rails llm:models:refresh` | The **live** `/models` endpoint of every configured provider, plus models.dev metadata. | yes |

The refresh is also wired to the **Refresh from providers** button on `/models`,
which enqueues `RefreshModelsJob`.

### How retired models are handled

A refresh never deletes rows — `Chat`, `SourceProcessingReport` and `Skill`
records referencing an old model must keep resolving. Instead every model a
provider returned is stamped with one shared `last_seen_at`. `Model.current`
selects the rows carrying the newest stamp, and `Model.selectable` narrows that
to the providers offered in pickers, so retired models drop out of dropdowns
while remaining in the table. `/models` hides them behind a "show" toggle.

This is fail-safe by design: if a provider is unconfigured or its API errors,
RubyLLM preserves that provider's existing models, so they get stamped and are
never falsely marked retired.

### Requirements and known issues

- A provider is only fetched if its key is configured (see
  `config/initializers/ruby_llm.rb`). With no `ANTHROPIC_API_KEY`, Anthropic
  models are preserved as-is and new ones never appear.
- **ruby_llm 1.14.1 cannot ingest models.dev.** 173 models across 35 providers
  publish `release_date`/`last_updated` as `YYYY-MM`; the gem interpolates that
  into `"2026-01 00:00:00 UTC"` and `Utils.to_time` raises an unrescued
  `ArgumentError: argument out of range`, aborting the whole feed. The refresh
  logs `Failed to fetch models.dev` and continues with provider data only.
  Until this is fixed upstream, a provider's models can only be refreshed by
  configuring that provider's API key.

## Running the test suite

```sh
docker-compose exec web bundle exec rails test
```

To reset the test database and run the full suite:

```sh
docker-compose exec web bundle exec rails test:db
```

See `CLAUDE.md` for the full command reference.

## Continuous integration

`.github/workflows/ci.yml` runs three jobs on every pull request:

| Job | What it does |
| --- | --- |
| `test` | `bin/rails db:test:prepare test` |
| `system-test` | `bin/rails db:test:prepare test:system`, uploading screenshots on failure |
| `quality` | Change-request traceability gate (pull requests only) |

### The quality gate

`quality` runs the `sw-factory` quality agent from
[software-factory-plugin](https://github.com/frizman21/software-factory-plugin)
via `anthropics/claude-code-action`. It checks that the PR body links a change
request with a GitHub closing keyword (`Closes #123`), that the change request
defines a scope and a test approach, and that the diff and its tests are
consistent with both. It then posts a review or a comment on the PR.

It is **not** a bug hunter or a style reviewer — the two test jobs own
everything a deterministic check can decide. That is also why `quality` declares
`needs: [test, system-test]`: a branch whose tests fail is never reviewed, so no
tokens are spent on it. GitHub Actions has no cross-workflow `needs:`, which is
why this job lives in `ci.yml` rather than its own workflow file.

Requirements:

- **`ANTHROPIC_API_KEY`** must be set as a repository secret
  (Settings → Secrets and variables → Actions).
- **`id-token: write`** must stay in the job's permissions. The action mints a
  GitHub OIDC token to obtain its app token, and fails the job without it even
  though Anthropic auth uses the static API key.
- The marketplace is **pinned by a second `actions/checkout`** that clones the
  plugin repo at a fixed ref into `.sw-factory-plugin`, which is then passed to
  `plugin_marketplaces` as a local path. `plugin_marketplaces` has no ref syntax
  of its own and rejects anything that is not a bare `https://….git` URL — a
  trailing `#v0.1.0` fails with *Invalid marketplace URL format* — so checking
  the ref out is the pin. Leave it pinned: unpinned, an edit to the plugin
  silently changes what every open PR is judged against. Bumping the gate is a
  deliberate edit to this file.
- The **`Report gate failure` step must stay.** The agent comments on what it
  finds, but it cannot comment on its own death — a bad ref, an expired key, or
  exhausting `--max-turns` kills the step before the skill posts anything. That
  step leaves a comment saying the PR is *unreviewed* (not approved), with a
  link to the logs.

#### A PR that edits `ci.yml` is not reviewed

The action compares this workflow file against the copy on the default branch
and refuses to run when they differ, so a PR cannot rewrite the gate that judges
it. That check is why the gate is trustworthy, but note how it fails:

> Workflow validation failed. The workflow file must exist and have identical
> content to the version on the repository's default branch.

**It skips with a green check, not a red one.** Any PR touching `ci.yml` will
show `quality` passing without a review having happened. Read the job log rather
than the check mark when the diff includes this file, and expect the gate to be
inactive until the change is merged to `main`.

## Production deployment

The repo includes `docker-compose.production.yml` for single-host production
deployments. It builds the existing `Dockerfile` (Thruster + non-root user)
and runs four services:

- `nginx` — Public-facing reverse proxy. The **only** service that publishes
  a port to the host. Config lives at `docker/nginx/default.conf`.
- `app` — Rails application, served by Thruster (container port 80, internal
  only). Runs `bin/rails db:prepare` on every start to pick up new migrations.
- `worker` — Solid Queue worker (`bin/jobs`).
- `postgres` — Postgres 17. An init script creates the Solid cache, queue,
  and cable databases on first boot of an empty data volume.

Request flow: `client → nginx:80 → app:80 (Thruster) → Puma`.

Solid Cache, Solid Queue, and Solid Cable each get a dedicated Postgres
database, configured via per-database `*_DATABASE_URL` environment variables.

### 1. Create `.env.production`

```sh
cp .env.production.example .env.production
```

Fill in the required values:

- `RAILS_MASTER_KEY` — contents of `config/master.key`.
- `APP_DATABASE_PASSWORD` — password for the `app` Postgres role
  (`openssl rand -hex 32`).

`.env.production` is gitignored. Optional tuning vars (`APP_HTTP_PORT`,
`RAILS_MAX_THREADS`, `WEB_CONCURRENCY`, `APP_VERSION`) are documented in
the example file.

### 2. Build and start

```sh
docker compose -f docker-compose.production.yml --env-file .env.production build
docker compose -f docker-compose.production.yml --env-file .env.production up -d
```

Startup order is enforced by healthchecks:

1. `postgres` becomes healthy (`pg_isready`).
2. `app` runs `bin/rails db:prepare` (creates+loads schema on a fresh DB,
   runs `db:migrate` on an existing DB), then starts Thruster.
3. `app` becomes healthy (`GET /up`).
4. `worker` and `nginx` start once `app` is healthy.

This guarantees migrations finish before jobs run or traffic is served.

### 3. Migrations on every start

`db:prepare` is invoked by the `app` service's `command:` override on
every container start. Running an explicit `db:migrate` after a deploy is
not required — the new `app` container does it for you on boot. To apply
a one-off migration without a full deploy, run:

```sh
docker compose -f docker-compose.production.yml --env-file .env.production \
  exec app ./bin/rails db:migrate
```

### 4. TLS

The bundled nginx terminates plain HTTP only. Two options for HTTPS:

- **Recommended** — put a TLS terminator in front of nginx (Cloudflare
  Tunnel, an external load balancer / managed cert) and bind nginx to a
  loopback interface in `.env.production`:

  ```env
  APP_HTTP_PORT=127.0.0.1:8080
  ```

- **Self-managed certs** — extend `docker/nginx/default.conf` with a
  `listen 443 ssl http2` server block (a commented template is included
  at the bottom of that file), mount certs into the nginx container via a
  bind mount, and publish `443:443` instead of `80:80`.

### 5. Persistent volumes

Two named volumes hold all stateful data:

- `postgres_data` — Postgres data directory. **Survives** `docker compose
  down`, container rebuilds, host reboots, and `docker compose up`
  re-runs. Only `docker compose down -v` or `docker volume rm` will
  destroy it.
- `app_storage` — Rails `storage/` directory (used by any local file
  storage; safe to mount on both `app` and `worker`).

Back both up before destructive operations or host migrations:

```sh
# Postgres logical dump
docker compose -f docker-compose.production.yml --env-file .env.production \
  exec postgres pg_dumpall -U app > backups/pg_$(date +%Y%m%d_%H%M%S).sql

# Active Storage / local files
docker run --rm -v f-dod_app_storage:/data -v "$PWD/backups":/backup alpine \
  tar czf /backup/app_storage_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
```

### 6. Updating the application

Ship a new version (code + migrations) like this:

```sh
git pull
docker compose -f docker-compose.production.yml --env-file .env.production build
docker compose -f docker-compose.production.yml --env-file .env.production up -d
```

What happens:

1. `build` produces a new image tagged `f-dod:${APP_VERSION:-latest}`.
2. `up -d` recreates the `app` and `worker` containers using the new
   image, leaving `postgres` and `nginx` untouched (their configs didn't
   change). The `postgres_data` volume is preserved.
3. The new `app` container runs `bin/rails db:prepare`, applying any
   pending migrations against the existing database.
4. Once `app` is healthy, `worker` starts (or restarts) on the new image.

If only nginx config changed, restart just that service:

```sh
docker compose -f docker-compose.production.yml --env-file .env.production \
  up -d --force-recreate nginx
```

To roll back, set `APP_VERSION` to a previously built image tag in
`.env.production` and re-run `up -d`. (Tag images explicitly before
upgrading if you want this option — by default the build overwrites
`f-dod:latest`.)

### 7. Adding the cache/queue/cable databases to an existing deployment

The Postgres init script only runs against an empty data volume. If you
are upgrading a deployment whose `postgres_data` volume predates the
init script, create the databases manually once:

```sh
docker compose -f docker-compose.production.yml --env-file .env.production \
  exec postgres psql -U app -d app_production -c \
  "CREATE DATABASE app_production_cache OWNER app;
   CREATE DATABASE app_production_queue OWNER app;
   CREATE DATABASE app_production_cable OWNER app;"
```
