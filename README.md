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

## The crawler's identity

The crawler reads other people's servers, so it identifies itself rather than
pretending to be a browser. Every outbound request carries:

```
f-agents/<commit> (+https://github.com/f-agents)
```

The name is **`f-agents`, not `f-dod`**, and that is deliberate. This
application is f-dod; f-agents is the project the crawler belongs to, and it is
the token a site operator sees in their logs, looks up, and writes a
`robots.txt` rule against. A stable public identity that outlives any single
application is worth more than one that matches this repository's name — so
please do not "fix" it to match.

The contact URL is what makes the crawler accountable: an operator who finds
our traffic has somewhere to go to learn what it does and how to ask it to
stop. It defaults to a real, already-public address rather than a path on
whatever host this is deployed to, because it has to resolve from the outside,
from any environment, without depending on this app being reachable.

Two settings override the defaults, read from `ENV` with a credentials
fallback, the same way the LLM keys are:

| Variable | Effect |
|---|---|
| `CRAWLER_USER_AGENT` | Replaces the agent portion. The contact URL is still appended unless the value already carries one. |
| `CRAWLER_CONTACT_URL` | Replaces the contact URL. Set it to an empty value to send none at all. |

Sending a fake browser user-agent is explicitly not supported: it would make
`robots.txt` compliance unverifiable from the server side and the traffic
unattributable, which defeats the point of identifying at all.

### What the crawler honours

Before crawling a host, the crawler reads its `robots.txt` and obeys it, per
RFC 9309: the most specific matching `User-agent` group applies, `Allow` and
`Disallow` are matched by longest pattern with `Allow` winning ties, `*` and
`$` are supported, and an empty `Disallow` means nothing is off limits.

| Response | Effect |
|---|---|
| 2xx | Parsed and obeyed. A `Crawl-delay` is recorded and used. |
| 4xx | The site stated no rules; everything is permitted. |
| 429 | **Nothing on that host is crawled** — see below. |
| 5xx or a timeout | **Nothing on that host is crawled** until it can be read. |

The last row is the conservative branch RFC 9309 specifies, and the one most
likely to surprise: a site with a flaky `robots.txt` endpoint becomes
temporarily uncrawlable. The domain's page says so when that is what happened.

The **whole** 4xx range means "permitted" (§2.3.1.3), not only 404. A `403` on
`/robots.txt` is common behind a WAF, and treating it as unreadable would make
such a site permanently uncrawlable.

`429` is the one deliberate departure. It sits inside 4xx, so the strict reading
would have the crawler take a rate-limit response as permission to crawl.
Denying is the better failure mode: over-cautious rather than rude.

Each domain's page shows what its `robots.txt` said, when it was last read, and
the crawl history that resulted. Files are re-read once a day.

The crawler waits between requests to the same host. The delay is the domain's
`min_crawl_delay_seconds` when an operator has set one, otherwise the site's own
`Crawl-delay`, otherwise one second.

A crawl can start from the site's own sitemap instead of following links from
one page. Sitemaps are found from the `Sitemap:` directives in `robots.txt`,
falling back to `/sitemap.xml`; index files are resolved one level down, gzipped
sitemaps are decompressed, and URLs outside the seed's host are dropped. The
listed pages seed the ordinary crawl, so the page cap, exclusions, `robots.txt`
and pacing all apply exactly as they do to any other crawl.

Re-fetching a page sends `If-None-Match` and `If-Modified-Since` from the last
response, so a page that has not changed costs one small request instead of a
full download and stores no second copy. The "Re-fetch content" button is
deliberately unconditional — an operator pressing it wants the content, and a
`304` with no new payload would read as a broken button.

A server that answers `429` or `5xx` on a *page* request is retried up to four
times with a growing backoff. A `Retry-After` header overrides that backoff in
both its forms (seconds and HTTP-date) — it is an instruction, not a suggestion
— and one asking for longer than fifteen minutes is refused rather than parking
a worker. A `404` or `403` is a definite answer and is not retried.

**The manual "Fetch content" button is deliberately not gated by `robots.txt`.**
An operator asking for one specific page is a different act from an automated
crawl, and gating it would make a disallowed page unfetchable even deliberately.

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

### Models served from a custom endpoint

A model the refresh never discovers — self-hosted, an inference vendor behind a
gateway, a colleague's endpoint — is registered by hand under **Model Endpoints**
in the sidebar. An endpoint carries a name, an OpenAI-compatible base URL, and
the **name of the environment variable** holding its token; the token itself
stays in the environment, beside `OPENAI_API_KEY`, and is never written to the
database or shown on a page.

```sh
# in .env, alongside the provider keys. The name is yours to choose — it only
# has to match what the endpoint's "Token variable" field says.
ACME_PAT=...
```

