defmodule RevenueApiWeb.LevyTypeController do
  use RevenueApiWeb, :controller

  alias RevenueApi.{Levies, Authz}

  action_fallback RevenueApiWeb.FallbackController

  def index(conn, %{"lga_id" => lga_id}) do
    case Integer.parse(lga_id) do
      {lga_id, ""} ->
        with :ok <- Authz.authorize_lga(current_user(conn), lga_id) do
          render(conn, :index, levy_types: Levies.list_levy_types(lga_id))
        end

      _ ->
        conn |> put_status(:bad_request) |> json(%{errors: %{detail: "invalid lga_id"}})
    end
  end
end
