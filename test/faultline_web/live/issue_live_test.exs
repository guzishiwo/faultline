defmodule FaultlineWeb.IssueLiveTest do
  use FaultlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Faultline.Events
  alias Faultline.Ingest.RawEvent
  alias Faultline.Issues.Issue
  alias Faultline.Projects
  alias Faultline.Repo

  @fixtures Path.expand("../../fixtures/sentry_events", __DIR__)

  setup :register_and_log_in_user

  test "lists project issues and links to details", %{conn: conn} do
    project = project_fixture()
    event = event_fixture(project, "javascript.json")

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/issues")

    assert has_element?(view, "#issues")
    assert has_element?(view, "#issues-#{event.issue_id}")
  end

  test "loads more issues with keyset pagination", %{conn: conn} do
    project = project_fixture()

    events =
      for index <- 1..21 do
        event_fixture(project, "javascript.json", %{
          "event_id" => String.pad_leading(Integer.to_string(index), 32, "0"),
          "culprit" => "checkout.step.#{index}",
          "timestamp" =>
            "2026-06-14T15:#{String.pad_leading(Integer.to_string(index), 2, "0")}:00Z",
          "exception" => distinct_exception(index)
        })
      end

    oldest_event = List.first(events)

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/issues")

    assert has_element?(view, "#load-more-issues")
    refute has_element?(view, "#issues-#{oldest_event.issue_id}")

    view
    |> element("#load-more-issues")
    |> render_click()

    assert has_element?(view, "#issues-#{oldest_event.issue_id}")
  end

  test "searches issues by title", %{conn: conn} do
    project = project_fixture()

    target_event =
      event_fixture(project, "javascript.json", %{
        "event_id" => "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "exception" => distinct_exception(1, "Checkout search target")
      })

    other_event =
      event_fixture(project, "javascript.json", %{
        "event_id" => "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        "exception" => distinct_exception(2, "Background worker failed")
      })

    target_issue = Repo.get!(Issue, target_event.issue_id)

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/issues")

    assert has_element?(view, "#issue-search-form")

    assert has_element?(
             view,
             ~s|#issue-search-form input[placeholder="Search issues, e.g. release:web@1.2.3 environment:prod TypeError"]|
           )

    assert has_element?(
             view,
             ~s|#issue-search-form .hero-magnifying-glass[class*="top-1/2"][class*="-translate-y-1/2"]|
           )

    assert has_element?(view, "#issues-#{target_event.issue_id}")
    assert has_element?(view, "#issues-#{other_event.issue_id}")

    view
    |> element("#issue-search-form")
    |> render_change(%{"filters" => %{"q" => target_issue.title, "project" => project.id}})

    assert has_element?(view, "#issues-#{target_event.issue_id}")
    refute has_element?(view, "#issues-#{other_event.issue_id}")

    view
    |> element("#clear-issue-filters")
    |> render_click()

    assert has_element?(view, "#issues-#{target_event.issue_id}")
    assert has_element?(view, "#issues-#{other_event.issue_id}")
  end

  test "global issues filters across projects", %{conn: conn} do
    first_project = project_fixture(%{"platform" => "react"})
    second_project = project_fixture(%{"platform" => "flutter"})

    first_event = event_fixture(first_project, "javascript.json")
    second_event = event_fixture(second_project, "ruby.json")

    {:ok, view, _html} = live(conn, ~p"/issues?project=-1")

    assert has_element?(view, "#issue-search-form")
    assert has_element?(view, click_away_wrapper_selector("#theme-menu-trigger"))
    assert has_element?(view, click_away_wrapper_selector("#account-menu-trigger"))
    assert has_element?(view, "#issues-#{first_event.issue_id}")
    assert has_element?(view, "#issues-#{second_event.issue_id}")
    assert has_element?(view, "#issues-#{first_event.issue_id}", first_project.name)
    assert has_element?(view, "#issues-#{second_event.issue_id}", second_project.name)
    assert has_element?(view, "#issue-project-meta-#{first_event.issue_id}", first_project.name)
    assert has_element?(view, "#issue-project-meta-#{second_event.issue_id}", second_project.name)
    refute has_element?(view, "#issues-#{first_event.issue_id} .font-mono")
    assert has_element?(view, "#project-filter-menu")
    assert has_element?(view, click_away_details_selector("#project-filter-menu"))
    assert has_element?(view, "#project-filter-logo-#{first_project.id}", "R")
    assert has_element?(view, "#project-filter-logo-#{second_project.id}", "F")
    assert has_element?(view, click_away_details_selector("#status-filter-menu"))
    assert has_element?(view, click_away_details_selector("#time-filter-menu"))
    assert has_element?(view, "#issue-project-logo-#{first_event.issue_id}", "R")

    view
    |> element("#issue-search-form")
    |> render_change(%{
      "filters" => %{
        "q" => "",
        "project" => first_project.id,
        "status" => "all",
        "time" => "all"
      }
    })

    assert_patch(view, ~p"/issues?project=#{first_project.id}")
    assert has_element?(view, "#issues-#{first_event.issue_id}")
    refute has_element?(view, "#issues-#{second_event.issue_id}")
  end

  test "global issues filters by status", %{conn: conn} do
    resolved_project = project_fixture(%{"platform" => "browser_javascript"})
    unresolved_project = project_fixture(%{"platform" => "rails"})

    resolved_event = event_fixture(resolved_project, "javascript.json")
    unresolved_event = event_fixture(unresolved_project, "ruby.json")

    resolved_issue = Repo.get!(Issue, resolved_event.issue_id)
    assert {:ok, _issue} = Faultline.Issues.update_issue_status(resolved_issue, "resolved")

    {:ok, view, _html} = live(conn, ~p"/issues?project=-1")

    view
    |> element("#issue-search-form")
    |> render_change(%{
      "filters" => %{
        "q" => "",
        "project" => "-1",
        "status" => "resolved",
        "time" => "all"
      }
    })

    assert_patch(view, ~p"/issues?project=-1&status=resolved")
    assert has_element?(view, "#issues-#{resolved_event.issue_id}")
    refute has_element?(view, "#issues-#{unresolved_event.issue_id}")
  end

  test "inserts new issues through PubSub", %{conn: conn} do
    project = project_fixture()
    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/issues")

    assert has_element?(view, "#issues-empty-state")

    event = event_fixture(project, "javascript.json")

    assert has_element?(view, "#issues-#{event.issue_id}")
  end

  test "shows issue details, updates status, and loads raw event JSON", %{conn: conn} do
    project = project_fixture()

    older_event =
      event_fixture(project, "javascript.json", %{
        "timestamp" => "2026-06-14T15:00:00Z",
        "release" => "web@1.2.3"
      })

    newer_event =
      event_fixture(project, "javascript.json", %{
        "event_id" => "99999999999999999999999999999999",
        "timestamp" => "2026-06-14T15:05:00Z",
        "release" => "web@2.0.0",
        "exception" => source_context_exception(),
        "contexts" => smoke_contexts(),
        "sdk" => smoke_sdk(),
        "modules" => %{"@sentry/node" => "^10.57.0"}
      })

    newer_event
    |> Ecto.Changeset.change(details: Map.drop(newer_event.details, ~w(contexts modules sdk)))
    |> Repo.update!()

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/issues/#{older_event.issue_id}")

    assert has_element?(view, "#issue-status", "unresolved")

    assert has_element?(
             view,
             ~s|#set-status-unresolved[class*="border-error/40"][class*="bg-error/10"][class*="text-error"]|
           )

    assert has_element?(
             view,
             ~s|#set-status-resolved[class*="border-success/25"][class*="text-success"]|
           )

    assert has_element?(
             view,
             ~s|#set-status-ignored[class*="border-base-300"][class*="text-base-content/60"]|
           )

    assert has_element?(view, "#issue-occurrences")
    assert has_element?(view, "#select-event-#{older_event.id}")
    assert has_element?(view, "#select-event-#{newer_event.id}")

    view
    |> element("#select-event-#{newer_event.id}")
    |> render_click()

    assert has_element?(view, "#issue-event-#{newer_event.id}")
    assert has_element?(view, "#stack-frame-1")
    assert has_element?(view, "details#event-overview[open] summary", "Overview")
    assert has_element?(view, "details#event-stacktrace[open] summary", "Stacktrace")
    assert has_element?(view, "details#event-context[open] summary", "Context")
    assert has_element?(view, "details#event-sdk[open] summary", "SDK and runtime")
    assert has_element?(view, "details#event-breadcrumbs summary", "Breadcrumbs")
    assert has_element?(view, "#event-context-runtime", "node")
    assert has_element?(view, "#event-context-app", "100.3 MB")
    assert has_element?(view, "#event-context-app", "3.1 GB")
    assert has_element?(view, "#event-context-device", "Apple M3 Pro")
    assert has_element?(view, "#event-context-device", "18 GB")
    assert has_element?(view, "#event-context-device", "11")
    assert has_element?(view, "#event-context-trace", "ab08bb5f21f04795ad26d8d3f919379d")
    refute has_element?(view, "#event-context .font-medium")
    assert has_element?(view, "#stack-frame-1-source", "const amount = cart.total")
    assert has_element?(view, "#stack-frame-1-source", "throw new TypeError")
    assert has_element?(view, "#stack-frame-1-source", "return charge")
    assert has_element?(view, "#stack-frame-1-source code[phx-hook='CodeHighlight']")
    assert has_element?(view, "#stack-frame-1-source code[data-prism-language='javascript']")
    assert has_element?(view, "#stack-frame-1-var-cart", "cart-123")
    assert has_element?(view, "#stack-frame-1-var-amount", "149.99")
    assert has_element?(view, "#event-modules", "@sentry/node")
    assert has_element?(view, "#event-sdk", "sentry.javascript.node")
    refute has_element?(view, "#event-sdk .font-medium")
    assert has_element?(view, "#load-raw-event-#{newer_event.id}")

    view
    |> element("#set-status-resolved")
    |> render_click()

    assert has_element?(view, "#issue-status", "resolved")

    assert has_element?(
             view,
             ~s|#set-status-resolved[class*="border-success/40"][class*="bg-success/10"][class*="text-success"]|
           )

    assert has_element?(
             view,
             ~s|#set-status-unresolved[class*="border-error/25"][class*="text-error"]|
           )

    assert has_element?(
             view,
             ~s|#set-status-ignored[class*="border-base-300"][class*="text-base-content/60"]|
           )

    view
    |> element("#select-event-#{older_event.id}")
    |> render_click()

    assert has_element?(view, "#issue-event-#{older_event.id}")
    assert has_element?(view, "#issue-event-#{older_event.id}", "web@1.2.3")

    view
    |> element("#load-raw-event-#{older_event.id}")
    |> render_click()

    assert has_element?(view, "#raw-event-json")
    assert has_element?(view, "#raw-event-json code[phx-hook='CodeHighlight']")
    assert has_element?(view, "#raw-event-json code[data-prism-language='json']")
    assert has_element?(view, "#raw-event-json", "web@1.2.3")

    view
    |> element("#select-event-#{newer_event.id}")
    |> render_click()

    assert has_element?(view, "#issue-event-#{newer_event.id}")
    refute has_element?(view, "#raw-event-json")
  end

  test "filters issue detail events by tag query", %{conn: conn} do
    project = project_fixture()

    older_event =
      event_fixture(project, "javascript.json", %{
        "timestamp" => "2026-06-14T15:00:00Z",
        "release" => "web@1.2.3"
      })

    newer_event =
      event_fixture(project, "javascript.json", %{
        "event_id" => "99999999999999999999999999999999",
        "timestamp" => "2026-06-14T15:05:00Z",
        "release" => "web@2.0.0"
      })

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/issues/#{older_event.issue_id}")

    assert has_element?(view, "#issue-event-search-form")

    assert has_element?(
             view,
             ~s|#issue-event-search-form .hero-magnifying-glass[class*="top-1/2"][class*="-translate-y-1/2"]|
           )

    assert has_element?(view, "#select-event-#{older_event.id}")
    assert has_element?(view, "#select-event-#{newer_event.id}")

    view
    |> element("#issue-event-search-form")
    |> render_change(%{"event_filters" => %{"q" => "release:web@2.0.0"}})

    refute has_element?(view, "#select-event-#{older_event.id}")
    assert has_element?(view, "#select-event-#{newer_event.id}")
    assert has_element?(view, "#issue-event-#{newer_event.id}")
  end

  test "marks source frames with common Sentry SDK languages", %{conn: conn} do
    project = project_fixture()

    event =
      event_fixture(project, "javascript.json", %{
        "exception" => source_context_exception(common_source_languages())
      })

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/issues/#{event.issue_id}")

    for {index, {_filename, language}} <-
          Enum.with_index(Enum.reverse(common_source_languages()), 1) do
      assert has_element?(
               view,
               "#stack-frame-#{index}-source code[data-prism-language='#{language}']"
             )
    end
  end

  test "project list links to issue triage", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/projects")

    assert has_element?(view, "#project-issues-link-#{project.id}")
    assert has_element?(view, "#project-settings-link-#{project.id}")
  end

  defp event_fixture(project, fixture, overrides \\ %{}) do
    payload =
      fixture
      |> fixture_payload()
      |> Map.merge(overrides)

    raw_event =
      %RawEvent{}
      |> RawEvent.changeset(%{
        project_id: project.id,
        event_id: payload["event_id"],
        source: "store",
        payload_type: "event",
        payload: payload,
        auth: %{"public_key" => project.public_key},
        received_at: ~U[2026-06-14 16:00:00.000000Z]
      })
      |> Repo.insert!()

    assert {:ok, event} = Events.normalize_raw_event(raw_event)
    event
  end

  defp fixture_payload(filename) do
    @fixtures
    |> Path.join(filename)
    |> File.read!()
    |> Jason.decode!()
  end

  defp distinct_exception(index, value \\ "Cannot read properties of undefined") do
    %{
      "values" => [
        %{
          "type" => "TypeError",
          "value" => value,
          "stacktrace" => %{
            "frames" => [
              %{
                "filename" => "assets/js/checkout_#{index}.js",
                "function" => "submitOrder#{index}",
                "lineno" => 42,
                "in_app" => true
              }
            ]
          }
        }
      ]
    }
  end

  defp source_context_exception do
    source_context_exception([{"app.js", "javascript"}])
  end

  defp source_context_exception(frames) do
    %{
      "values" => [
        %{
          "type" => "TypeError",
          "value" => "Cannot read properties of undefined",
          "stacktrace" => %{
            "frames" => Enum.map(frames, &source_context_frame/1)
          }
        }
      ]
    }
  end

  defp source_context_frame({filename, _language}) do
    %{
      "filename" => filename,
      "function" => "submitOrder",
      "lineno" => 42,
      "colno" => 13,
      "pre_context" => [
        "const amount = cart.total",
        "const charge = createCharge(amount)",
        "",
        "try {"
      ],
      "context_line" => "  throw new TypeError(\"Cannot read properties of undefined\")",
      "post_context" => [
        "} finally {",
        "  return charge",
        "}"
      ],
      "vars" => %{
        "amount" => "149.99",
        "cart" => "{id: \"cart-123\", items: 3}"
      }
    }
  end

  defp common_source_languages do
    [
      {"app.ts", "typescript"},
      {"App.jsx", "jsx"},
      {"Screen.tsx", "tsx"},
      {"worker.py", "python"},
      {"job.rb", "ruby"},
      {"index.php", "php"},
      {"Checkout.java", "java"},
      {"Checkout.kt", "kotlin"},
      {"Program.cs", "csharp"},
      {"main.go", "go"},
      {"lib.rs", "rust"},
      {"App.swift", "swift"},
      {"ViewController.m", "objectivec"},
      {"main.dart", "dart"},
      {"native.c", "c"},
      {"addon.cpp", "cpp"},
      {"worker.ex", "elixir"},
      {"event.json", "json"}
    ]
  end

  defp smoke_contexts do
    %{
      "device" => %{
        "arch" => "arm64",
        "cpu_description" => "Apple M3 Pro",
        "memory_size" => 19_327_352_832,
        "processor_count" => 11
      },
      "app" => %{
        "app_memory" => 105_168_896,
        "free_memory" => 3_376_431_104
      },
      "runtime" => %{"name" => "node", "version" => "v25.8.2"},
      "trace" => %{
        "trace_id" => "ab08bb5f21f04795ad26d8d3f919379d",
        "span_id" => "b1ecefa84c94387a"
      }
    }
  end

  defp smoke_sdk do
    %{
      "name" => "sentry.javascript.node",
      "version" => "10.57.0",
      "packages" => [%{"name" => "npm:@sentry/node", "version" => "10.57.0"}],
      "integrations" => ["InboundFilters", "NodeFetch", "Express"]
    }
  end

  defp project_fixture(attrs \\ %{}) do
    assert {:ok, project} =
             %{"name" => unique_project_name()}
             |> Map.merge(attrs)
             |> Projects.create_project(dsn_base_url: "https://errors.example.com")

    project
  end

  defp unique_project_name do
    "Project #{System.unique_integer([:positive])}"
  end

  defp click_away_details_selector(selector) do
    "#{selector}[data-close-on-click-away][phx-click-away][phx-window-keydown][phx-key='escape']"
  end

  defp click_away_wrapper_selector(child_selector) do
    "details[data-close-on-click-away][phx-click-away][phx-window-keydown][phx-key='escape'] #{child_selector}"
  end
end
