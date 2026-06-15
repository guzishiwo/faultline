# Single-node deployment

Faultline should stay predictable and cheap for a single Phoenix node plus PostgreSQL.
Avoid adding Redis, Kafka, ClickHouse, or a separate job system until the product has a
measured need that PostgreSQL and the BEAM cannot cover.

## Required services

- One Faultline Phoenix release.
- One PostgreSQL database.
- Optional SMTP or webhook egress for alerts.

## Required environment

```sh
PHX_SERVER=true
PHX_HOST=errors.example.com
SECRET_KEY_BASE=...
DATABASE_URL=ecto://USER:PASS@HOST/DATABASE
```

## Cost controls

These defaults are intentionally small. Raise them only after observing saturation.

| Variable | Default | Purpose |
| --- | ---: | --- |
| `POOL_SIZE` | `5` | PostgreSQL connections opened by the web node. |
| `DB_QUEUE_TARGET_MS` | `50` | Ecto checkout queue target before back-pressure increases. |
| `DB_QUEUE_INTERVAL_MS` | `1000` | Ecto queue interval for adapting checkout pressure. |
| `MAX_ENVELOPE_BYTES` | `1000000` | Maximum Sentry envelope request body accepted by ingest. |
| `RETENTION_CLEANUP_INTERVAL_MS` | `3600000` | Local retention cleanup interval. |
| `DNS_CLUSTER_QUERY` | unset | Leave unset for single-node deployments. |

## Operational shape

- Keep ingest synchronous and bounded at the HTTP edge.
- Store raw events and normalized events in PostgreSQL first.
- Keep alert delivery best-effort and deduplicated; do not add a queue service by default.
- Run retention cleanup on the local BEAM node; missed runs after restarts are acceptable.
- Load large event payloads on demand in the UI instead of rendering them in lists.
- Prefer retention and rate-limit controls before adding more infrastructure.

## Release flow

```sh
mix deps.get --only prod
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix compile
MIX_ENV=prod mix release
```

Run migrations before starting or during deployment:

```sh
MIX_ENV=prod mix ecto.migrate
```

Then start the release:

```sh
PHX_SERVER=true bin/faultline start
```
