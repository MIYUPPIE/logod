defmodule RevenueApi.Repo do
  use Ecto.Repo,
    otp_app: :revenue_api,
    adapter: Ecto.Adapters.Postgres
end
