defmodule RevenueApiWeb.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :revenue_api,
    module: RevenueApi.Guardian,
    error_handler: RevenueApiWeb.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
