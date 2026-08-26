defmodule RevenueApiWeb.Admin.LevyTypeControllerTest do
  use RevenueApiWeb.ConnCase, async: true

  import RevenueApi.Factory

  describe "POST /api/v1/admin/levy-types" do
    test "an admin can create a levy type", %{conn: conn} do
      admin = insert(:admin)
      lga = insert(:lga)

      attrs = %{lga_id: lga.id, name: "Daily Trading Levy", amount: "500.00", frequency: "daily"}
      conn = conn |> authed(admin) |> post(~p"/api/v1/admin/levy-types", attrs)

      body = json_response(conn, 201)
      assert body["name"] == "Daily Trading Levy"
      assert body["lga_id"] == lga.id
    end

    test "an agent cannot create a levy type", %{conn: conn} do
      agent = insert(:agent)
      lga = insert(:lga)

      attrs = %{lga_id: lga.id, name: "Daily Trading Levy", amount: "500.00", frequency: "daily"}
      conn = conn |> authed(agent) |> post(~p"/api/v1/admin/levy-types", attrs)

      assert json_response(conn, 403)
    end

    test "rejects a non-positive amount", %{conn: conn} do
      admin = insert(:admin)
      lga = insert(:lga)

      attrs = %{lga_id: lga.id, name: "Bad Levy", amount: "0.00", frequency: "daily"}
      conn = conn |> authed(admin) |> post(~p"/api/v1/admin/levy-types", attrs)

      assert json_response(conn, 422)
    end
  end

  describe "PATCH /api/v1/admin/levy-types/:id" do
    test "an admin can update the amount", %{conn: conn} do
      admin = insert(:admin)
      levy_type = insert(:levy_type, amount: Decimal.new("500.00"))

      conn =
        conn
        |> authed(admin)
        |> patch(~p"/api/v1/admin/levy-types/#{levy_type.id}", %{amount: "750.00"})

      body = json_response(conn, 200)
      assert body["amount"] == "750.00"
    end
  end
end
