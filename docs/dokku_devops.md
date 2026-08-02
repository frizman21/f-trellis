# Dokku operations reference

Day-to-day commands for the f-dod app running on the local Dokku instance. For
the one-time setup that produced this environment, see
[`dokku_setup_guide.md`](dokku_setup_guide.md).

Every command below is written bare, as `dokku <command>`. Run it either way:

```sh
ssh -p 3022 dokku@localhost <command>      # over SSH
docker exec dokku dokku <command>          # inside the container
```

Anything interactive — `enter`, `run`, `postgres:connect` — needs a TTY: use
`ssh -t -p 3022 dokku@localhost …` or `docker exec -it dokku dokku …`.

Throughout: the app is `f-dod`, its database service is `f-dod-db`, and its
process types are `web` and `worker`.

## Deploying

```sh
git push dokku main                 # build and deploy the current main
git push dokku my-branch:main       # deploy a non-main branch
git push dokku main --force         # after a rebase; Dokku takes the new tree
```

Rebuild from the last-pushed source without a new commit — the way to pick up a
changed config var that requires a fresh build:

```sh
dokku ps:rebuild f-dod
```

Inspect builds — `builds:output` is how you read the build log itself, and
`logs:failed` is the shortcut to the last failed deploy:

```sh
dokku builds:list f-dod                 # build history
dokku builds:output f-dod current       # output of the in-flight build
dokku builds:output f-dod <build-id>    # output of a past build
dokku builds:cancel f-dod               # stop a runaway build
dokku logs:failed f-dod                 # last failed deploy
```

## Starting, stopping, restarting

```sh
dokku ps:report f-dod               # deployed? running? how many of each process?
dokku ps:stop f-dod                 # stop all processes (containers removed)
dokku ps:start f-dod                # start them again from the current image
dokku ps:restart f-dod              # stop + start
dokku ps:restart f-dod worker       # restart just one process type
```

Scale process counts. This takes effect immediately and **overrides
`app.json`'s formation** until the next deploy:

```sh
dokku ps:scale f-dod web=1 worker=2
dokku ps:scale f-dod                # show current scale
dokku ps:scale f-dod worker=0       # pause job processing without touching web
```

After a host or Docker-daemon reboot, bring back everything that was running:

```sh
dokku ps:restore
```

## Logs

```sh
dokku logs f-dod                    # recent output, all processes
dokku logs f-dod -t                 # follow
dokku logs f-dod -n 200             # last 200 lines
dokku logs f-dod -p worker          # only the worker process
dokku logs f-dod -p web -t          # follow only web
```

`logs:failed` is the one to reach for when a deploy died — the regular `logs`
command only shows containers that currently exist.

## Shell and console access

```sh
dokku enter f-dod web                              # shell in the running web container
dokku run f-dod bundle exec rails console          # one-off container, Rails console
dokku run f-dod bundle exec rails db:migrate       # one-off migration
dokku run f-dod bash                               # one-off shell
```

`enter` attaches to a **running** container — use it to inspect live state.
`run` starts a **fresh** container from the deployed image and removes it on
exit; it is the right choice for migrations and rake tasks, and it works even
when the app is stopped.

Note `run` containers get the same config vars, so they hit the real database.

## Config vars

```sh
dokku config:show f-dod                       # all vars (values in plaintext)
dokku config:get f-dod DATABASE_URL           # one value, script-friendly
dokku config:set f-dod RAILS_LOG_LEVEL=debug  # set and restart
dokku config:set --no-restart f-dod FOO=bar   # set without restarting
dokku config:unset f-dod FOO
```

Setting a config var restarts the app but does **not** rebuild the image. Vars
consumed at build time need `dokku ps:rebuild f-dod` afterwards.

Vars f-dod expects, and where they come from:

