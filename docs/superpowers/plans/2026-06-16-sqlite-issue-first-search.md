# SQLite Issue-First Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Replace merged-text issue search with a SQLite issue-first search boundary using normalized tag indexes and issue-level FTS5, while preserving future PostgreSQL portability.

**Architecture:** Add `Faultline.Search` as the storage-neutral API and `Faultline.Search.Store.SQLite` as the implementation. Ingest calls `Faultline.Search.sync_event/2`; issue queries call `Faultline.Search.search_issues/2`; issue detail drill-down calls `Faultline.Search.search_events/3`.

**Tech Stack:** Phoenix 1.8, Ecto, ecto_sqlite3, SQLite FTS5, ExUnit, Phoenix LiveViewTest.

---

### Task 1: Add SQLite Search Schema

**Files:**
- Create: `priv/repo/migrations/*_add_sqlite_issue_first_search.exs`
- Modify: `lib/faultline/search/issue_document.ex`
- Create: `lib/faultline/search/issue_tag_value.ex`
- Create: `lib/faultline/search/event_tag_value.ex`
- Test: `test/faultline/search/sqlite_store_test.exs`

- [x] **Step 1: Generate the migration**

Run: `mix ecto.gen.migration add_sqlite_issue_first_search`

Expected: a new migration under `priv/repo/migrations`.

- [x] **Step 2: Replace generated migration body**

Write a migration that:

```elixir
defmodule Faultline.Repo.Migrations.AddSqliteIssueFirstSearch do
  use Ecto.Migration

  def up do
    drop_if_exists index(:issue_search_documents, [:last_seen_at])
    drop_if_exists index(:issue_search_documents, [:level])
    drop_if_exists index(:issue_search_documents, [:environment])
    drop_if_exists index(:issue_search_documents, [:release])
    drop_if_exists index(:issue_search_documents, [:project_id])

    alter table(:issue_search_documents) do
      remove :document
      remove :tags
      remove :release
      remove :environment
      remove :level
      remove :logger
      remove :platform
      remove :server_name
      remove :user_identifier
      remove :request_url
      add :title, :text, null: false, default: ""
      add :body, :text, null: false, default: ""
    end

    create index(:issue_search_documents, [:project_id, :last_seen_at])

    create table(:issue_tag_values) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :issue_id, references(:issues, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :value, :string, null: false
      add :event_count, :integer, null: false, default: 0
      add :first_seen_at, :utc_datetime_usec, null: false
      add :last_seen_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:issue_tag_values, [:project_id, :issue_id, :key, :value])
    create index(:issue_tag_values, [:project_id, :key, :value, :issue_id])
    create index(:issue_tag_values, [:issue_id, :key, :value])

    create table(:event_tag_values) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :issue_id, references(:issues, on_delete: :delete_all), null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :value, :string, null: false
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:event_tag_values, [:project_id, :event_id, :key, :value])
    create index(:event_tag_values, [:project_id, :key, :value, :issue_id])
    create index(:event_tag_values, [:issue_id, :key, :value, :event_id])
    create index(:event_tag_values, [:issue_id, :occurred_at])

    execute("""
    CREATE VIRTUAL TABLE issue_search_fts USING fts5(
      title,
      body,
      content='issue_search_documents',
      content_rowid='id',
      tokenize='unicode61'
    )
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS issue_search_fts")
    drop table(:event_tag_values)
    drop table(:issue_tag_values)

    drop_if_exists index(:issue_search_documents, [:project_id, :last_seen_at])

    alter table(:issue_search_documents) do
      remove :title
      remove :body
      add :document, :text, null: false, default: ""
      add :tags, :text, null: false, default: ""
      add :release, :string
      add :environment, :string
      add :level, :string
      add :logger, :string
      add :platform, :string
      add :server_name, :string
      add :user_identifier, :string
      add :request_url, :string
    end

    create index(:issue_search_documents, [:project_id])
    create index(:issue_search_documents, [:release])
    create index(:issue_search_documents, [:environment])
    create index(:issue_search_documents, [:level])
    create index(:issue_search_documents, [:last_seen_at])
  end
end
```

- [x] **Step 3: Update schemas**

Change `Faultline.Search.IssueDocument` fields to `title` and `body`; add `Faultline.Search.IssueTagValue` and `Faultline.Search.EventTagValue` schemas with the fields from the migration.

- [x] **Step 4: Run migration and focused compile**

Run: `mix ecto.migrate && mix compile`

Expected: migration succeeds and compile passes.

### Task 2: Add Search Boundary And SQLite Store

**Files:**
- Create: `lib/faultline/search.ex`
- Create: `lib/faultline/search/store.ex`
- Create: `lib/faultline/search/store/sqlite.ex`
- Modify: `lib/faultline/search/query.ex`
- Test: `test/faultline/search/query_test.exs`
- Test: `test/faultline/search/sqlite_store_test.exs`

- [x] **Step 1: Extend query parsing tests**

Add tests that assert parsed queries expose reserved filters, tag filters, and text terms without changing the product syntax:

```elixir
assert query = Query.parse(~s(project:api status:unresolved release:"web 1" TypeError checkout))
assert query.reserved_filters == [{"project", "api"}, {"status", "unresolved"}]
assert query.tag_filters == [{"release", "web 1"}]
assert query.text_terms == ["TypeError", "checkout"]
```

- [x] **Step 2: Update `Faultline.Search.Query`**

Keep existing `text` and `filters` fields for compatibility, and add:

