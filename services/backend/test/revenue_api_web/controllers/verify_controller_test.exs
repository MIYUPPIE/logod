defmodule RevenueApiWeb.VerifyControllerTest do
  use RevenueApiWeb.ConnCase, async: true

  import RevenueApi.Factory

  alias RevenueApi.Receipts

  test "GET /api/v1/verify/:qr requires no authentication and returns only non-sensitive fields",
       %{conn: conn} do
    payment = insert(:payment)
    {:ok, _receipt} = Receipts.create_for_payment(payment)

    conn = get(conn, ~p"/api/v1/verify/#{payment.receipt_no}")
    body = json_response(conn, 200)

    assert body["valid"] == true
    assert body["receipt_no"] == payment.receipt_no
    refute Map.has_key?(body, "seller_id")
    refute Map.has_key?(body, "phone")
    refute Map.has_key?(body, "nin")
  end

  test "returns 404 for an unknown receipt code", %{conn: conn} do
    conn = get(conn, ~p"/api/v1/verify/RCT-NOPE-0000")
    assert json_response(conn, 404)
  end

  test "is rate-limited", %{conn: _conn} do
    # A dedicated simulated IP so this test's bucket doesn't collide with
    # the shared 127.0.0.1 default used by sibling tests in this file.
    responses =
      for _ <- 1..35 do
        %{build_conn() | remote_ip: {203, 0, 113, 42}}
        |> get(~p"/api/v1/verify/RCT-SCRAPE-TEST")
        |> Map.get(:status)
      end

    assert 429 in responses
  end
end
