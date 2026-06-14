defmodule FaultlineWeb.PageController do
  use FaultlineWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
