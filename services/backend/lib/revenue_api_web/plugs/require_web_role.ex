defmodule RevenueApiWeb.Plugs.RequireWebRole do
  @moduledoc """
  Session-cookie equivalent of RequireRole, for plain (non-LiveView)
  browser routes such as the CSV report download — a normal `<a href>`
  can't carry a Bearer token, so it has to ride the session cookie
  instead of the JWT API pipeline.
  """
  import Plug.Conn
  alias RevenueApi.Accounts

  def init(roles), do: roles

  def call(conn, allowed_roles) do
    user = get_session(conn, :user_id) && Accounts.get_active_user(get_session(conn, :user_id))

    if user && user.role in allowed_roles do
      assign(conn, :current_user, user)
    else
      conn
      |> Phoenix.Controller.redirect(to: "/login")
      |> halt()
    end
  end
end
