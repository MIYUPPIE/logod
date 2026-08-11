import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :revenue_api, RevenueApi.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "revenue_api_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :revenue_api, RevenueApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "f+/iFlUg91onV4Paz5r+pkEJgE2LrUjcMmvtgBgbkFtc4ls6xPfZHBfZPR5GWsMX",
  server: false

# In test we don't send emails
config :revenue_api, RevenueApi.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

config :revenue_api, RevenueApi.Guardian,
  secret_key: "test_only_guardian_secret_do_not_use_in_prod_aB3xQ9"

config :revenue_api, :receipt_signing_key, "test_only_receipt_signing_key"

# Jobs are inserted but not auto-executed; tests use Oban.Testing to assert
# on enqueued jobs and run workers explicitly.
config :revenue_api, Oban, testing: :manual

config :revenue_api, :notifier, RevenueApi.NotifierMock
config :revenue_api, :storage, RevenueApi.Storage.Local
config :revenue_api, :storage_local, base_dir: Path.expand("../priv/uploads_test", __DIR__)
