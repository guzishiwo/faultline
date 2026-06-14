defmodule FaultlineWeb.AdminUserLiveTest do
  use FaultlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Faultline.AccountsFixtures

  alias Faultline.Accounts

  test "redirects anonymous users", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/users")
  end

  test "redirects non-admin users", %{conn: conn} do
    user = user_fixture()
    {:ok, user} = Accounts.update_user_role(user, %{role: "member"})

    conn = log_in_user(conn, user)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/users")
  end

  test "lists users for admins and updates roles", %{conn: conn} do
    admin = admin_user_fixture()
    member = user_fixture()
    {:ok, member} = Accounts.update_user_role(member, %{role: "member"})

    {:ok, view, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/users")

    assert has_element?(view, "#admin-users")
    assert has_element?(view, "#user-role-#{member.id}", "member")

    view
    |> element("#make-admin-#{member.id}")
    |> render_click()

    assert has_element?(view, "#user-role-#{member.id}", "admin")
  end

  test "does not demote the last admin", %{conn: conn} do
    admin = admin_user_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/users")

    view
    |> element("#make-member-#{admin.id}")
    |> render_click()

    assert has_element?(view, "#user-role-#{admin.id}", "admin")
    assert render(view) =~ "Faultline needs at least one admin user."
  end
end
