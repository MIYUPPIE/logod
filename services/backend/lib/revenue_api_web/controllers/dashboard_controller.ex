defmodule RevenueApiWeb.DashboardController do
  use RevenueApiWeb, :controller

  alias RevenueApi.Dashboard

  def summary(conn, _params) do
    json(conn, Dashboard.summary(current_user(conn)))
  end
end
