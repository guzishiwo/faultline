# SQLite Issue-First Search Design

## Context

Faultline is a SQLite-first, Sentry-compatible error tracker for single-node
self-hosting. The default product path should stay one Phoenix release plus one
durable SQLite database file. A future SaaS edition may move the same product
semantics to PostgreSQL, so the search design must avoid leaking SQLite FTS5
details into LiveViews, issue workflows, or public query syntax.

The common user workflow is issue triage, not log-scale event search. Users most
often need to answer:

- Which unresolved issues are active now?
- Which issues affect a project, environment, release, user, or trace?
- Which representative events inside an issue match the same filters?
- What issue matches an exception type, message, culprit, or important stack
  frame?

## Recommendation

Implement storage-neutral search semantics with a SQLite-first store.

Faultline should use issue-first search as the V1 product model:

- Ordinary issue filters use normal indexed columns.
- `key:value` filters use normalized tag tables and B-tree indexes.
- Free text uses a small issue-level FTS5 index with the `unicode61` tokenizer.
- Event-level searching is drill-down by tags and issue membership, not full
  event FTS.
- Raw event JSON remains detail data and is loaded on demand.

Do not enable trigram FTS or full event FTS by default. Those can be added later
behind the same search boundary if measured user behavior needs arbitrary
substring search or high-volume event text search.

## Product Query Syntax

The product query syntax should stay database neutral:

```text
TypeError
status:unresolved
project:api
issue:abc123
release:1.2.3 environment:prod
user:123
trace:abc
project:web status:unresolved TimeoutError
```

Parsing rules:

- `project:`, `status:`, and `issue:` are reserved filters.
- Known system dimensions such as `release:`, `environment:`, `level:`,
  `logger:`, `platform:`, `server:`, `server_name:`, `user:`,
  `user_identifier:`, `url:`, `request_url:`, and `trace:` are tag filters.
- Unknown `key:value` tokens are custom tag filters.
- Remaining terms are free text.
- Multiple filters are combined with AND.
- Quoted values preserve spaces.
- V1 does not expose FTS5-specific operators such as `NEAR`, column-specific
  `MATCH`, or complex boolean syntax.

## Module Boundary

Business code should depend on a small search boundary, not on FTS5 SQL.

```text
Faultline.Search
  parse(query) -> Faultline.Search.Query
  search_issues(current_scope, query, opts)
  search_events(current_scope, issue, query, opts)
  sync_event(event, issue)
  delete_event(event)
  delete_issue(issue)

Faultline.Search.Store
  behaviour implemented by storage-specific modules

Faultline.Search.Store.SQLite
  current implementation

Future:
Faultline.Search.Store.Postgres
  SaaS/PostgreSQL implementation
```

`Faultline.Search.Query` is the stable AST. LiveViews and contexts should pass
query structs and options to `Faultline.Search`; they should not construct FTS5
`MATCH` expressions or know whether the backing store is SQLite or PostgreSQL.

## SQLite Data Model

Keep the existing `issues`, `events`, and `raw_events` tables. Replace the
merged `tags` text lookup pattern with normalized issue and event tag tables.

```text
issue_tag_values
- project_id
- issue_id
- key
- value
- event_count
- first_seen_at
- last_seen_at
- inserted_at
- updated_at

event_tag_values
- project_id
- issue_id
- event_id
- key
- value
- occurred_at
- inserted_at
- updated_at

issue_search_documents
- id integer primary key
- project_id
- issue_id
- title
- body
- last_seen_at
- inserted_at
- updated_at

issue_search_fts
- virtual FTS5 table over title and body
- external content table: issue_search_documents
- content rowid: issue_search_documents.id
- tokenizer: unicode61
```

`issue_search_documents.id` is intentionally an integer rowid for FTS5 external
content. `issue_id` remains the product identity and must be unique. Tag keys
and values should be stored in normalized lowercase form for search, while the
original event payload remains available through `raw_events`.

`issue_search_documents.body` should contain a concise issue summary:

- issue title
- fingerprint
- exception type
- exception value
- message
- culprit
- platform and logger
- important in-app stack frames
- latest release, environment, server, user, and URL values when useful

Do not put full raw payloads, complete breadcrumbs, request headers, or large
JSON blobs into FTS.

## SQLite Indexes

Use ordinary indexes for the high-frequency paths:

