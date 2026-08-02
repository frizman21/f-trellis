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
http://f-dod                    from anywhere on the tailnet
http://f-dod.localhost:8080     from this machine only
```

The tailnet name is the primary one — see
[Tailscale access](#9-tailscale-access) below. The `.localhost` fallback works
only on the machine running Dokku, and the `:8080` is required there because
that is the host port the Dokku proxy is published on. (`dokku url f-dod`
reports port 80, the *container*-side port, and so omits it.)

### Why not `f-dod.dokku.me`

Dokku assigns `<app>.dokku.me` by default, and upstream `dokku.me` is a public
domain whose records point at `127.0.0.1`. **That does not hold on this
network.** Here it resolves to something else entirely:

```
$ nslookup f-dod.dokku.me
Name:    dokku.me
Address: 10.0.0.2
Aliases: f-dod.dokku.me
```

`10.0.0.2` is not this machine, so a browser hitting `f-dod.dokku.me:8080`
times out. The vhost is configured correctly and the app is serving — the name
just points somewhere else.

The fix used here is a second vhost on the `.localhost` TLD, which browsers
resolve to loopback themselves (RFC 6761) with no DNS server and no admin
rights:

```sh
dokku domains:add f-dod f-dod.localhost
```

The app answers on both names; only `.localhost` is reachable from a browser
here. Note that system resolvers do **not** honor the RFC-6761 rule — `nslookup
f-dod.localhost` fails and `curl` needs `--resolve f-dod.localhost:8080:127.0.0.1`.
This affects command-line testing only, not browsers.

The alternative, if you prefer keeping the `dokku.me` name, is a hosts entry
(needs administrator rights):

```
127.0.0.1 f-dod.dokku.me f-agents.dokku.me
```

## 9. Tailscale access

Each app on this Dokku instance is its own Tailscale device, with its own
MagicDNS name and 100.x address:

```
$ tailscale status
100.126.137.31  home-pc     …   # the machine itself
100.70.98.0     f-dod       …
100.83.249.38   f-agents    …
```

so the apps are reached as `http://f-dod` and `http://f-agents` from any device
on the tailnet — no port numbers, no hosts-file entries, and nothing extra
published on the host.

### Why not just `home-pc:8080`

Dokku separates apps by `Host` header; Tailscale gives a machine exactly one
MagicDNS name. There is no `f-dod.home-pc` — MagicDNS has no per-machine
subdomains, so that name fails at DNS before any connection is made.

`home-pc:8080` does reach Dokku, but the `Host` matches no `server_name`, so
nginx falls through to the first server block — whichever app sorts first,
which is not necessarily the one you wanted. Giving each app its own tailnet
node sidesteps the problem entirely instead of allocating a port per app.

### How it is wired

`C:\Users\mikef\dokku\docker-compose.tailscale.yml`, alongside the Dokku
compose file, runs one `tailscale/tailscale` sidecar per app. Each has a
`TS_HOSTNAME`, a named state volume holding its node identity, and a
`TS_DEST_IP` pointing at Dokku's nginx. `TS_DEST_IP` is L3 forwarding, so the
client's `Host` header survives the hop and Dokku's vhost routing still
applies — which is why each app needs its tailnet names registered:

```sh
dokku domains:add f-dod f-dod f-dod.tail1a468b.ts.net
```

Adding another app is a new service block plus a matching `domains:add`.

Two traps worth knowing:

- **`TS_DEST_IP` is incompatible with userspace mode, and the image defaults
  `TS_USERSPACE` to true.** Omitting it is not enough; it must be set to
  `"false"` explicitly, and the sidecars then need `/dev/net/tun` with
  `NET_ADMIN` and `NET_RAW`.
- **Keep the state volumes.** They hold each node's identity. Delete one and
  that app re-registers as a new device (`f-dod-1`, `f-dod-2`, …), leaving dead
  entries in the admin console.

The sidecars reach Dokku over a dedicated network at a fixed address, attached
to the **running** container:

