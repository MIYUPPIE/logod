# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :revenue_api,
  ecto_repos: [RevenueApi.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :revenue_api, RevenueApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: RevenueApiWeb.ErrorHTML, json: RevenueApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RevenueApi.PubSub,
  live_view: [signing_salt: "gaUXenTB"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :revenue_api, RevenueApi.Mailer, adapter: Swoosh.Adapters.Local

config :revenue_api, RevenueApi.Guardian, issuer: "revenue_api"

config :revenue_api, Oban,
  repo: RevenueApi.Repo,
  queues: [default: 10, sms: 10, pdf: 5],
  plugins: [{Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}]

config :hammer,
  backend:
    {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

# Swapped per-env: Notifier.Console in dev, NotifierMock (Mox) in test,
# Notifier.Termii in prod. See specs/mvp_design.md "SMS Confirmation".
config :revenue_api, :notifier, RevenueApi.Notifier.Console
config :revenue_api, :storage, RevenueApi.Storage.Local
config :revenue_api, :storage_local, base_dir: Path.expand("../priv/uploads", __DIR__)
config :revenue_api, :cors_origins, ["*"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  revenue_api: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  revenue_api: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
