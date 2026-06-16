# Faultline Homepage Landing Page Design

Date: 2026-06-16

## Goal

Redesign the public homepage at `/` so it communicates Faultline's core promise:
Sentry SDK compatible error tracking that runs from one Docker command, stores
data in SQLite, and gives small teams a realtime triage UI without requiring a
heavy observability stack.

The primary first-screen audience is developers evaluating whether Faultline is
simple enough to run. The page should also speak to operators and open-source
visitors through the lower sections.

## Route and Authentication Placement

Keep the homepage as a controller route:

```elixir
scope "/", FaultlineWeb do
  pipe_through :browser

  get "/", PageController, :home
end
```

Do not move it into an authenticated scope or LiveView `live_session`. The page
must work for both anonymous visitors and signed-in users. The `:browser`
pipeline already runs `:fetch_current_scope_for_user`, so the template can use
`@current_scope` to render the correct calls to action.

For logged-in users:

- Show `Open issues` as the primary call to action.
- Show `Projects` as a secondary action.
- Show `Admin` only when `@current_scope.user.role == "admin"`.

For anonymous users:

- Show `Create account` as the primary call to action.
- Show `Log in` as a secondary action.

## Design Direction

Use the command-first developer direction.

The hero should make the product promise concrete immediately:

> Error tracking that runs in one container.

The supporting message should connect four ideas:

- Existing Sentry SDKs can point at Faultline.
- The default V1.0 deployment is one Phoenix release and one SQLite database.
- LiveView provides realtime issue triage without a separate SPA.
- PostgreSQL, Redis, Kafka, ClickHouse, and object storage are not required for
  the open-source V1.0 path.

The Docker command should be visually prominent in the hero:

```sh
docker run -p 4010:4010 -v faultline-data:/data faultline
```

This command block is the main proof point. It should not be buried in a later
documentation-style section.

## Page Structure

### 1. Hero

The hero should have:

- A compact product eyebrow such as `Sentry SDK compatible error tracking`.
- A direct headline: `Error tracking that runs in one container.`
- A short paragraph explaining SDK compatibility, SQLite-first storage, and
  realtime LiveView triage.
- Auth-aware calls to action.
- A prominent terminal-style Docker command block.
- A small set of deployment facts near the command block:
  - `SQLite in /data/faultline.db`
  - `One Phoenix node`
  - `No Redis or queue service`
  - `Sentry store + envelope ingest`

### 2. Workflow Strip

Add a compact sequence showing the product flow:

1. Point an SDK DSN at Faultline.
2. Receive store and envelope events.
3. Normalize and group stacktraces.
4. Search, resolve, ignore, and alert.
5. Retain data predictably in SQLite.

This should be scannable, not a long explanation.

### 3. Core Capabilities

Add a feature grid focused on what the project already supports or explicitly
targets in V1.0:

- Sentry-compatible ingest for existing SDKs.
- Grouped issues with event count, affected users, first seen, and last seen.
- Realtime issue triage with LiveView and PubSub.
- SQLite-backed issue search with free text and structured filters.
- Alerts through email, webhooks, and Slack-compatible webhooks.
- Retention and noisy-event drop controls for predictable single-node cost.

Avoid marketing claims that imply full Sentry API compatibility, APM, profiling,
session replay, metrics, source maps, or multi-node SaaS readiness.

### 4. Architecture Snapshot

Show a lightweight architecture band:

```text
Sentry SDK -> Phoenix ingest -> normalization/grouping -> SQLite -> LiveView UI
```

This reinforces the small-infrastructure concept and differentiates Faultline
from heavier observability stacks.

### 5. Product Principles Close

End with the philosophy:

> Error tracking first. Observability later.

Support it with concise principles:

- Keep the ingest path bounded and boring.
- Load large event payloads on demand.
- Push SQLite as far as practical before adding heavier infrastructure.
- Make retention and cost controls first-class defaults.

## Visual Style

Use the existing Faultline theme: neutral graphite surfaces with amber accents.
The page should feel like a practical developer tool, not a broad SaaS marketing
site.

Guidelines:

- Keep the hero dense enough that the Docker command is visible in the first
  viewport on desktop.
- Use restrained cards only for repeated feature items and command/status
  panels.
- Avoid decorative gradient blobs, oversized marketing illustrations, and
  vague stock imagery.
- Use Tailwind utility classes in the HEEx template.
- Do not add external scripts, external stylesheets, or new bundles.
- Use `<.icon>` from `core_components.ex` for icons.
- Wrap the page content in
  `<Layouts.app flash={@flash} current_scope={@current_scope}>`.

## Implementation Scope

Implementation should be limited to:

- Updating `lib/faultline_web/controllers/page_html/home.html.heex`.
- Updating `test/faultline_web/controllers/page_controller_test.exs` so it
  asserts stable page contracts rather than brittle full HTML.

No new route, context, JavaScript hook, database migration, dependency, or
external asset is needed.

## Testing

Run focused tests after implementation:

```sh
mix test test/faultline_web/controllers/page_controller_test.exs
```

Run the project precommit alias before completion:

```sh
mix precommit
```

The page test should verify stable elements or copy that represents the new
contract, such as:

- The homepage returns HTTP 200.
- The hero includes `Error tracking that runs in one container.`
- The page includes the Docker command.
- The page includes auth-aware entry points in anonymous mode.

## Out of Scope

- Building a docs site.
- Adding copy-to-clipboard behavior for the Docker command.
- Adding a video, illustration, or screenshots.
- Changing authentication behavior.
- Changing `/api/:project_id/store/` or `/api/:project_id/envelope/`.
- Changing the product navigation layout outside what is needed for the
  homepage content.
