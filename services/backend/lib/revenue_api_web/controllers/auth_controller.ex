defmodule RevenueApiWeb.AuthController do
  use RevenueApiWeb, :controller

  alias RevenueApi.{Accounts, RateLimiter}

  def login(conn, %{"identifier" => identifier, "password" => password}) do
    ip = conn.assigns[:request_context][:ip] || format_ip(conn.remote_ip)

    with {:allow, _count} <- RateLimiter.check_login(identifier, ip),
         {:ok, user} <- Accounts.authenticate_user(identifier, password, %{ip: ip}),
         {:ok, tokens} <- Accounts.issue_tokens(user) do
      render(conn, :tokens, tokens: tokens)
    else
      {:deny, _} ->
        conn |> put_status(:too_many_requests) |> json(%{errors: %{detail: "rate_limited"}})

      {:error, :invalid_credentials} ->
        conn |> put_status(:unauthorized) |> json(%{errors: %{detail: "invalid_credentials"}})
    end
  end

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Accounts.refresh(refresh_token) do
      {:ok, tokens} ->
        render(conn, :tokens, tokens: tokens)

      {:error, :invalid_refresh_token} ->
        conn |> put_status(:unauthorized) |> json(%{errors: %{detail: "invalid_refresh_token"}})
    end
  end

  def logout(conn, %{"refresh_token" => refresh_token}) do
    :ok = Accounts.revoke_refresh_token(refresh_token)
    send_resp(conn, :no_content, "")
  end

  defp format_ip(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()
  defp format_ip(_), do: nil
end