Then add the endpoint (`https://acme.internal/v1`, token variable `ACME_PAT`)
and press **Check**: one GET to `{base_url}/models` that costs nothing and
confirms the address and the token together, rather than discovering either is
wrong hours later in a failed run. The model ids you add to it become ordinary
rows in the registry under the `custom_endpoint` provider, offered wherever a
model is picked.

They are exempt from the staleness sweep above: nothing refreshes them, because
no provider is asked about them, so they stay in circulation until disabled.

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
and runs three services:

- `nginx` — Public-facing reverse proxy. The **only** service that publishes
  a port to the host. Config lives at `docker/nginx/default.conf`.
- `app` — Rails application, served by Thruster (container port 80, internal
  only). Runs `bin/rails db:prepare` on every start to pick up new migrations.
- `worker` — Solid Queue worker (`bin/jobs`).

Postgres is **not** part of the stack. The bundled `postgres` service is
commented out in the compose file and the app connects to a server running on
the host via `host.docker.internal`. See "Running the production stack
locally" below for what that server needs.

Request flow: `client → nginx:80 → app:80 (Thruster) → Puma`.

Solid Cache, Solid Queue, and Solid Cable each get a dedicated Postgres
database, configured via per-database `*_DATABASE_URL` environment variables.

### 1. Create `.env.production`

```sh
cp .env.production.example .env.production
```

Fill in the required values:

- `RAILS_MASTER_KEY` — contents of `config/master.key`.
- `APP_DATABASE_PASSWORD` — password for the `f_dod_user` Postgres role
  (`openssl rand -hex 32`). It must match the password actually set on that
  role, or the app will fail to connect.

`.env.production` is gitignored. Optional tuning vars (`APP_HTTP_PORT`,
`RAILS_MAX_THREADS`, `WEB_CONCURRENCY`, `APP_VERSION`, `GIT_REV`) are
documented in the example file.

`app` and `worker` load this whole file via `env_file:`, so runtime settings
the app reads from `ENV` — `CRAWLER_USER_AGENT`, `CRAWLER_CONTACT_URL`,
`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and any custom model endpoint tokens —
take effect by being present in it. That both services load it matters for the
endpoint tokens in particular: the worker is what runs extractions, reports and
evaluations, so a token only `app` could see would pass Check on the endpoint's
page and then fail every actual run.
Note that `--env-file` on its own does **not** do this: that flag only feeds
`${...}` interpolation inside the compose file and puts nothing in the
container.

### 2. Prepare the database

The stack expects a Postgres server on the host, reachable at 5432, with a
`f_dod_user` role that can log in and owns four databases:

```sh
createuser --createdb --login f_dod_user
psql -d postgres -c "ALTER ROLE f_dod_user WITH PASSWORD '<APP_DATABASE_PASSWORD>';"
for db in f_dod_production f_dod_production_cache \
          f_dod_production_queue f_dod_production_cable; do
  createdb -O f_dod_user "$db"
done
```

All four are required — Solid Cache, Solid Queue, and Solid Cable each get a
dedicated database via the per-database `*_DATABASE_URL` vars. Because
Postgres is external, `db/postgres-init/` never runs, so nothing creates the
`_cache` / `_queue` / `_cable` trio for you.

On Docker Desktop for Mac, `host.docker.internal` is proxied to the host's
loopback, so a server on the default `listen_addresses = 'localhost'` is
reachable as-is and the connection arrives as `127.0.0.1`. On Linux the host
gateway is a real interface, so a deployment there additionally needs
`listen_addresses` to cover it plus a matching `pg_hba.conf` line.

### 3. Build and start

```sh
GIT_REV=$(git rev-parse HEAD) docker compose -f docker-compose.production.yml \
  --env-file .env.production up --build -d
```

Then open <http://localhost:3080> (or whatever `APP_HTTP_PORT` is set to).

`--env-file .env.production` is required on **every** compose invocation.
Without it `${RAILS_MASTER_KEY}` has nothing to interpolate from and the
command aborts with `required variable RAILS_MASTER_KEY is missing a value`.

`GIT_REV` is what the navbar version badge displays, and it is also the
version in the default crawler user-agent. Omit it and the badge reads
"version unknown" — `AppVersion` falls back to reading `.git`, which
`.dockerignore` keeps out of the image. A shell variable takes precedence
over `.env.production` for interpolation, which is why this works as a
one-liner. It describes your *working tree*, so build from a clean checkout
or the badge will name a commit that does not match the image.

Startup order is enforced by healthchecks:

1. `app` runs `bin/rails db:prepare` (creates+loads schema on a fresh DB,
   runs `db:migrate` on an existing DB), then starts Thruster.
2. `app` becomes healthy (`GET /up`).
3. `worker` and `nginx` start once `app` is healthy.

This guarantees migrations finish before jobs run or traffic is served.
Nothing waits on Postgres, since it is outside the stack — if the host server
is down, `app` fails `db:prepare` and restarts until it comes back.

### 4. Migrations on every start

`db:prepare` is invoked by the `app` service's `command:` override on
every container start. Running an explicit `db:migrate` after a deploy is
not required — the new `app` container does it for you on boot. To apply
a one-off migration without a full deploy, run:

```sh
docker compose -f docker-compose.production.yml --env-file .env.production \
  exec app ./bin/rails db:migrate