| Var | Source |
| --- | --- |
| `DATABASE_URL` | set automatically by `postgres:link` |
| `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, `CABLE_DATABASE_URL` | set by hand — see the setup guide |
| `RAILS_MASTER_KEY` | contents of `config/master.key` |

Optional tuning vars the app understands: `RAILS_MAX_THREADS`,
`WEB_CONCURRENCY`, `JOB_CONCURRENCY`, `RAILS_LOG_LEVEL`.

## The Postgres service

```sh
dokku postgres:list                 # all services on this Dokku instance
dokku postgres:info f-dod-db        # status, version, internal IP, links
dokku postgres:logs f-dod-db -t     # follow Postgres' own logs
dokku postgres:connect f-dod-db     # interactive psql (needs a TTY)
```

Lifecycle — note these act on the *database service*, independently of the app:

```sh
dokku postgres:stop f-dod-db
dokku postgres:start f-dod-db
dokku postgres:restart f-dod-db
```

Linking:

```sh
dokku postgres:links f-dod-db       # which apps use this service
dokku postgres:app-links f-dod      # which services this app uses
dokku postgres:unlink f-dod-db f-dod
```

`unlink` removes `DATABASE_URL` and restarts the app. It does **not** remove the
three `*_DATABASE_URL` vars you set by hand — those still point at a service the
app can no longer reach, so unset them too if you are re-pointing the app.

### Creating the Solid databases manually

`db:prepare` creates `f_dod_db_cache`, `f_dod_db_queue`, and `f_dod_db_cable`
automatically, because the linked role is the `postgres` superuser. If you are
re-pointing the app at a service whose role lacks `CREATEDB`, create them first:

```sh
dokku postgres:connect f-dod-db
```

```sql
CREATE DATABASE f_dod_db_cache;
CREATE DATABASE f_dod_db_queue;
CREATE DATABASE f_dod_db_cable;
```

### Backup and restore

`postgres:export` writes a custom-format dump to stdout — redirect it to a file:

```sh
docker exec dokku dokku postgres:export f-dod-db > backups/f-dod_$(date +%Y%m%d_%H%M%S).dump
```

Restore into a service (this **overwrites** the target database):

```sh
docker exec -i dokku dokku postgres:import f-dod-db < backups/f-dod_20260802_120000.dump
```

Export covers the primary database only. The cache, queue, and cable databases
hold regenerable state — dumping them is usually not worth it, but if you want
them, use `psql`/`pg_dump` through `postgres:connect`.

Clone a service, data and all, to experiment against a copy:

```sh
dokku postgres:clone f-dod-db f-dod-db-scratch
```

## Domains and the proxy

```sh
dokku domains:report f-dod              # current vhosts
dokku urls f-dod                        # all URLs Dokku knows about
dokku domains:add f-dod f-dod.localhost
dokku domains:remove f-dod f-dod.dokku.me
```

The app answers on three names, in descending order of usefulness:

| URL | Reachable from | Notes |
| --- | --- | --- |
| `http://f-dod` | anywhere on the tailnet | its own Tailscale node — see below |
| `http://f-dod.localhost:8080` | this machine only | browsers resolve `.localhost` to loopback themselves |
| `http://f-dod.dokku.me:8080` | nowhere | `dokku.me` resolves to `10.0.0.2` on this network, not loopback |

`dokku urls` reports port 80 (the container-side port) and so omits the `:8080`
the `.localhost` name needs.

Testing `.localhost` from the command line needs an explicit resolve, because
the RFC-6761 loopback rule is a browser/resolver-library behavior that
`nslookup` and `curl` do not apply:

```sh
curl --resolve f-dod.localhost:8080:127.0.0.1 http://f-dod.localhost:8080/
curl -H 'Host: f-dod.localhost:8080' http://localhost:8080/     # equivalent
```

The tailnet name needs no such trick — `curl http://f-dod/` just works from any
device on the tailnet.

If routing looks wrong after adding a domain, rebuild the proxy config:

```sh
dokku proxy:build-config f-dod
```

## Tailscale sidecars

Each app is its own Tailscale device, run as a sidecar container defined in
`C:\Users\mikef\dokku\docker-compose.tailscale.yml`. These commands run from
that directory, not the app repo:

```sh
docker compose -f docker-compose.tailscale.yml --env-file .env.tailscale up -d
docker compose -f docker-compose.tailscale.yml --env-file .env.tailscale down
docker compose -f docker-compose.tailscale.yml --env-file .env.tailscale restart ts-f-dod
```

Status and logs:

```sh
tailscale status                    # every node, including f-dod and f-agents
docker logs ts-f-dod --tail 20      # "Startup complete" means it registered
docker exec ts-f-dod tailscale ip -4
```

The sidecars are independent of the app. Restarting `ts-f-dod` does not touch
the running app, and redeploying the app does not touch its tailnet node.

### Adding a new app to the tailnet

1. Copy a service block in the compose file, changing the container name,
   `hostname`, `TS_HOSTNAME`, and state volume.
