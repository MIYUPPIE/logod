import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/revenue_api start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :revenue_api, RevenueApiWeb.Endpoint, server: true
end

config :revenue_api, RevenueApiWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :revenue_api, RevenueApiWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
        # Gettext translations
        ~r"priv/gettext/.*\.po$",
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/revenue_api_web/router\.ex$",
        ~r"lib/revenue_api_web/(controllers|live|components)/.*\.(ex|heex)$"
      ]
    ]
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :revenue_api, RevenueApi.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :revenue_api, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :revenue_api, RevenueApiWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base,
    # SRS §8: all API traffic over HTTPS. Self-signed is fine for a pilot
    # behind a reverse proxy that terminates TLS; this still forces the
    # redirect + HSTS at the app layer either way.
    force_ssl: [hsts: true]

  guardian_secret =
    System.get_env("GUARDIAN_SECRET_KEY") ||
      raise "environment variable GUARDIAN_SECRET_KEY is missing"

  config :revenue_api, RevenueApi.Guardian, secret_key: guardian_secret

  receipt_signing_key =
    System.get_env("RECEIPT_SIGNING_KEY") ||
      raise "environment variable RECEIPT_SIGNING_KEY is missing"

  config :revenue_api, :receipt_signing_key, receipt_signing_key

  # SRS §9 open decision: Termii, behind the Notifier behaviour (see
  # specs/mvp_design.md). Swapping to Africa's Talking is a one-line change
  # here plus a new adapter module.
  config :revenue_api, :notifier, RevenueApi.Notifier.Termii

  config :revenue_api, :termii,
    api_key: System.get_env("TERMII_API_KEY"),
    sender_id: System.get_env("TERMII_SENDER_ID", "RevenueNG"),
    base_url: System.get_env("TERMII_BASE_URL", "https://api.ng.termii.com")

  config :revenue_api, :storage, RevenueApi.Storage.S3
  config :revenue_api, :storage_s3, bucket: System.get_env("S3_BUCKET", "revenue-mvp-uploads")

  # Comma-separated allowlist, e.g. "https://admin.example.com,https://agent.example.com"
  config :revenue_api,
         :cors_origins,
         (System.get_env("CORS_ORIGINS") || "") |> String.split(",", trim: true)

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :revenue_api, RevenueApiWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :revenue_api, RevenueApiWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :revenue_api, RevenueApi.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://swoosh.hexdocs.pm/Swoosh.html#module-installation for details.
end
