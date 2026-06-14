defmodule FaultlineWeb.Router do
  use FaultlineWeb, :router

  import FaultlineWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FaultlineWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FaultlineWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", FaultlineWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated_app,
      on_mount: [{FaultlineWeb.UserAuth, :require_authenticated}] do
      live "/projects", ProjectLive.Index, :index
      live "/projects/new", ProjectLive.New, :new
      live "/projects/:project_id/alerts", AlertLive.Index, :index
      live "/projects/:project_id/issues", IssueLive.Index, :index
      live "/projects/:project_id/issues/:id", IssueLive.Show, :show
    end
  end

  scope "/admin", FaultlineWeb.Admin do
    pipe_through [:browser, :require_authenticated_user, :require_admin_user]

    live_session :admin,
      on_mount: [{FaultlineWeb.UserAuth, :require_admin}] do
      live "/users", UserLive.Index, :index
    end
  end

  # Other scopes may use custom stacks.
  scope "/api", FaultlineWeb do
    pipe_through :api

    post "/:project_id/store/", IngestController, :store
    post "/:project_id/envelope/", IngestController, :envelope
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:faultline, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FaultlineWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", FaultlineWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{FaultlineWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", FaultlineWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{FaultlineWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
