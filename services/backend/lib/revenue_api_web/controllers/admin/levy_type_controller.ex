defmodule RevenueApiWeb.Admin.LevyTypeController do
  use RevenueApiWeb, :controller

  alias RevenueApi.Levies

  action_fallback RevenueApiWeb.FallbackController

  def create(conn, params) do
    with {:ok, levy_type} <-
           Levies.create_levy_type(params, current_user(conn), request_context(conn)) do
      conn
      |> put_status(:created)
      |> json(RevenueApiWeb.LevyTypeJSON.show(%{levy_type: levy_type}))
    end
  end

  def update(conn, %{"id" => id} = params) do
    levy_type = Levies.get_levy_type!(id)
    attrs = Map.take(params, ["amount", "frequency"])

    with {:ok, updated} <-
           Levies.update_levy_type(levy_type, attrs, current_user(conn), request_context(conn)) do
      json(conn, RevenueApiWeb.LevyTypeJSON.show(%{levy_type: updated}))
    end
  end
end
