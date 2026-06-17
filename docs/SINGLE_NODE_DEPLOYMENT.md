# Single-node Deployment

Faultline V1.0 should stay predictable and cheap for a single Phoenix node plus
SQLite. Avoid adding PostgreSQL, Redis, Kafka, ClickHouse, object storage, or a
separate job system until the product has a measured need that SQLite and the
BEAM cannot cover.

## Required services

- One Faultline Phoenix release.
- One SQLite database file.
- Optional SMTP or webhook egress for alerts.

## Docker path

The default open-source deployment should be one command:

```sh
docker run -p 4010:4010 -v faultline-data:/data \
  -e PHX_HOST=errors.example.com \
  faultline
```

The container stores its database at:

```text
/data/faultline.db
```

If `SECRET_KEY_BASE` is not provided, the entrypoint generates one and stores it
in `/data/secret_key_base` so sessions survive restarts with the same volume.

On first boot, if no users exist, the entrypoint also creates a bootstrap admin:

```text
Email: admin@faultline.local
Password file: /data/bootstrap_admin_password
```

To choose the first admin credentials yourself:

```sh
docker run -p 4010:4010 -v faultline-data:/data \
  -e PHX_HOST=errors.example.com \
  -e FAULTLINE_ADMIN_EMAIL=admin@example.com \
  -e FAULTLINE_ADMIN_PASSWORD=change-me-now \
  faultline
```

Admin bootstrap only runs while the `users` table is empty. Existing users are
never overwritten.

## Required environment

```sh
PHX_SERVER=true
PHX_HOST=errors.example.com
DATABASE_PATH=/data/faultline.db
```

`SECRET_KEY_BASE` is optional for the Docker image because the entrypoint can
persist one under `/data`. For hand-built releases outside Docker, provide a
stable `SECRET_KEY_BASE`.

## Public DSN URL

`PHX_HOST` is the default public host used in generated Sentry-compatible DSNs.
Set it to the HTTPS hostname that application SDKs can reach:

```sh
docker run -p 127.0.0.1:4010:4010 -v faultline-data:/data \
  -e PHX_HOST=errors.example.com \
  faultline
```

In this shape, terminate TLS in a reverse proxy such as Caddy, Nginx, Traefik,
or a load balancer, and forward traffic to `http://127.0.0.1:4010`.

After login, admins can also update the public DSN base URL from:

```text
/admin/settings
```

Use that page when a host is assigned after first boot, such as a managed
platform hostname. New projects use the saved public DSN base URL. Existing
projects keep their stored DSNs until an admin clicks **Regenerate project
DSNs** on the same page.

## Cost controls

These defaults are intentionally small. Raise them only after observing saturation.

| Variable | Default | Purpose |
| --- | ---: | --- |
| `DATABASE_PATH` | `/data/faultline.db` | SQLite database file path. |
| `POOL_SIZE` | `5` | SQLite connections opened by the web node. |
| `DB_QUEUE_TARGET_MS` | `50` | Ecto checkout queue target before back-pressure increases. |
| `DB_QUEUE_INTERVAL_MS` | `1000` | Ecto queue interval for adapting checkout pressure. |
| `MAX_ENVELOPE_BYTES` | `1000000` | Maximum Sentry envelope request body accepted by ingest. |
| `RETENTION_CLEANUP_INTERVAL_MS` | `3600000` | Local retention cleanup interval. |
| `FAULTLINE_ADMIN_EMAIL` | `admin@faultline.local` | Optional first admin email when the database has no users. |
| `FAULTLINE_ADMIN_PASSWORD` | generated | Optional first admin password; must be at least 12 characters. |
| `FAULTLINE_ADMIN_PASSWORD_FILE` | `/data/bootstrap_admin_password` | Where the generated first admin password is stored. |
| `DNS_CLUSTER_QUERY` | unset | Leave unset for single-node deployments. |

## Operational shape

- Keep ingest synchronous and bounded at the HTTP edge.
- Store raw events and normalized events in SQLite first.
- Use one SQLite-backed issue search document table for V1.0 search.
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
bin/faultline eval 'Faultline.Release.migrate()'
```

Then start the release:

```sh
PHX_SERVER=true DATABASE_PATH=/data/faultline.db bin/faultline start
```
