# Faultline Roadmap

This roadmap is written as GitHub-ready execution slices. Each milestone should stay small enough to ship independently.

## Milestone 0: Project Foundation

Goal: make the repository easy to run, test, and deploy locally.

- [x] Generate Phoenix 1.8 application with LiveView.
- [x] Upgrade project dependencies to Phoenix 1.8.8 and LiveView 1.2.x.
- [x] Document product scope, architecture boundaries, and local development.
- [x] Switch the V1.0 default storage path to SQLite.
- [x] Add release-oriented runtime configuration notes.
- [x] Add basic CI with `mix precommit`.

## Milestone 1: Project and DSN Model

Goal: let a user create a project and obtain a Sentry-compatible DSN.

- [x] Create `projects` context.
- [x] Add project schema with slug, name, public key, secret key, and DSN fields.
- [x] Add project creation and listing LiveViews.
- [x] Generate a Sentry-compatible DSN format.
- [x] Add project-level rate limit settings.
- [x] Add tests for DSN generation and validation.

## Milestone 1.5: Users and Admin Controls

Goal: require login for the product console and give operators a small admin surface.

- [x] Add Phoenix authentication with registration, login, logout, settings, and email confirmation flow.
- [x] Add user roles with `member` and `admin`.
- [x] Protect project and issue LiveViews behind authentication.
- [x] Add admin-only user management route.
- [x] Add admin LiveView for listing users and changing roles.
- [x] Prevent demoting the last admin user.
- [x] Update the home page for Faultline product positioning and user entry points.
- [x] Add a first-user bootstrap path that makes the first registered user an admin.
- [ ] Add invite-only registration mode.
- [ ] Add audit log entries for role changes.
- [ ] Add organization and team membership model.
- [ ] Scope projects to an organization.

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

- [x] Extract event id, timestamp, platform, logger, level, culprit, and message.
- [x] Extract exception type, value, mechanism, and stacktrace frames.
- [x] Extract tags, user, request, release, environment, and server name.
- [x] Extract breadcrumbs.
- [x] Store normalized event data in queryable columns plus JSON details.
- [x] Add validation for malformed but acceptable SDK payloads.
- [x] Add fixtures for Elixir, JavaScript, Python, and Ruby SDK events.

## Milestone 4: Issue Grouping

Goal: group repeated events into actionable issues.

- [x] Design initial grouping fingerprint.
- [x] Respect explicit SDK fingerprint when present.
- [x] Group by exception type, normalized stacktrace, platform, and culprit.
- [x] Track first seen, last seen, event count, affected users, and status.
- [x] Reopen resolved issues when a new matching event arrives.
- [x] Add unit tests for grouping stability.

## Milestone 5: LiveView Triage UI

Goal: provide the first useful operator workflow.

- [x] Add issue list LiveView with keyset pagination.
- [x] Add issue detail LiveView with latest events.
- [x] Show stacktrace, breadcrumbs, tags, request, user, release, and environment.
- [x] Add status transitions: unresolved, resolved, ignored.
- [x] Broadcast new issues and issue updates with Phoenix PubSub.
- [x] Use LiveView streams for issue collections.
- [x] Load raw event JSON on demand.

## Milestone 6: Alerts and Notifications

Goal: notify teams about new and regressed issues.

- [x] Add alert rules per project.
- [x] Add email notification adapter.
- [x] Add webhook notification adapter.
- [x] Add Slack-compatible webhook adapter.
- [x] Add per-issue notification deduplication.
- [x] Add tests for alert fanout and suppression.

## Milestone 7: Retention and Cost Controls

Goal: keep single-node deployments predictable and cheap.

- [x] Add per-project retention days.
- [x] Add event-count retention cap.
- [x] Add scheduled cleanup job.
- [x] Add project usage page.
- [x] Add drop rules for noisy event classes.
- [x] Add request-size limits and rate-limit responses.

## Milestone 8: Production Packaging

Goal: make self-hosting boring.

- [x] Add production Dockerfile.
- [x] Add SQLite-first single-container deployment path.
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
- [ ] Optional PostgreSQL/SaaS storage profile.
