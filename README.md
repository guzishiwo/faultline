# Faultline

Faultline is a lightweight, self-hostable error tracking service built with Phoenix and LiveView.

The product direction is Sentry SDK compatible error tracking without the infrastructure tax: small teams should be able to point an existing Sentry SDK DSN at Faultline, receive errors, group them into issues, and triage them from a fast realtime UI.

## Goals

- Keep deployment simple: Phoenix release plus PostgreSQL first.
- Support the Sentry SDK ingest protocol where it matters for error tracking.
- Use LiveView for a realtime operational console without a separate SPA.
- Focus on exceptions, messages, stacktraces, breadcrumbs, tags, users, releases, environments, and alerts.
- Make retention and cost controls first-class features.

## Non-goals

- Full Sentry API compatibility.
- Full observability platform scope.
- Session replay, profiling, metrics, and APM tracing in the first versions.
- Kafka, ClickHouse, Redis, or other infrastructure as an MVP requirement.

## Initial Architecture

```text
Sentry SDK
  -> Phoenix ingest controller
  -> Sentry envelope/store parser
  -> raw event persistence
  -> background normalization and grouping
  -> issue/event storage in PostgreSQL
  -> LiveView triage console
```

The ingest path should be plain HTTP controllers, not LiveView. LiveView is for human-facing realtime workflows such as issue lists, event details, filtering, resolving, ignoring, and alert configuration.

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
http://localhost:4000
```

## Database

The generated development config expects PostgreSQL on localhost:

```elixir
username: "postgres"
password: "postgres"
hostname: "localhost"
database: "faultline_dev"
```

Update `config/dev.exs` if your local PostgreSQL credentials are different.

## Verification

Run the default project checks:

```sh
mix test
mix precommit
```

## Product Principles

- Error tracking first, observability later.
- Compatibility should be pragmatic and well documented.
- Expensive work belongs in background jobs, not request handlers.
- Large payloads and raw event data should be loaded on demand in the UI.
- PostgreSQL should be pushed as far as practical before introducing heavier infrastructure.
