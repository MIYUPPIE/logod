defmodule RevenueApiWeb.VerifyController do
  use RevenueApiWeb, :controller

  alias RevenueApi.{Receipts, RateLimiter}

  def show(conn, %{"receipt_qr_payload" => qr_payload}) do
    ip = conn.remote_ip |> format_ip()

    case RateLimiter.check_verify(ip) do
      {:allow, _count} ->
        case Receipts.verify(qr_payload) do
          {:ok, result} -> json(conn, result)
          {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{errors: %{detail: "not_found"}})
        end

      {:deny, _} ->
        conn |> put_status(:too_many_requests) |> json(%{errors: %{detail: "rate_limited"}})
    end
  end

  defp format_ip(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()
  defp format_ip(_), do: nil
end
