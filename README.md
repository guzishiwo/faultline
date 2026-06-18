# Faultline

[中文说明](docs/README.zh-CN.md)

Faultline is a small self-hosted error tracker built with Phoenix, LiveView, and
SQLite. It is designed for teams that want Sentry-compatible error ingestion
without running PostgreSQL, Redis, Kafka, ClickHouse, or object storage.

> Status: early V1.0 work. The goal is a practical single-node open-source
> edition, not a full Sentry replacement.

## Why Faultline exists

Most small teams do not need a complete observability platform just to answer
one urgent question: "what broke in production, and how do we fix it?"

Sentry is powerful, but self-hosting it is intentionally a large distributed
system. GlitchTip is broader and covers error tracking, performance monitoring,
uptime monitoring, and logs. Bugsink is closer to Faultline's self-hosted error
tracking focus and is already a strong option.

Faultline exists for a narrower reason: make Sentry-compatible error tracking
feel like a normal application you can understand, run, back up, and maintain
yourself. The open-source V1.0 line is deliberately single-node, SQLite-first,
and focused on the daily issue triage workflow rather than becoming another
large monitoring stack.

The scope is intentionally small:

- Keep the ingest path boring: accept common Sentry SDK payloads and store them
  locally.
- Keep operations boring: one Phoenix release, one SQLite database, one
  persistent `/data` volume.
- Keep the UI direct: fast issue scanning, readable event detail pages, useful
  search, retention controls, and alerts without a maze of admin screens.
- Keep the codebase maintainable: Phoenix contexts, LiveView screens, Ecto
  schemas, and a small number of moving parts.

## What it does

- Accepts Sentry SDK event ingestion through compatible store/envelope endpoints.
- Stores raw events, normalized events, and grouped issues in SQLite.
- Provides a LiveView UI for issue triage, event inspection, search, retention,
  and alert configuration.
- Keeps deployment simple: one container plus one persistent `/data` volume.
- Uses structured search such as `release:1.2.3`, `environment:prod`, and
  `status:unresolved`.

## What it is not

- Not a full Sentry API implementation.
- Not a full observability platform.
- No session replay, profiling, metrics, APM, source maps, or minidumps yet.
- Not intended for multi-node SaaS operation in the open-source V1.0 line.

## Compared with Bugsink and GlitchTip

Faultline is not trying to copy every feature from existing Sentry alternatives.
It is making a different set of trade-offs.

