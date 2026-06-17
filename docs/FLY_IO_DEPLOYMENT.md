# Fly.io Trial Deployment

This guide deploys Faultline as a single Phoenix Machine with one Fly Volume
mounted at `/data`. It is intended for trials and small single-node installs,
not multi-region or multi-machine production.

Faultline's default Docker image stores SQLite at:

```text
/data/faultline.db
```

On Fly.io, `/data` must be backed by a Fly Volume. Without the volume, the
SQLite database, generated `SECRET_KEY_BASE`, and bootstrap admin password would
be lost when the Machine is replaced.

## Prerequisites

- Install `flyctl`.
- Run `fly auth login`.
- Pick an app name and one region.

Examples below use:

```sh
APP=faultline-demo
REGION=sin
VOLUME=faultline_data
```

## Create The App

From the repository root:

```sh
fly launch --name "$APP" --region "$REGION" --no-deploy
```

Fly Launch should detect the repository `Dockerfile`. Keep PostgreSQL and Redis
disabled when prompted.

## Create Persistent Storage

Create one volume in the same region as the app:

```sh
fly volumes create "$VOLUME" --app "$APP" --region "$REGION" --size 1
```

The volume name must use letters, numbers, or underscores. Keep this app at one
Machine unless you deliberately move beyond SQLite single-node deployment.

## Configure `fly.toml`

Edit the generated `fly.toml` so it has these pieces. Keep any generated app
name or region values that differ from the example.

```toml
app = "faultline-demo"
primary_region = "sin"

[build]
  dockerfile = "Dockerfile"

[env]
  PHX_HOST = "faultline-demo.fly.dev"
  DATABASE_PATH = "/data/faultline.db"
  PORT = "4010"
  POOL_SIZE = "5"

[mounts]
  source = "faultline_data"
  destination = "/data"

[http_service]
  internal_port = 4010
  force_https = true
  auto_stop_machines = false
  auto_start_machines = true
  min_machines_running = 1
```

Notes:

- `PHX_HOST` must match the Fly hostname unless you attach a custom domain.
- `DATABASE_PATH` must stay under `/data`.
- `auto_stop_machines = false` keeps the LiveView console and ingest endpoint
  warm for trials.
- The Docker entrypoint generates and persists `SECRET_KEY_BASE` in `/data` if
  you do not provide one as a Fly secret.

## Optional Admin Credentials

If you do nothing, the first deployment creates:

```text
Email: admin@faultline.local
Password file: /data/bootstrap_admin_password
```

To choose the first admin email and password yourself:

```sh
fly secrets set \
  --app "$APP" \
  FAULTLINE_ADMIN_EMAIL="admin@example.com" \
  FAULTLINE_ADMIN_PASSWORD="change-me-now"
```

The bootstrap only runs when the `users` table is empty. Once any user exists,
these environment variables are ignored and no account is overwritten.

If you provide `FAULTLINE_ADMIN_PASSWORD`, it must satisfy the app password rule:
at least 12 characters. It does not need symbols, uppercase letters, or digits.

## Deploy

```sh
fly deploy --app "$APP"
```

The entrypoint runs migrations, bootstraps the first admin if needed, and starts
Phoenix.

Open the app:

```sh
fly open --app "$APP"
```

If you used the generated default password, read it from the volume:

```sh
fly ssh console --app "$APP" -C "cat /data/bootstrap_admin_password"
```

Then log in with:

```text
admin@faultline.local
```

## First Project

After login:

1. Create a project.
2. Copy the generated Sentry-compatible DSN.
3. Configure an SDK to send a test message.
4. Check `/issues` or the project issue list.

## Backup During A Trial

For a simple offline backup, download the SQLite database from the running
Machine:

```sh
fly ssh sftp get /data/faultline.db ./faultline.db --app "$APP"
```

This is acceptable for a trial with low write volume. For a serious backup,
pause ingest during a maintenance window or use Fly Volume snapshots so the
database file is copied from a stable storage snapshot.

## Operational Limits

- This is a single-node SQLite deployment.
- Fly Volumes are local to one region and attach to one Machine.
- Do not scale this app horizontally without changing the storage design.
- Keep alerts best-effort until a durable background job path is introduced.
