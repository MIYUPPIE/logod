defmodule RevenueApiWeb.RootRedirectController do
  use RevenueApiWeb, :controller

  def index(conn, _params) do
    if get_session(conn, :user_id) do
      redirect(conn, to: ~p"/dashboard")
    else
      redirect(conn, to: ~p"/login")
    end
  end
end
