defmodule RevenueApiWeb.ReportControllerTest do
  use RevenueApiWeb.ConnCase, async: true

  import RevenueApi.Factory

  describe "GET /api/v1/reports/revenue" do
    test "JSON format returns enriched rows, not raw seller/levy_type ids", %{conn: conn} do
      payment = insert(:payment)
      admin = insert(:admin)

      today = Date.utc_today() |> Date.to_iso8601()

      conn =
        conn
        |> authed(admin)
        |> get(~p"/api/v1/reports/revenue?from=#{today}&to=#{today}")

      [row] = json_response(conn, 200)
      assert row["receipt_no"] == payment.receipt_no
      assert row["business_name"]
      assert row["levy_type_name"]
      assert row["agent_name"]
      refute Map.has_key?(row, "seller_id")
      refute Map.has_key?(row, "levy_type_id")
    end

    test "CSV format returns a csv body", %{conn: conn} do
      insert(:payment)
      admin = insert(:admin)
      today = Date.utc_today() |> Date.to_iso8601()

      conn =
        conn
        |> authed(admin)
        |> get(~p"/api/v1/reports/revenue?from=#{today}&to=#{today}&format=csv")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "text/csv"
      assert conn.resp_body =~ "receipt_no"
    end

    test "an agent cannot access reports", %{conn: conn} do
      agent = insert(:agent)
      today = Date.utc_today() |> Date.to_iso8601()

      conn = conn |> authed(agent) |> get(~p"/api/v1/reports/revenue?from=#{today}&to=#{today}")
      assert json_response(conn, 403)
    end

    test "rejects an invalid date", %{conn: conn} do
      admin = insert(:admin)

      conn =
        conn |> authed(admin) |> get(~p"/api/v1/reports/revenue?from=not-a-date&to=2026-01-01")

      assert json_response(conn, 400)
    end
  end
end
