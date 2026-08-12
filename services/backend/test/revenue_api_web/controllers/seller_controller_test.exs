defmodule RevenueApiWeb.SellerControllerTest do
  use RevenueApiWeb.ConnCase, async: true

  import RevenueApi.Factory

  setup do
    market = insert(:market) |> RevenueApi.Repo.preload(ward: [lga: :state])
    agent = insert(:agent, lga_id: market.ward.lga_id)
    %{market: market, agent: agent}
  end

  test "POST /api/v1/sellers registers a seller and returns 201", %{
    conn: conn,
    market: market,
    agent: agent
  } do
    attrs = %{
      client_uuid: Ecto.UUID.generate(),
      full_name: "Amaka Obi",
      phone: "08031112222",
      dob: "1985-04-12",
      gender: "female",
      business_name: "Amaka Store",
      business_category: "Retail",
      market_id: market.id,
      ward_id: market.ward_id,
      lga_id: market.ward.lga_id,
      state_id: market.ward.lga.state_id,
      lat: 6.5,
      lng: 3.3
    }

    conn = conn |> authed(agent) |> post(~p"/api/v1/sellers", attrs)
    body = json_response(conn, 201)

    assert body["seller_uid"]
    refute Map.has_key?(body, "password_hash")
  end

  test "POST /api/v1/sellers rejects a seller with no client_uuid", %{
    conn: conn,
    market: market,
    agent: agent
  } do
    attrs = %{
      full_name: "No UUID",
      phone: "08039990000",
      dob: "1990-01-01",
      gender: "male",
      business_name: "No UUID Biz",
      business_category: "Retail",
      market_id: market.id,
      ward_id: market.ward_id,
      lga_id: market.ward.lga_id,
      state_id: market.ward.lga.state_id,
      lat: 6.5,
      lng: 3.3
    }

    conn = conn |> authed(agent) |> post(~p"/api/v1/sellers", attrs)
    assert json_response(conn, 422)
  end

  test "GET /api/v1/sellers/qr/:seller_uid finds a registered seller", %{
    conn: conn,
    market: market,
    agent: agent
  } do
    {:ok, seller} =
      RevenueApi.Sellers.register(
        %{
          "client_uuid" => Ecto.UUID.generate(),
          "full_name" => "QR Test",
          "phone" => "08033334444",
          "dob" => "1990-01-01",
          "gender" => "male",
          "business_name" => "QR Biz",
          "business_category" => "Retail",
          "market_id" => market.id,
          "ward_id" => market.ward_id,
          "lga_id" => market.ward.lga_id,
          "state_id" => market.ward.lga.state_id,
          "lat" => 6.5,
          "lng" => 3.3
        },
        agent,
        %{}
      )

    conn = conn |> authed(agent) |> get(~p"/api/v1/sellers/qr/#{seller.seller_uid}")
    assert json_response(conn, 200)["id"] == seller.id
  end

  test "GET /api/v1/sellers/qr/:seller_uid returns 404 for unknown code", %{
    conn: conn,
    agent: agent
  } do
    conn = conn |> authed(agent) |> get(~p"/api/v1/sellers/qr/DOES-NOT-EXIST")
    assert json_response(conn, 404)
  end
end
