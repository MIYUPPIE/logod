defmodule RevenueApiWeb.GeoController do
  use RevenueApiWeb, :controller

  alias RevenueApi.Geo

  def states(conn, _params) do
    render(conn, :index, nodes: Geo.list_states())
  end

  def lgas(conn, %{"state_id" => state_id}) do
    render(conn, :index, nodes: Geo.list_lgas(state_id))
  end

  def wards(conn, %{"lga_id" => lga_id}) do
    render(conn, :index, nodes: Geo.list_wards(lga_id))
  end

  def markets(conn, %{"ward_id" => ward_id}) do
    render(conn, :index, nodes: Geo.list_markets(ward_id))
  end
end
