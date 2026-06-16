# SQLite3 V1.0 Storage Plan

Faultline V1.0 is SQLite-first. The open-source edition should run as a
single-node service with one app container and one durable SQLite database file.

## Product Target

```text
docker run -p 4010:4010 -v faultline-data:/data faultline
```

The default production database path is:

```text
/data/faultline.db
```

Development and tests use SQLite as well. PostgreSQL is not a V1.0 runtime
requirement and should not leak into the default product path.

## Core Tables

The V1.0 SQLite schema keeps the existing core entities:

```text
projects
raw_events
events
issues
users
users_tokens
alert_rules
alert_deliveries
project_drop_rules
```

`project_number` is assigned by the application during project creation. SQLite
only auto-increments integer primary keys, so a secondary public project number
should not rely on PostgreSQL `bigserial`.

## One Search Table

Issue search adds one auxiliary table:

```text
issue_search_documents
```

Each issue owns one row. The row stores:

- `issue_id` and `project_id` for joins and filtering.
- `document`, a merged text document from issue title, fingerprint, latest and
  previous event fields, and tag values.
- `tags`, a newline-separated list of normalized `key:value` pairs.
- Structured columns for common filters: `release`, `environment`, `level`,
  `logger`, `platform`, `server_name`, `user_identifier`, and `request_url`.
- `last_seen_at` for ordering/filtering support.

This deliberately avoids separate FTS virtual tables and normalized tag tables
for V1.0. If search volume grows, this table is the only boundary that needs to
be replaced or expanded.

## Query Syntax

Search supports free text and structured filters:

```text
TypeError
release:1.2.3
environment:prod
project:cai-label
project:"Cai Label"
status:unresolved
level:error checkout
release:1.2.3 environment:prod TypeError
feature:"checkout flow"
```

Parsing rules:

- `key:value` becomes a structured token.
- `key:"quoted value"` preserves spaces.
- Remaining tokens become free text.
- Unknown keys are treated as SDK tag keys.

Reserved keys:

```text
project
status
```

`project:` resolves against project id, slug, then name. `status:` resolves
against `issues.status`. Other known keys resolve against
`issue_search_documents` columns. Unknown keys are matched against the single
table's normalized `tags` field.

If the URL already contains a project filter and the search box also contains
`project:...`, both filters are applied as an intersection.

## Ingest Updates

After raw event normalization and issue grouping:

```text
raw_event inserted
event normalized
issue grouped
event linked to issue
issue_search_documents row inserted or updated
```

System tag candidates stored into the search row:

```text
release
environment
server
server_name
level
logger
platform
user
user_identifier
url
request_url
```

SDK-provided `tags` are folded into the same row as normalized `key:value`
pairs.

## SQLite Version Check

From the application shell:

```sh
iex -S mix
```

```elixir
Faultline.Repo.query!("select sqlite_version();").rows
```

Or with the SQLite CLI against a database file:

```sh
sqlite3 priv/repo/faultline_dev.db 'select sqlite_version();'
```

## PostgreSQL Later

When PostgreSQL becomes necessary for a SaaS or larger-install edition, it
should be introduced as an explicit product path, not as a hidden V1.0
requirement. The current search boundary is small enough to replace with a
PostgreSQL implementation later without changing LiveView or public query
syntax.
