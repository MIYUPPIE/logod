defmodule RevenueApiWeb.Router do
  use RevenueApiWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RevenueApiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug, origin: {RevenueApiWeb.CorsOrigins, :list, []}
  end

  pipeline :authenticated do
    plug RevenueApiWeb.AuthPipeline
    plug RevenueApiWeb.Plugs.RequestContext
  end

  pipeline :require_admin_or_supervisor do
    plug RevenueApiWeb.Plugs.RequireRole, [:admin, :supervisor]
  end

  pipeline :require_admin do
    plug RevenueApiWeb.Plugs.RequireRole, [:admin]
  end

  scope "/api/v1", RevenueApiWeb do
    pipe_through :api

    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
    get "/verify/:receipt_qr_payload", VerifyController, :show
  end

  scope "/api/v1", RevenueApiWeb do
    pipe_through [:api, :authenticated]

    post "/auth/logout", AuthController, :logout

    post "/sellers", SellerController, :create
    get "/sellers/search", SellerController, :search
    get "/sellers/qr/:seller_uid", SellerController, :show_by_qr
    get "/sellers/:id", SellerController, :show
    get "/sellers/:id/payments", SellerController, :payments

    get "/levy-types", LevyTypeController, :index

    post "/payments", PaymentController, :create
    get "/payments/:id", PaymentController, :show

    get "/receipts/:id/pdf", ReceiptController, :pdf

    post "/sync/batch", SyncController, :batch

    get "/geo/states", GeoController, :states
    get "/geo/lgas", GeoController, :lgas
    get "/geo/wards", GeoController, :wards
    get "/geo/markets", GeoController, :markets
  end

  scope "/api/v1", RevenueApiWeb do
    pipe_through [:api, :authenticated, :require_admin_or_supervisor]

    get "/dashboard/summary", DashboardController, :summary
    get "/reports/revenue", ReportController, :revenue
  end

  scope "/api/v1/admin", RevenueApiWeb do
    pipe_through [:api, :authenticated, :require_admin]

    get "/users", Admin.UserController, :index
    post "/users", Admin.UserController, :create
    patch "/levy-types/:id", Admin.LevyTypeController, :update
  end

  scope "/", RevenueApiWeb do
    pipe_through :api
    get "/uploads/:token", UploadController, :show
  end

  scope "/", RevenueApiWeb do
    pipe_through :browser

    get "/", RootRedirectController, :index
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete
  end

  scope "/", RevenueApiWeb do
    pipe_through :browser

    live_session :web_authenticated,
      on_mount: [{RevenueApiWeb.LiveUserAuth, {:ensure_role, [:admin, :supervisor]}}] do
      live "/dashboard", SupervisorDashboardLive, :index
    end

    live_session :web_admin,
      on_mount: [{RevenueApiWeb.LiveUserAuth, {:ensure_role, [:admin]}}] do
      live "/admin/users", Admin.UsersLive, :index
      live "/admin/levy-types", Admin.LevyTypesLive, :index
      live "/admin/reports", Admin.ReportsLive, :index
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:revenue_api, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RevenueApiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
