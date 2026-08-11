defmodule RevenueApiWeb.Plugs.RequestContext do
  @moduledoc """
  Builds the who/where half of every audit_logs row from the connection:
  IP, agent device ID, and (if the agent sent it) GPS. Assigned once so
  every controller/context call downstream shares the same context instead
  of each one re-deriving it.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    assign(conn, :request_context, %{
      ip: format_ip(conn.remote_ip),
      device_id: get_req_header(conn, "x-device-id") |> List.first(),
      gps: parse_gps(get_req_header(conn, "x-gps") |> List.first())
    })
  end

  defp format_ip(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()
  defp format_ip(_), do: nil

  defp parse_gps(nil), do: nil

  defp parse_gps(header) do
    case Jason.decode(header) do
      {:ok, %{"lat" => _lat, "lng" => _lng} = gps} -> gps
      _ -> nil
    end
  end
end
