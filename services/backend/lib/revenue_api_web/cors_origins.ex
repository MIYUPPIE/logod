defmodule RevenueApiWeb.CorsOrigins do
  @moduledoc "Reads the CORS allowlist from app config so it's env-driven (see config/runtime.exs)."
  def list, do: Application.get_env(:revenue_api, :cors_origins, ["*"])
end
