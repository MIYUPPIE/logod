defmodule RevenueApiWeb.LevyTypeController do
  use RevenueApiWeb, :controller

  alias RevenueApi.Levies

  def index(conn, %{"lga_id" => lga_id}) do
    render(conn, :index, levy_types: Levies.list_levy_types(lga_id))
  end
end