```sh
docker network create --subnet 172.28.0.0/16 dokku-tailnet
docker network connect --ip 172.28.0.2 dokku-tailnet dokku
```

It is done this way because Dokku's compose uses `network_mode: bridge`, which
compose cannot combine with a named network — declaring it would force a
recreate, and that wipes the installed plugins. The cost is that the attachment
is not captured in Dokku's compose file: **if the Dokku container is ever
recreated, re-run both lines above** along with reinstalling the plugins.

Auth keys live in `.env.tailscale` next to the compose file, never in the
compose file itself. Use a **reusable, non-ephemeral** key — an ephemeral key
deletes the device when the container stops. Once the nodes are registered the
key can be revoked; they stay authenticated.

The app requires sign-in and seeds no users in production. Create the first one
through the console:

```sh
dokku run f-dod bundle exec rails console
```

```ruby
User.create!(email: "you@example.com", password: "set-a-good-one")
```

## How the release task runs

Dokku **does** honor the Procfile `release` line. Confirmed from deploy output
on 0.38.1:

```
-----> Checking for predeploy task
       No predeploy task found, skipping
-----> Checking for release task
       Executing release task from Procfile in ephemeral container: bundle exec rails db:prepare
```

It runs in an ephemeral container after the image is built and **before** any
`web` or `worker` container starts, and a non-zero exit **rejects the push** —
the deploy is aborted and the previously running release, if any, stays up. So
migrations are guaranteed to complete before jobs run or traffic is served, and
there is no race between `worker` booting and the queue database existing.

`app.json`'s `scripts.dokku.predeploy` is checked first and is the place for
anything that must run even earlier; this app does not need one.

Note the release task is belt-and-braces here: `bin/docker-entrypoint` also runs
`db:prepare` whenever the command ends in `./bin/rails server`, which the `web`
line does. Both are idempotent.

## The first deploy will fail on seeds

On a **fresh** database, `db:prepare` creates the databases, loads the schema,
and then runs `db/seeds.rb` — Rails seeds only when it had to create a database.
Seeding aborts:

```
!     RubyLLM::ConfigurationError: Missing configuration for OpenAI: openai_api_key
!     /rails/db/seeds.rb:945:in `<main>'
```

This is not really a missing-key problem. Nothing populates the `models` table
on a fresh database — per the README that is a separate `ruby_llm:load_models`
or `llm:models:refresh` step — so this seed line resolves to `nil`:

```ruby
demo_model = Model.find_by(provider: "anthropic", model_id: "claude-sonnet-4-5") ||
             Model.find_by(model_id: "gpt-5-nano") || Model.first   # → nil
demo_chat = Chat.create!(model: demo_model)                          # seeds.rb:945
```

`Chat.create!(model: nil)` makes RubyLLM fall back to its default model, which
is an OpenAI one, and it validates provider configuration eagerly.

The structural work all succeeds before this point — the four databases exist
with their schemas loaded. Only seeding fails. Because every database now
exists, **re-running the push skips seeding entirely** (`db:prepare` migrates
instead), and the deploy goes through.

That leaves a partially seeded database: whatever ran before line 945. Your
options:

- **Accept it** — push again, then populate what you need by hand:
  ```sh
  dokku run f-dod bundle exec rails ruby_llm:load_models   # fill the model registry, offline
  dokku run f-dod bundle exec rails console                # create your first user
  ```
- **Start clean** — set `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` as config vars,
  or guard the `Chat.create!` block in `db/seeds.rb` against an empty model
  registry, then drop and recreate the databases so seeds run from scratch.

Seeding demo data into a production-environment database is arguably wrong
regardless; `db/seeds.rb` already guards the admin user with `Rails.env.local?`,
and the chat block could reasonably be guarded the same way.

## Other notes

**Assets and secrets at build time.** The `Dockerfile` precompiles assets with
`SECRET_KEY_BASE_DUMMY=1`, so the build needs no secrets. Config vars are
injected at run time only.
