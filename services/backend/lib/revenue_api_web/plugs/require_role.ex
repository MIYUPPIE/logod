defmodule RevenueApiWeb.Plugs.RequireRole do
  @moduledoc """
  Role check as a plug, not scattered in controllers (per SRS §5). Usage:

      plug RevenueApiWeb.Plugs.RequireRole, [:admin, :supervisor]
  """
  import Plug.Conn

  def init(roles), do: roles

  def call(conn, allowed_roles) do
    user = Guardian.Plug.current_resource(conn)

    if user && user.role in allowed_roles do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{errors: %{detail: "forbidden"}})
      |> halt()
    end
  end
end
