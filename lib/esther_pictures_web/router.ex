defmodule EstherPicturesWeb.Router do
  use EstherPicturesWeb, :router

  import EstherPicturesWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EstherPicturesWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", EstherPicturesWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", EstherPicturesWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:esther_pictures, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: EstherPicturesWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  # Bootstrap registration: creating the first admin. The controller closes
  # this route once any account exists.
  scope "/", EstherPicturesWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", EstherPicturesWeb do
    pipe_through [:browser]

    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  ## Admin

  # Reachable while `must_change_password` is set — it must NOT be behind the
  # password-change gate, or a forced user could never get out.
  scope "/admin", EstherPicturesWeb.Admin, as: :admin do
    pipe_through [:browser, :require_authenticated_user]

    get "/change-password", PasswordController, :edit
    put "/change-password", PasswordController, :update
  end

  # The admin app proper: authenticated + past the forced password change.
  scope "/admin", EstherPicturesWeb.Admin, as: :admin do
    pipe_through [:browser, :require_authenticated_user, :require_password_change]

    get "/", DashboardController, :index

    get "/settings", SiteSettingController, :edit
    put "/settings", SiteSettingController, :update

    resources "/craft", CraftServiceController, except: [:show]
    resources "/clips", ClipController, except: [:show]
    resources "/ensemble", EnsembleMemberController, except: [:show]
  end

  # User management is restricted to administrators.
  scope "/admin", EstherPicturesWeb.Admin, as: :admin do
    pipe_through [
      :browser,
      :require_authenticated_user,
      :require_password_change,
      :require_admin_user
    ]

    resources "/users", UserController, only: [:index, :new, :create, :delete]

    get "/history", HistoryController, :index
    post "/history/:id/restore", HistoryController, :restore
    delete "/history/:id", HistoryController, :delete
    delete "/history", HistoryController, :clear
  end
end
