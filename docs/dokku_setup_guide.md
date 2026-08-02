# Deploying to a local Dokku instance

This is a **one-time setup guide** for deploying f-dod to the containerized
Dokku instance running on this workstation. For day-to-day operation once the
app is deployed, see [`dokku_devops.md`](dokku_devops.md).

This is a third deployment target, independent of the two already documented in
the README: it does not use `docker-compose.production.yml`, and it does not use
Kamal (`config/deploy.yml` is still stock Rails scaffolding). Dokku builds the
same `Dockerfile` the other targets use.

## How Dokku is reached

Dokku itself runs as a container named `dokku` (image `dokku/dokku:0.38.1`),
publishing three host ports:

| Host port | Container port | Purpose |
| --- | --- | --- |
| `3022` | `22` | Dokku's SSH interface — git pushes and remote commands |
| `8080` | `80` | The proxy serving deployed apps over HTTP |
| `8443` | `443` | The same, over HTTPS |

It mounts the host Docker socket, so the app containers it launches are siblings
on the host daemon rather than nested children.

There are two equivalent ways to issue a Dokku command. Throughout these docs
commands are written bare, as `dokku <command>` — run them either way:

```sh
# Over SSH (works from anywhere, needs your key authorized)
ssh -p 3022 dokku@localhost <command>

# Directly in the container (always works, no key needed)
docker exec dokku dokku <command>
```

Commands needing a TTY (`dokku enter`, `dokku run`, `postgres:connect`) need
`ssh -t` or `docker exec -it`.

## 1. Install the service plugins

Dokku ships only core plugins. Postgres and Redis are separate:

```sh
dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres
dokku plugin:install https://github.com/dokku/dokku-redis.git redis
```

Run these as root — `docker exec dokku dokku plugin:install …` already is.

> **If the Dokku container is ever rebuilt**, the plugins must be reinstalled,
> because they live in the image rather than in the `dokku_dokku-data` volume.
> Existing *services* survive: their metadata is under
> `/var/lib/dokku/services/` on the volume, and their containers keep running
> untouched. Reinstalling the plugin re-adopts them, and `postgres:list` shows
> them again. Linked apps never notice the outage, because a link is just a
> `DATABASE_URL` config var — but you cannot manage the services until the
> plugin is back.