```elixir
defstruct text: "", filters: [], reserved_filters: [], tag_filters: [], text_terms: []
```

Reserved keys are `project`, `status`, and `issue`. All other key/value pairs become tag filters. Free text tokens become `text_terms`.

- [x] **Step 3: Add the store behaviour**

Create callbacks:

```elixir
@callback search_issues(Query.t(), keyword()) :: [String.t()]
@callback search_events(Query.t(), String.t(), keyword()) :: [String.t()]
@callback sync_event(Event.t(), Issue.t()) :: {:ok, term()} | {:error, term()}
@callback delete_event(Event.t()) :: :ok
@callback delete_issue(Issue.t()) :: :ok
```

- [x] **Step 4: Add `Faultline.Search` facade**

Route public calls to `Faultline.Search.Store.SQLite` for now:

```elixir
def parse(query), do: Query.parse(query)
def search_issues(query, opts), do: store().search_issues(Query.parse(query), opts)
def search_events(query, issue_id, opts), do: store().search_events(Query.parse(query), issue_id, opts)
def sync_event(event, issue), do: store().sync_event(event, issue)
```

- [x] **Step 5: Implement SQLite sync**

`Faultline.Search.Store.SQLite.sync_event/2` should:

- extract system and SDK tags
- insert event tag values with `on_conflict: :nothing`
- rebuild issue tag rollups for the issue from current event tags
- upsert `issue_search_documents`
- delete and reinsert the matching `issue_search_fts` row

- [x] **Step 6: Add sync tests**

Test that ingesting two events in the same issue creates event tag rows and issue tag rollups with counts and last seen timestamps.

- [x] **Step 7: Run focused tests**

Run: `mix test test/faultline/search/query_test.exs test/faultline/search/sqlite_store_test.exs`

Expected: all tests pass.

### Task 3: Move Issue Queries To Search Boundary

**Files:**
- Modify: `lib/faultline/issues.ex`
- Modify: `lib/faultline/search/store/sqlite.ex`
- Test: `test/faultline/issues_test.exs`

- [x] **Step 1: Add failing issue search tests**

Add tests for combined text and tag search:

```elixir
assert [target_issue.id] ==
         issue_ids(Issues.list_issues(search: "release:web@1.2.3 environment:production Checkout"))

assert [] == Issues.list_issues(search: "release:web@1.2.3 environment:staging Checkout")
```

- [x] **Step 2: Replace `IssueDocument.sync_event_issue/2` call**

In `Issues.group_event/1`, call:

```elixir
Search.sync_event(event, issue)
```

Keep broadcasting and alert dispatch unchanged.

- [x] **Step 3: Replace private document search**

In `Issues.search_issues/2`, call `Search.search_issues/2` and restrict by returned ids:

```elixir
case Search.search_issues(search, opts) do
  :all -> query
  [] -> where(query, false)
  issue_ids -> where(query, [issue], issue.id in ^issue_ids)
end
```

Keep project, status, and time filters in `Issues` for now so existing pagination and LiveViews remain stable.

- [x] **Step 4: Implement SQLite issue search ids**

`Store.SQLite.search_issues/2` should resolve reserved `project:` filters, tag filters through `issue_tag_values`, and text through `issue_search_fts`, returning matching issue ids.

- [x] **Step 5: Run issue tests**

Run: `mix test test/faultline/issues_test.exs`

Expected: all issue tests pass.

### Task 4: Add Event Drill-Down

**Files:**
- Modify: `lib/faultline/events.ex`
- Modify: `lib/faultline_web/live/issue_live/show.ex`
- Test: `test/faultline_web/live/issue_live_test.exs`

- [x] **Step 1: Add event search API**

Add:

```elixir
def list_issue_events(issue_id, opts \\ []) do
  search = Keyword.get(opts, :search, "")
  event_ids = Search.search_events(search, issue_id, opts)
  ...
end
```

If search has no reserved/tag filters, keep the existing query. If ids are empty, return `[]`. Otherwise restrict events by ids.

- [x] **Step 2: Add issue detail search UI**

In `IssueLive.Show`, add a search form above occurrences:

```heex
<.form for={@event_filter_form} id="issue-event-search-form" phx-change="filter_events">
  <.input field={@event_filter_form[:q]} type="search" placeholder="Filter events by release, environment, user, trace" phx-debounce="300" />
</.form>
```

Use `to_form(%{"q" => query}, as: :event_filters)`.

- [x] **Step 3: Handle filtering**

Add `handle_event("filter_events", %{"event_filters" => %{"q" => query}}, socket)` to reload `Events.list_issue_events(issue.id, search: query, limit: 20)`, clear selected raw JSON, and select the first matching event.

- [x] **Step 4: Add LiveView test**

Create two events in one issue with different releases and assert `release:web@2.0.0` filters the occurrence list to the matching event.

- [x] **Step 5: Run focused LiveView test**

Run: `mix test test/faultline_web/live/issue_live_test.exs`

Expected: all issue LiveView tests pass.

### Task 5: Verification And Cleanup

**Files:**
- Modify only files touched above if failures reveal issues.

- [x] **Step 1: Format**

Run: `mix format`

Expected: files formatted.

- [x] **Step 2: Run precommit**

Run: `mix precommit`

Expected: compile, deps check, format, and tests pass.

- [x] **Step 3: Inspect git diff**

Run: `git diff --stat`

Expected: changes are limited to search modules, migration, issue/event contexts, issue LiveView, and tests.
