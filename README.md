# Faultline

Faultline is a tiny self-hosted error tracker built with Phoenix and LiveView.

The V1.0 target is a minimal open-source SQLite edition: one Docker command, one data volume, and no PostgreSQL, Redis, Kafka, ClickHouse, or object storage required. Small teams should be able to point an existing Sentry SDK DSN at Faultline, receive errors, group them into issues, search them, and triage them from a fast realtime UI.

## Goals

- Keep deployment simple: SQLite by default and a single-container Docker path.
- Support the Sentry SDK ingest protocol where it matters for error tracking.
- Use LiveView for a realtime operational console without a separate SPA.
- Focus on exceptions, messages, stacktraces, breadcrumbs, tags, users, releases, environments, alerts, and searchable issue triage.
- Use a single SQLite-backed search document table with structured `key:value` filters for practical local search.
- Make retention and cost controls first-class features.

## Non-goals

- Full Sentry API compatibility.
- Full observability platform scope.
- Session replay, profiling, metrics, and APM tracing in the first versions.
- PostgreSQL as a V1.0 requirement.
- Kafka, ClickHouse, Redis, object storage, or other infrastructure as an MVP requirement.
- Multi-node SaaS architecture in the open-source V1.0 line.

## V1.0 Shape

Faultline V1.0 is optimized for a single-node open-source install:

```text
Sentry SDK
  -> Faultline Phoenix app
  -> SQLite database in /data/faultline.db
  -> LiveView issue triage UI
```

The intended deployment model is:

```sh
docker run -p 4010:4010 -v faultline-data:/data faultline
```

PostgreSQL may become an optional path later for larger deployments or a hosted SaaS edition, but it should not complicate the default open-source experience.

See [docs/SQLITE3.md](docs/SQLITE3.md) for the SQLite storage and search plan.

## Initial Architecture

```text
Sentry SDK
  -> Phoenix ingest controller
  -> Sentry envelope/store parser
  -> raw event persistence
  -> background normalization and grouping
  -> issue/event storage in SQLite
  -> SQLite-backed issue search documents
  -> LiveView triage console
```

The ingest path should be plain HTTP controllers, not LiveView. LiveView is for human-facing realtime workflows such as issue lists, event details, filtering, resolving, ignoring, and alert configuration.

## Search

Faultline search should support both free text and structured filters.

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

- Free text searches the issue search document row maintained during ingest.
- `key:value` tokens use structured filters.
- `project:` is a reserved key and should match project id, slug, or name.
- `status:` is a reserved key and should filter issue status.
- Other keys use the same issue search document row, either as structured columns or normalized SDK tags.
- URL project filters and `project:` search tokens are combined as an intersection.

The search implementation should keep the parser and business API database-neutral. V1.0 intentionally keeps the SQLite storage shape small so it can be rebuilt during early development.

## Planned Contexts

```text
lib/faultline/
  accounts/
  projects/
  ingest/
  sentry/
    auth.ex
    envelope.ex
    event.ex
    stacktrace.ex
    grouping.ex
  events/
  issues/
  search/
  alerts/
  retention/

lib/faultline_web/
  controllers/ingest_controller.ex
  live/issues_live/
  live/events_live/
  live/settings_live/
```

## Sentry Compatibility Scope

The first compatibility target is SDK event ingestion, not the Sentry web app or management API.

Planned endpoints:

```text
POST /api/:project_id/envelope/
POST /api/:project_id/store/
```

Planned payload support:

- Events and messages.
- Exceptions and stacktraces.
- Breadcrumbs.
- Tags, user, request, release, environment, server name.
- Custom fingerprint where present.
- Basic client reports and unknown envelope items can be accepted and ignored.

Deferred:

- Source maps.
- Minidumps.
- Performance transactions.
- Session replay.
- Profiling.
- Metrics.

## Development

Install and set up dependencies:

```sh
mix setup
```

Create the database:

```sh
mix ecto.create
```

Start the Phoenix server:

```sh
mix phx.server
```

Or run it inside IEx:

```sh
iex -S mix phx.server
```

Then open:

```text
http://localhost:4010
```

## Database

V1.0 is SQLite-first. The default local database should live under a repo-local or configurable data path, and production Docker should use:

```text
/data/faultline.db
```

SQLite is the primary open-source storage backend. PostgreSQL can be introduced later as an optional deployment profile without changing the UI or product workflow.

## Verification

Run the default project checks:

```sh
mix test
mix precommit
```

## Deployment

See [docs/SINGLE_NODE_DEPLOYMENT.md](docs/SINGLE_NODE_DEPLOYMENT.md) for the default
single-node deployment shape and runtime cost controls.

## Product Principles

- Error tracking first, observability later.
- Compatibility should be pragmatic and well documented.
- The open-source V1.0 path should run with one container and one SQLite data volume.
- Expensive work belongs in background jobs, not request handlers.
- Large payloads and raw event data should be loaded on demand in the UI.
- SQLite should be pushed as far as practical before introducing heavier infrastructure.
- Single-node deployments should remain predictable and cheap by default.
- PostgreSQL and SaaS concerns should stay behind clear boundaries until the product needs them.
