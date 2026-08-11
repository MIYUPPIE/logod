defmodule RevenueApiWeb.SessionController do
  use RevenueApiWeb, :controller

  alias RevenueApi.Accounts

  def new(conn, _params) do
    render(conn, :new, error: nil)
  end

  def create(conn, %{"identifier" => identifier, "password" => password}) do
    request_context = %{ip: format_ip(conn.remote_ip), device_id: nil, gps: nil}

    with {:allow, _count} <- RevenueApi.RateLimiter.check_login(identifier, request_context.ip),
         {:ok, user} <- Accounts.authenticate_user(identifier, password, request_context),
         true <- user.role in [:admin, :supervisor] do
      conn
      |> put_session(:user_id, user.id)
      |> configure_session(renew: true)
      |> redirect(to: ~p"/dashboard")
    else
      _ -> render(conn, :new, error: "Invalid credentials or insufficient access")
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/login")
  end

  defp format_ip(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()
  defp format_ip(_), do: nil
end
