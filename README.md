# Faultline

[中文说明](docs/README.zh-CN.md)

Faultline is a small self-hosted error tracker built with Phoenix, LiveView, and
SQLite. It is designed for teams that want Sentry-compatible error ingestion
without running PostgreSQL, Redis, Kafka, ClickHouse, or object storage.

> Status: early V1.0 work. The goal is a practical single-node open-source
> edition, not a full Sentry replacement.

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

Build and run a single-node container:

```sh
docker build -t faultline .

docker run -p 4010:4010 \
  -v faultline-data:/data \
  -e PHX_HOST=errors.example.com \
  -e SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  faultline
```

`PHX_HOST` should be the public HTTPS host that browsers and SDKs can reach. It
must be a host name only, without `https://`.

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

Always mount `/data` to persistent storage.

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