f-dod itself does not need Redis (see [Why four databases](#why-four-databases)
below); the Redis plugin is listed because the sibling `f-agents` app on this
same Dokku instance does.

## 2. Create the app

```sh
dokku apps:create f-dod
```

This assigns the vhost `f-dod.dokku.me` automatically, from Dokku's global
domain (`dokku.me`).

## 3. Add the git remote

Dokku deploys by receiving a git push. From this checkout:

```sh
git remote add dokku ssh://dokku@localhost:3022/f-dod
```

Verify it connects before pushing anything:

```sh
git ls-remote dokku
```

Empty output means success — connected, no refs yet. An error here is an SSH
problem, not a Dokku one. Your public key must be registered:

```sh
dokku ssh-keys:list
# to add one:
dokku ssh-keys:add <name> < ~/.ssh/id_ed25519.pub
```

## 4. Commit `Procfile` and `app.json`

Both files are in the repo root and must be committed for Dokku to see them.

`Procfile` declares the process types:

```
release: bundle exec rails db:prepare
web: ./bin/thrust ./bin/rails server
worker: ./bin/jobs
```

`app.json` declares how many of each to run:

```json
{
  "formation": {
    "web":    { "quantity": 1 },
    "worker": { "quantity": 1 }
  }
}
```

The `worker` line runs Solid Queue via `bin/jobs`, matching the `worker` service
in `docker-compose.production.yml`. Do **not** also set `SOLID_QUEUE_IN_PUMA` —
that runs the job supervisor inside Puma, which would duplicate the dedicated
worker.

## 5. Provision Postgres

```sh
dokku postgres:create f-dod-db
dokku postgres:link f-dod-db f-dod
```

The link sets `DATABASE_URL` on the app and restarts it. The generated URL looks
like:

```
postgres://postgres:<generated>@dokku-postgres-f-dod-db:5432/f_dod_db
```

Note the role is the `postgres` **superuser**, not the unprivileged `app` role
used by `docker-compose.production.yml`. That matters for the next step.

## 6. Set the remaining config vars

### Why four databases

`config/database.yml` declares four production databases — `primary`, `cache`,
`queue`, and `cable` — because Solid Cache, Solid Queue, and Solid Cable each
own one. Dokku's link only sets `DATABASE_URL`, which covers `primary`. Rails
reads the other three from `<NAME>_DATABASE_URL` variables, which must be set
by hand.

This also means f-dod needs no `REDIS_URL`: the Solid stack keeps queues, cache,
and cable in Postgres. (The `f-agents` app on this instance uses Sidekiq and
does need Redis — do not copy its config vars.)

Derive the three extra URLs from the linked one so the generated password stays
in one place:

```sh
DB=$(dokku config:get f-dod DATABASE_URL)
BASE=${DB%/*}

dokku config:set --no-restart f-dod \
  CACHE_DATABASE_URL="$BASE/f_dod_db_cache" \
  QUEUE_DATABASE_URL="$BASE/f_dod_db_queue" \
  CABLE_DATABASE_URL="$BASE/f_dod_db_cable" \
  RAILS_MASTER_KEY="$(cat config/master.key)"
```

These three databases do not exist yet. They are created on first deploy by
`db:prepare`, which can only do so because the linked role is a superuser. If
you ever re-link the app to a service using a non-superuser role, create them
manually first (see `dokku_devops.md`).

`--no-restart` is safe before the first deploy and avoids a pointless restart;
drop it when changing config on a running app.

### About `RAILS_MASTER_KEY`

Setting it is belt-and-braces: `config/master.key` is currently **tracked in
git**, so it is baked into the image and Rails would find it regardless. That
tracked key is worth fixing on its own merits — it is a live secret in the
repository history — and the moment it is gitignored, this config var becomes
load-bearing.

## 7. Deploy

```sh
git push dokku main
```

Dokku detects the `Dockerfile`, builds it, runs the `release` command, then
starts one `web` and one `worker` container. Subsequent deploys are the same
push.

If your working branch is not `main`, push it to Dokku's deploy branch
explicitly:

```sh
git push dokku my-branch:main
```

## 8. Reach the app

```
http://f-dod.dokku.me:8080
```

`dokku.me` is a public DNS name that resolves to `127.0.0.1`, so no hosts-file
entry is needed. The `:8080` is required — it is the host port the Dokku proxy
is published on.

Confirm what Dokku thinks the URL is with `dokku url f-dod` (which reports port
80, the *container*-side port, and so omits the `:8080`).

The app requires sign-in and seeds no users in production. Create the first one
through the console:

```sh
dokku run f-dod bundle exec rails console
```

```ruby
User.create!(email: "you@example.com", password: "set-a-good-one")
```

## Known caveats

**The `release:` line may not run.** Heroku runs the `release` process type on
every deploy; Dokku's documented equivalent is `app.json` →
`scripts.dokku.predeploy`, and it is unconfirmed whether Dokku 0.38 honors a
Procfile `release` line for a Dockerfile-built app. Migrations are covered
anyway, because `bin/docker-entrypoint` runs `db:prepare` whenever the command
ends in `./bin/rails server` — which the `web` line does.

The residual risk is a **race on first deploy**: the `worker` container has no
such entrypoint branch and may boot against a queue database that `web` has not
created yet. Dokku's restart policy is `on-failure:10`, so a slow first
migration could exhaust the worker's restarts. If that happens, the fix is to
make the migration an explicit pre-deploy step:

```json
{
  "scripts": { "dokku": { "predeploy": "bundle exec rails db:prepare" } },
  "formation": {
    "web":    { "quantity": 1 },
    "worker": { "quantity": 1 }
  }
}
```

Check with `dokku ps:report f-dod` after the first deploy; if `worker` is not
running, `dokku logs f-dod -p worker` will show the connection error.

**Assets and secrets at build time.** The `Dockerfile` precompiles assets with
`SECRET_KEY_BASE_DUMMY=1`, so the build needs no secrets. Config vars are
injected at run time only.
