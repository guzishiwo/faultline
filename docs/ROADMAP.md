# Faultline Roadmap

This roadmap is written as GitHub-ready execution slices. Each milestone should stay small enough to ship independently.

## Milestone 0: Project Foundation

Goal: make the repository easy to run, test, and deploy locally.

- [x] Generate Phoenix 1.8 application with LiveView and PostgreSQL.
- [x] Upgrade project dependencies to Phoenix 1.8.8 and LiveView 1.2.x.
- [x] Document product scope, architecture boundaries, and local development.
- [ ] Add Docker Compose for PostgreSQL.
- [ ] Add release-oriented runtime configuration notes.
- [x] Add basic CI with `mix precommit`.

## Milestone 1: Project and DSN Model

Goal: let a user create a project and obtain a Sentry-compatible DSN.

- [x] Create `projects` context.
- [x] Add project schema with slug, name, public key, secret key, and DSN fields.
- [x] Add project creation and listing LiveViews.
- [x] Generate a Sentry-compatible DSN format.
- [x] Add project-level rate limit settings.
- [x] Add tests for DSN generation and validation.

## Milestone 2: Sentry Ingest MVP

Goal: accept basic Sentry SDK error events through familiar endpoints.

- [x] Add `FaultlineWeb.IngestController`.
- [x] Implement `POST /api/:project_id/store/`.
- [x] Implement `POST /api/:project_id/envelope/`.
- [x] Parse `X-Sentry-Auth` and query-string auth.
- [x] Persist raw event payloads before normalization.
- [x] Return Sentry-compatible success responses for accepted events.
- [x] Accept and ignore unknown envelope item types.
- [x] Add controller tests using captured sample payloads.

## Milestone 3: Event Normalization

Goal: convert raw SDK payloads into a stable internal event model.

- [ ] Extract event id, timestamp, platform, logger, level, culprit, and message.
- [ ] Extract exception type, value, mechanism, and stacktrace frames.
- [ ] Extract tags, user, request, release, environment, and server name.
- [ ] Extract breadcrumbs.
- [ ] Store normalized event data in queryable columns plus JSONB details.
- [ ] Add validation for malformed but acceptable SDK payloads.
- [ ] Add fixtures for Elixir, JavaScript, Python, and Ruby SDK events.

## Milestone 4: Issue Grouping

Goal: group repeated events into actionable issues.

- [ ] Design initial grouping fingerprint.
- [ ] Respect explicit SDK fingerprint when present.
- [ ] Group by exception type, normalized stacktrace, platform, and culprit.
- [ ] Track first seen, last seen, event count, affected users, and status.
- [ ] Reopen resolved issues when a new matching event arrives.
- [ ] Add unit tests for grouping stability.

## Milestone 5: LiveView Triage UI

Goal: provide the first useful operator workflow.

- [ ] Add issue list LiveView with keyset pagination.
- [ ] Add issue detail LiveView with latest events.
- [ ] Show stacktrace, breadcrumbs, tags, request, user, release, and environment.
- [ ] Add status transitions: unresolved, resolved, ignored.
- [ ] Broadcast new issues and issue updates with Phoenix PubSub.
- [ ] Use LiveView streams for issue collections.
- [ ] Load raw event JSON on demand.

## Milestone 6: Alerts and Notifications

Goal: notify teams about new and regressed issues.

- [ ] Add alert rules per project.
- [ ] Add email notification adapter.
- [ ] Add webhook notification adapter.
- [ ] Add Slack-compatible webhook adapter.
- [ ] Add per-issue notification deduplication.
- [ ] Add tests for alert fanout and suppression.

## Milestone 7: Retention and Cost Controls

Goal: keep single-node deployments predictable and cheap.

- [ ] Add per-project retention days.
- [ ] Add event-count retention cap.
- [ ] Add scheduled cleanup job.
- [ ] Add project usage page.
- [ ] Add drop rules for noisy event classes.
- [ ] Add request-size limits and rate-limit responses.

## Milestone 8: Production Packaging

Goal: make self-hosting boring.

- [ ] Add production Dockerfile.
- [ ] Add Docker Compose for app and PostgreSQL.
- [ ] Add health check endpoint.
- [ ] Add deployment guide for a small VPS.
- [ ] Add backup and restore notes.
- [ ] Add sample reverse proxy configuration.

## Later

- [ ] Source map support.
- [ ] Minidump support.
- [ ] Organization and team permissions.
- [ ] Multi-tenant billing primitives.
- [ ] ClickHouse event storage option.
- [ ] Performance transaction ingestion.
- [ ] Public API for basic issue operations.