| Project | Best fit | Trade-off |
| --- | --- | --- |
| [Bugsink](https://www.bugsink.com/docs/) | Self-hosted Sentry SDK compatible error tracking with a mature Python/Django implementation and documented single-server performance work. | A strong direct alternative. Faultline's difference is Phoenix/LiveView, an Elixir codebase, and a compact console built around the triage workflow. |
| [GlitchTip](https://glitchtip.com/documentation/) | Teams that want open-source error tracking plus performance monitoring, uptime monitoring, logs, hosted plans, and broader platform features. | More product surface area also means more concepts to configure and maintain. Faultline intentionally avoids that breadth in V1.0. |
| Faultline | Small teams that want the lightest practical Sentry-compatible issue tracker they can run as one container with SQLite. | Narrower scope: error tracking first, single-node first, no full Sentry API compatibility claim. |

### UI

Faultline's UI is built with Phoenix LiveView instead of a separate SPA. That
keeps the interface close to the backend code and avoids a second frontend
application just for the console.

The UI is meant to be practical first:

- Dense issue lists for scanning many errors quickly.
- Clear issue detail pages with stacktraces, breadcrumbs, tags, request data,
  user data, release, and environment in one workflow.
- Project settings, usage, retention, and alert rules kept near the work they
  affect.
- Tailwind-based styling with a restrained visual hierarchy and responsive
  layouts.

The point is not to look flashy. The point is to make the common path short:
open the issue, understand the failure, decide whether to fix, ignore, or alert
on it.

### Performance

Faultline does not publish comparative benchmark numbers yet, so this README
does not claim it is faster than Bugsink or GlitchTip. The performance target is
more specific: keep the single-node error-tracking path fast enough that small
teams do not need to operate a larger stack.

The important choices are:

- Phoenix and Bandit handle concurrent HTTP ingestion inside one BEAM
  application.
- SQLite keeps the V1.0 storage path local and removes a network hop.
- Normalized event fields and issue search documents avoid reparsing raw JSON
  for common UI queries.
- LiveView avoids shipping and maintaining a large separate frontend app for
  the console.
- Retention rules, rate limits, and drop rules are part of the product so noisy
  projects do not turn into surprise infrastructure work.

The right benchmark for Faultline is not "can it become a Sentry-scale
cluster?" It is "can a small team run it on modest hardware and still trust it
during an error spike?"

### Maintenance model

Faultline is optimized for people who will also be the operators:

- No PostgreSQL, Redis, Kafka, ClickHouse, object storage, Celery, or separate
  worker fleet in the default V1.0 path.
- One database file to back up.
- One container to deploy or roll back.
- Migrations and first-admin bootstrap run at release startup.
- The core data model is small: projects, DSNs, raw events, normalized events,
  grouped issues, alert rules, retention rules, and users.

That smaller maintenance surface is the main reason to choose Faultline.

## Architecture

```text
Sentry SDK
  -> Faultline Phoenix app
  -> SQLite database in /data/faultline.db
  -> LiveView issue triage UI
```

The ingest path uses normal Phoenix HTTP controllers. LiveView is used for the
human-facing console.

## Quick Start

Install dependencies and prepare the local database:

```sh
mix setup
```

Start the Phoenix server:

```sh
mix phx.server
```

Open:

```text
http://localhost:4010
```

You can also run inside IEx:

```sh
iex -S mix phx.server
```

## Docker

Run the published container with a persistent SQLite volume:

```sh
docker run --pull always -d --name faultline --restart unless-stopped -p 4010:4010 -v faultline-data:/data -e PHX_HOST=localhost ghcr.io/guzishiwo/faultline:latest
```

Then open:

```text
http://localhost:4010
```

Sign in with the default first-admin email:

```text
admin@faultline.local
```

Read the generated first-admin password from the container:

```sh
docker exec faultline cat /data/bootstrap_admin_password
```

The named Docker volume `faultline-data` stores both the SQLite database and the
generated Phoenix secret:

```text
/data/faultline.db
/data/secret_key_base
```

Build and run a local image:

```sh
docker build -t faultline .

docker run -p 4010:4010 \
  -v faultline-data:/data \
  -e PHX_HOST=localhost \
  faultline
```

`PHX_HOST` should be the public HTTPS host that browsers and SDKs can reach. It
must be a host name only, without `https://`. Use `localhost` for local Docker
runs and your real domain in production.

Good:

```text
PHX_HOST=errors.example.com
```

Bad:

```text
PHX_HOST=https://errors.example.com
```

Production data is stored at:

```text
/data/faultline.db
```

Always mount `/data` to persistent storage. If `SECRET_KEY_BASE` is not set, the
container generates one and stores it at `/data/secret_key_base`, so cookies stay
valid across restarts as long as the volume is kept.

## Railway Deployment

This repository includes a Dockerfile suitable for Railway GitHub deployments.

Recommended Railway setup:

```env
PORT=4010
PHX_HOST=${{RAILWAY_PUBLIC_DOMAIN}}
SECRET_KEY_BASE=<mix phx.gen.secret output>
LANG=en_US.UTF-8
LC_CTYPE=en_US.UTF-8
FAULTLINE_ADMIN_EMAIL=admin@example.com
FAULTLINE_ADMIN_PASSWORD=<temporary strong password>
```

Also create a Railway Volume and mount it at:

```text
/data
```

Notes:

- Do not add a Dockerfile `VOLUME` instruction. Railway expects volumes to be
  configured in the Railway UI.
- `PHX_HOST` is required for Phoenix LiveView origin checks. If `PHX_HOST` is not
  set, Faultline falls back to `RAILWAY_PUBLIC_DOMAIN` when Railway provides it.
- The app runs migrations and bootstraps the first admin user at container start.
- If you deploy in Railway Singapore and access from mainland China, LiveView UI
  interactions may feel slow because every interaction depends on network
  round-trips.

## First Admin User

On startup, Faultline runs:

```text
Faultline.Release.bootstrap_admin_from_env()
```

If no users exist, it creates the first admin account.

Recommended production variables:

```env
FAULTLINE_ADMIN_EMAIL=admin@example.com
FAULTLINE_ADMIN_PASSWORD=<temporary strong password>
```

If no password is supplied, Faultline writes a generated password to:

```text
/data/bootstrap_admin_password
```

For the Docker quick start above, read it with:

```sh
docker exec faultline cat /data/bootstrap_admin_password
```

## Sentry SDK Endpoints

Faultline targets SDK event ingestion first:

```text
POST /api/:project_id/envelope/
POST /api/:project_id/store/
```

Supported payload areas:

- Events and messages.
- Exceptions and stacktraces.
- Breadcrumbs.
- Tags, user, request, release, environment, and server name.
- Custom fingerprints where present.
- Unknown envelope items may be accepted and ignored.

Deferred:

- Source maps.
- Minidumps.
- Performance transactions.
- Session replay.
- Profiling.
- Metrics.

## Search

Examples:

```text
TypeError
release:1.2.3
environment:prod
project:cai-label
project:"Cai Label"
status:unresolved
level:error checkout
release:1.2.3 environment:prod TypeError
```

Search rules:

- Free text searches the issue search document.
- `key:value` tokens use structured filters.
- `project:` matches project id, slug, or name.
- `status:` filters issue status.
- Other keys match structured issue fields or normalized SDK tags.

## Development

Useful commands:

```sh
mix setup
mix phx.server
mix test
mix precommit
```

`mix precommit` is the default final check before submitting changes.

## More Docs

- [Chinese README](docs/README.zh-CN.md)
- [Single-node deployment](docs/SINGLE_NODE_DEPLOYMENT.md)
- [SQLite storage plan](docs/SQLITE3.md)
- [Fly.io deployment](docs/FLY_IO_DEPLOYMENT.md)
- [Roadmap](docs/ROADMAP.md)
- [User/admin tasks](docs/USER_ADMIN_TASKS.md)
