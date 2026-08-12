defmodule RevenueApiWeb.Admin.LevyTypeController do
  use RevenueApiWeb, :controller

  alias RevenueApi.Levies

  action_fallback RevenueApiWeb.FallbackController

  def update(conn, %{"id" => id} = params) do
    levy_type = Levies.get_levy_type!(id)
    attrs = Map.take(params, ["amount", "frequency"])

    with {:ok, updated} <-
           Levies.update_levy_type(levy_type, attrs, current_user(conn), request_context(conn)) do
      json(conn, RevenueApiWeb.LevyTypeJSON.show(%{levy_type: updated}))
    end
  end
end
