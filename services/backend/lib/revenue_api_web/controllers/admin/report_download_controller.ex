defmodule RevenueApiWeb.Admin.ReportDownloadController do
  @moduledoc "CSV download for the browser admin panel (session auth, not JWT — see RequireWebRole)."
  use RevenueApiWeb, :controller

  alias RevenueApi.Reports

  def revenue(conn, %{"from" => from_str, "to" => to_str}) do
    with {:ok, from_date} <- Date.from_iso8601(from_str),
         {:ok, to_date} <- Date.from_iso8601(to_str) do
      from = DateTime.new!(from_date, ~T[00:00:00], "Etc/UTC")
      to = DateTime.new!(to_date, ~T[23:59:59], "Etc/UTC")
      payments = Reports.revenue(conn.assigns.current_user, from, to)

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", ~s(attachment; filename="revenue.csv"))
      |> send_resp(200, Reports.to_csv(payments))
    else
      :error -> conn |> put_status(:bad_request) |> text("invalid date")
    end
  end
end
