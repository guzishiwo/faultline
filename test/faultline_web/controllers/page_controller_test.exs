defmodule FaultlineWeb.PageControllerTest do
  use FaultlineWeb.ConnCase

  test "GET / renders the focused public homepage", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ "Self-hosted error tracking in one Docker command."
    assert html =~ "$ docker run"
    assert html =~ "docker run -p 4010:4010 -v faultline-data:/data faultline"
    assert html =~ "Sentry SDK compatible error tracking"
    assert html =~ "Connect existing SDKs"
    assert html =~ "See grouped issues"
    assert html =~ "Keep ownership of your data"
    assert html =~ "What you get after install"
    assert html =~ "Issue inbox"
    assert html =~ "Event detail"
    assert html =~ "Noise control"
    assert html =~ "Error tracking first. Heavy observability later."
    assert html =~ "Create account"
    assert html =~ "Log in"
    refute html =~ "Architecture snapshot"
    refute html =~ "Realtime triage"
  end
end