```

### 5. TLS

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

### 6. Persistent volumes

Stateful data lives in two places:

- **The host's Postgres data directory** — outside Docker's lifecycle
  entirely, so no compose command can destroy it, `down -v` included.
- `app_storage` — a named volume holding the Rails `storage/` directory
  (used by any local file storage; safe to mount on both `app` and
  `worker`). **Survives** `docker compose down`, container rebuilds, host
  reboots, and `docker compose up` re-runs. Only `docker compose down -v`
  or `docker volume rm` will destroy it.

Back both up before destructive operations or host migrations:

```sh
# Postgres logical dump — run against the host server, not a container
pg_dump f_dod_production > backups/pg_$(date +%Y%m%d_%H%M%S).sql

# Active Storage / local files
docker run --rm -v f-dod-prod_app_storage:/data -v "$PWD/backups":/backup alpine \
  tar czf /backup/app_storage_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
```

### 7. Updating the application

Ship a new version (code + migrations) like this:

```sh
git pull
GIT_REV=$(git rev-parse HEAD) docker compose -f docker-compose.production.yml \
  --env-file .env.production up --build -d
```

What happens:

1. `build` produces a new image tagged `f-dod:${APP_VERSION:-latest}`.
2. `up -d` recreates the `app` and `worker` containers using the new
   image, leaving `nginx` untouched (its config didn't change). The host's
   Postgres is never touched by a deploy.
3. The new `app` container runs `bin/rails db:prepare`, applying any
   pending migrations against the existing database.
4. Once `app` is healthy, `worker` starts (or restarts) on the new image.

Recreating `app` gives it a new container IP, which `nginx` will not pick up
on its own — its `upstream` block resolves the name once at startup, so it
serves `502` until restarted. Until that is fixed in
`docker/nginx/default.conf`, follow a deploy with:

```sh
docker compose -f docker-compose.production.yml --env-file .env.production \
  restart nginx
```

If only nginx config changed, restart just that service:

```sh
docker compose -f docker-compose.production.yml --env-file .env.production \
  up -d --force-recreate nginx
```

To roll back, set `APP_VERSION` to a previously built image tag in
`.env.production` and re-run `up -d`. (Tag images explicitly before
upgrading if you want this option — by default the build overwrites
`f-dod:latest`.)

### 8. Adding the cache/queue/cable databases to an existing deployment

If you are upgrading a deployment that predates the Solid Cache / Queue /
Cable split, create the three extra databases once, on the host server:

```sh
psql -d postgres -c \
  "CREATE DATABASE f_dod_production_cache OWNER f_dod_user;
   CREATE DATABASE f_dod_production_queue OWNER f_dod_user;
   CREATE DATABASE f_dod_production_cable OWNER f_dod_user;"
```

`db/postgres-init/00-create-databases.sh` did this automatically when
Postgres ran as a container in this stack. It is dead code as long as the
`postgres` service stays commented out, and is kept only for the case where
that service is restored.

## Deploying to a local Dokku instance

An alternative deployment target: a containerized Dokku running on the
workstation, which builds the same `Dockerfile` but replaces the Compose file
with a `git push`-driven workflow. The repo carries a `Procfile` and `app.json`
for it, declaring the same `web` + `worker` split.

- **[`docs/dokku_setup_guide.md`](docs/dokku_setup_guide.md)** — one-time setup:
  installing the Postgres plugin, creating the app, adding the git remote,
  provisioning the database, the config vars Solid Queue/Cache/Cable need
  beyond what `postgres:link` sets, and the Tailscale sidecar that gives the
  app its own tailnet node.
- **[`docs/dokku_devops.md`](docs/dokku_devops.md)** — day-to-day operation:
  deploying, starting and stopping, logs, console access, backups, teardown,
  managing the Tailscale sidecars, and what does and does not come back after a
  reboot.

Deploys are automatic: a poller ships the newest commit on `main` that CI has
passed, so merging a PR is enough. `git push dokku main` still works for
deploying a branch or forcing a redeploy.

The app runs as its own Tailscale device, so once deployed it is served at
`http://f-dod` from anywhere on the tailnet. On the Dokku host itself,
`http://f-dod.localhost:8080` also works.