2. Add the volume under `volumes:`.
3. Register the names with Dokku so its vhost routing matches:
   ```sh
   dokku domains:add <app> <app> <app>.tail1a468b.ts.net
   ```
4. Bring it up with the `up -d` line above.

### Troubleshooting

**A tailnet name resolves but serves the wrong app.** The vhost is missing, so
Dokku fell through to its first server block. Check `dokku domains:report <app>`
includes the tailnet names.

**`invalid configuration: TS_DEST_IP is not supported with TS_USERSPACE`.**
The image defaults `TS_USERSPACE` to true. It must be set to `"false"`
explicitly — removing the line is not enough.

**A node reappears as `f-dod-1`.** Its state volume was deleted, so it
registered as a new device. Remove the stale entry in the Tailscale admin
console; the volumes are what keep identities stable.

**Nothing resolves after recreating the Dokku container.** The sidecars reach
Dokku over the `dokku-tailnet` network, attached to the running container
rather than declared in its compose file. Re-attach it:

```sh
docker network connect --ip 172.28.0.2 dokku-tailnet dokku
```

## Housekeeping

Dokku keeps every deployed image, which accumulates fast on a workstation:

```sh
dokku cleanup                       # remove exited containers and dangling images
docker image prune -a               # more aggressive, host-wide
docker system df                    # see what is actually using space
```

Check what is running at the Docker level — app containers are siblings on the
host daemon, named `<app>.<process>.<index>`:

```sh
docker ps --filter name=f-dod
```

## Tearing down

Destroy the app. This removes its containers, config, and git repo, but leaves
the database service alone:

```sh
dokku apps:destroy f-dod
```

Destroy the database service. This **permanently deletes the data**, and is
refused while any app is still linked:

```sh
dokku postgres:unlink f-dod-db f-dod
dokku postgres:destroy f-dod-db
```

Both prompt for confirmation; `-f` skips the prompt. Take an export first.

Destroying the app does not remove its Tailscale node — that is a separate
container. Remove the sidecar and its state volume, then delete the now-offline
device in the Tailscale admin console:

```sh
docker compose -f docker-compose.tailscale.yml --env-file .env.tailscale rm -sf ts-f-dod
docker volume rm dokku_ts-f-dod-state
```

## Troubleshooting

**Push is rejected or hangs.** Test the transport on its own with
`git ls-remote dokku` — empty output is success. Failures here are SSH, not
Dokku: check `dokku ssh-keys:list` and that port 3022 is published
(`docker ps --filter name=dokku`).

**Deploy fails during build.** `dokku logs:failed f-dod` has the build output.
The build runs `bin/rails assets:precompile` with a dummy secret, so a failure
there is a real asset problem, not a missing config var.

**Push rejected with `pre-receive hook declined`.** The build succeeded but the
`release` task exited non-zero, so Dokku aborted the deploy. The failure is in
the push output itself, between `Start of f-dod release task` and `End of`.
Nothing is deployed and any previously running release stays up.

On a *fresh* database this is most likely the seed failure documented in the
setup guide — `db:prepare` seeds a newly created database and
`db/seeds.rb` aborts on an empty model registry. Pushing again skips seeding and
succeeds.

**Worker keeps restarting.** Check `dokku logs f-dod -p worker`. The queue
database not existing is unlikely to be the cause, since the `release` task runs
`db:prepare` to completion before any process starts — a failure there would
have rejected the push instead.

**App returns 502.** The container is not listening. `dokku ps:report f-dod`
tells you whether it is running at all; `dokku logs f-dod -p web` tells you why
it exited. A Rails boot failure from a missing `RAILS_MASTER_KEY` or an
unreachable database looks exactly like this.

**Everything is stopped after a reboot.** `dokku ps:restore`.

## A note on the other apps here

This Dokku instance also hosts `f-agents`, with its own `f-agents-db` and
`f-agents-redis` services and its own `ts-f-agents` Tailscale sidecar. Every
command above takes an explicit app or service name, so nothing here is
ambiguous — but these are instance-wide and will affect that app too:

- `dokku ps:stop --all`, `dokku cleanup`, `docker image prune -a`
- `docker compose -f docker-compose.tailscale.yml … down` — stops **every**
  sidecar, taking all apps off the tailnet. Name the service to scope it.

Note `f-agents` is deployed twice on this machine: once on Dokku (reachable at
`http://f-agents`) and once as a standalone `f-agents-production` compose stack
published on port 3000. They are separate deployments with separate databases;
Dokku does not manage the latter.
