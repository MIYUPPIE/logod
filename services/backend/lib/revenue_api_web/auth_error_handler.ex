defmodule RevenueApiWeb.AuthErrorHandler do
  @moduledoc false
  @behaviour Guardian.Plug.ErrorHandler

  import Plug.Conn

  @impl true
  def auth_error(conn, {type, _reason}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{errors: %{detail: to_string(type)}})
    |> halt()
  end
end