```sql
CREATE UNIQUE INDEX issue_tag_values_unique_idx
ON issue_tag_values(project_id, issue_id, key, value);

CREATE INDEX issue_tag_values_project_key_value_issue_idx
ON issue_tag_values(project_id, key, value, issue_id);

CREATE INDEX issue_tag_values_issue_key_value_idx
ON issue_tag_values(issue_id, key, value);

CREATE UNIQUE INDEX event_tag_values_unique_idx
ON event_tag_values(project_id, event_id, key, value);

CREATE INDEX event_tag_values_project_key_value_issue_idx
ON event_tag_values(project_id, key, value, issue_id);

CREATE INDEX event_tag_values_issue_key_value_event_idx
ON event_tag_values(issue_id, key, value, event_id);

CREATE INDEX event_tag_values_issue_occurred_idx
ON event_tag_values(issue_id, occurred_at);
```

Keep existing issue indexes for project, status, and last-seen ordering. Issue
lists should use keyset pagination and avoid full-table counts.

## Query Flow

Issue search:

1. Parse the input into reserved filters, tag filters, and text terms.
2. Resolve `project:` against project id, slug, and name.
3. Apply ordinary issue filters for project, status, issue id, time range, and
   pagination cursor.
4. Intersect tag filters through `issue_tag_values`.
5. Intersect free text terms through `issue_search_fts`.
6. Load matching issues ordered by `issues.last_seen_at DESC, issues.id DESC`.

Event drill-down inside an issue:

1. Reuse the same parsed query.
2. Restrict to the selected issue id.
3. Apply tag filters through `event_tag_values`.
4. Load matching events ordered by `events.occurred_at DESC, events.id DESC`.
5. Load raw event JSON only when the UI asks for the event detail.

The initial SQLite implementation may omit text filtering inside event
drill-down. In that case, free-text terms decide which issues are listed, while
event drill-down applies reserved filters and tag filters within the selected
issue. If needed later, add an `event_search_documents` and `event_fts` store
feature without changing the product query syntax.

## Ingest Sync

After raw event normalization and issue grouping:

```text
raw_event inserted
event normalized
issue grouped
event linked to issue
Faultline.Search.sync_event(event, issue)
```

`sync_event/2` should:

- Extract system tags from normalized event columns.
- Extract custom SDK tags from event details.
- Insert event tag values for event drill-down.
- Upsert issue tag rollups with counts and first/last seen timestamps.
- Upsert the issue search document.
- Update the FTS5 virtual table for the issue document.

Search sync should run in the same logical ingest flow so accepted events are
searchable immediately. If write amplification becomes a measured problem, the
same boundary can support deferred search sync later.

## Retention And Cleanup

Retention must clean search data with event and issue data:

- Deleting an event deletes its `event_tag_values`.
- Deleting the last event for an issue should delete or expire the issue.
- Deleting an issue deletes `issue_tag_values`, `issue_search_documents`, and
  the corresponding FTS rows.
- When retention removes old events but leaves the issue, recompute issue tag
  rollups and the issue search summary for affected issues.

FTS maintenance should not run in request paths. A background cleanup task may
run small SQLite FTS5 merge work after retention. Full optimize should remain an
operator or maintenance action, not a normal web request side effect.

## Router And Authentication

Issue and event search belong to the authenticated product console. Any new
LiveView routes for search surfaces should be placed inside the existing:

```elixir
scope "/", FaultlineWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :require_authenticated_user,
    on_mount: [{FaultlineWeb.UserAuth, :require_authenticated}] do
    # search-enabled issue routes
  end
end
```

This is required because error data is private product data and because
Phoenix auth assigns `current_scope`, not `current_user`. LiveViews should pass
`@current_scope` to context/search functions and templates should access the
user as `@current_scope.user`.

## PostgreSQL Path

The SaaS/PostgreSQL implementation should preserve the same search AST and
module boundary.

Possible PostgreSQL mapping:

- Keep normalized issue and event tag tables with comparable B-tree indexes.
- Store issue summary text in `issue_search_documents`.
- Use generated `tsvector` or maintained `tsvector` columns for full text.
- Add GIN indexes for text vectors.
- Add `pg_trgm` only if measured substring search requires it.
- Consider time or project partitioning for events later, behind the store
  implementation.

The UI, query language, and `Faultline.Search` public functions should not
change when switching from SQLite to PostgreSQL.

## Testing Strategy

Add focused tests in stages:

- Query parser tests for reserved filters, custom tags, quoted values, and free
  text.
- SQLite store tests for issue tag rollups and event tag rows after ingest.
- Search integration tests for status, project, issue, tag, text, and combined
  queries.
- Retention tests that prove search rows are removed or recomputed.
- LiveView tests that reference stable element ids for issue search controls and
  verify outcomes with `has_element?/2` and `element/2`.

Run `mix precommit` after implementation changes.

## Non-Goals

- No external search service.
- No ClickHouse event store.
- No full event FTS in V1.
- No trigram index in V1.
- No public exposure of SQLite FTS5 syntax.
- No all-events raw JSON search in V1.
