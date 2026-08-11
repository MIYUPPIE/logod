defmodule RevenueApiWeb.ReportController do
  use RevenueApiWeb, :controller

  alias RevenueApi.Reports

  def revenue(conn, %{"from" => from_str, "to" => to_str} = params) do
    with {:ok, from} <- parse_date_start(from_str),
         {:ok, to} <- parse_date_end(to_str) do
      payments = Reports.revenue(current_user(conn), from, to)

      case params["format"] do
        "csv" ->
          conn
          |> put_resp_content_type("text/csv")
          |> put_resp_header("content-disposition", ~s(attachment; filename="revenue.csv"))
          |> send_resp(200, Reports.to_csv(payments))

        _ ->
          json(conn, RevenueApiWeb.PaymentJSON.index(%{payments: payments}))
      end
    else
      :error -> conn |> put_status(:bad_request) |> json(%{errors: %{detail: "invalid_date"}})
    end
  end

  defp parse_date_start(date_str) do
    with {:ok, date} <- Date.from_iso8601(date_str) do
      {:ok, DateTime.new!(date, ~T[00:00:00], "Etc/UTC")}
    end
  end

  defp parse_date_end(date_str) do
    with {:ok, date} <- Date.from_iso8601(date_str) do
      {:ok, DateTime.new!(date, ~T[23:59:59], "Etc/UTC")}
    end
  end
end
