defmodule RevenueApiWeb.Admin.UserController do
  use RevenueApiWeb, :controller

  alias RevenueApi.Accounts

  action_fallback RevenueApiWeb.FallbackController

  def index(conn, _params) do
    json(conn, RevenueApiWeb.UserJSON.index(%{users: Accounts.list_users()}))
  end

  def create(conn, params) do
    with {:ok, user} <- Accounts.create_user(params, current_user(conn), request_context(conn)) do
      conn |> put_status(:created) |> json(RevenueApiWeb.UserJSON.show(%{user: user}))
    end
  end
end
