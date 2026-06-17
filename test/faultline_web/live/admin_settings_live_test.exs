defmodule FaultlineWeb.AdminSettingsLiveTest do
  use FaultlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Faultline.AccountsFixtures

  alias Faultline.InstanceSettings
  alias Faultline.Projects

  test "redirects anonymous users", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/settings")
  end

  test "redirects non-admin users", %{conn: conn} do
    user = user_fixture()
    {:ok, user} = Faultline.Accounts.update_user_role(user, %{role: "member"})

    conn = log_in_user(conn, user)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/settings")
  end

  test "updates the public DSN base URL", %{conn: conn} do
    admin = admin_user_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/settings")

    assert has_element?(view, "#admin-instance-settings-page")
    assert has_element?(view, "#public-dsn-base-url-form")
    assert has_element?(view, "#current-public-dsn-base-url", "http://localhost:4010")

    view
    |> form("#public-dsn-base-url-form",
      instance_settings: %{"public_dsn_base_url" => "https://faultline-demo.fly.dev/base"}
    )
    |> render_submit()

    assert InstanceSettings.public_dsn_base_url() == "https://faultline-demo.fly.dev"
    assert has_element?(view, "#current-public-dsn-base-url", "https://faultline-demo.fly.dev")
    assert render(view) =~ "Public DSN base URL updated."
  end

  test "regenerates existing project DSNs with the configured public base URL", %{conn: conn} do
    admin = admin_user_fixture()

    assert {:ok, project} =
             Projects.create_project(%{"name" => "Old Host"},
               dsn_base_url: "https://old.example.com"
             )

    {:ok, view, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/settings")

    view
    |> form("#public-dsn-base-url-form",
      instance_settings: %{"public_dsn_base_url" => "https://errors.example.com"}
    )
    |> render_submit()

    view
    |> element("#regenerate-project-dsns-button")
    |> render_click()

    project = Projects.get_project!(project.id)

    assert project.dsn ==
             "https://#{project.public_key}:#{project.secret_key}@errors.example.com/#{project.project_number}"

    assert render(view) =~ "Regenerated 1 project DSN."
  end
end
