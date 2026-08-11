defmodule RevenueApiWeb.PageController do
  use RevenueApiWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
