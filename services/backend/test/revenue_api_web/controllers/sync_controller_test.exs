defmodule RevenueApiWeb.SyncControllerTest do
  use RevenueApiWeb.ConnCase, async: true

  import RevenueApi.Factory

  test "POST /api/v1/sync/batch rejects a batch bigger than 200 records", %{conn: conn} do
    agent = insert(:agent)

    records =
      for _ <- 1..201, do: %{type: "seller", client_uuid: Ecto.UUID.generate(), payload: %{}}

    conn = conn |> authed(agent) |> post(~p"/api/v1/sync/batch", %{records: records})
    assert json_response(conn, 400)
  end

  test "POST /api/v1/sync/batch processes a small batch and returns per-record results", %{
    conn: conn
  } do
    market = insert(:market) |> RevenueApi.Repo.preload(ward: [lga: :state])
    agent = insert(:agent, lga_id: market.ward.lga_id)

    record = %{
      type: "seller",
      client_uuid: Ecto.UUID.generate(),
      payload: %{
        full_name: "Batch Seller",
        phone: "08055556666",
        dob: "1990-01-01",
        gender: "male",
        business_name: "Batch Biz",
        business_category: "Retail",
        market_id: market.id,
        ward_id: market.ward_id,
        lga_id: market.ward.lga_id,
        state_id: market.ward.lga.state_id,
        lat: 6.5,
        lng: 3.3
      }
    }

    conn = conn |> authed(agent) |> post(~p"/api/v1/sync/batch", %{records: [record]})
    assert %{"results" => [%{"status" => "synced"}]} = json_response(conn, 200)
  end

  test "requires authentication", %{conn: conn} do
    conn = post(conn, ~p"/api/v1/sync/batch", %{records: []})
    assert json_response(conn, 401)
  end
end
