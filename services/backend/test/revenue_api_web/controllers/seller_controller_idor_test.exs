defmodule RevenueApiWeb.SellerControllerIdorTest do
  @moduledoc """
  Regression tests for a real IDOR found in a security review pass: read
  endpoints had no LGA-scoping even though the write endpoints did, so any
  authenticated agent could read another LGA's seller PII (phone, NIN,
  DOB, GPS, photo) just by knowing/guessing an id. See RevenueApi.Authz.
  """
  use RevenueApiWeb.ConnCase, async: true

  import RevenueApi.Factory

  setup do
    other_seller = insert(:seller)
    agent = insert(:agent)
    %{other_seller: other_seller, agent: agent}
  end

  test "an agent cannot GET another LGA's seller by id", %{
    conn: conn,
    other_seller: seller,
    agent: agent
  } do
    conn = conn |> authed(agent) |> get(~p"/api/v1/sellers/#{seller.id}")
    assert json_response(conn, 403)
  end

  test "an agent cannot GET another LGA's seller by QR/seller_uid", %{conn: conn, agent: agent} do
    other_seller = insert(:seller, seller_uid: "OTH-LGA-2026-000001")
    conn = conn |> authed(agent) |> get(~p"/api/v1/sellers/qr/#{other_seller.seller_uid}")
    assert json_response(conn, 403)
  end

  test "an agent cannot GET another LGA's seller's payment history", %{
    conn: conn,
    other_seller: seller,
    agent: agent
  } do
    conn = conn |> authed(agent) |> get(~p"/api/v1/sellers/#{seller.id}/payments")
    assert json_response(conn, 403)
  end

  test "search only returns results from the agent's own LGA", %{
    conn: conn,
    other_seller: seller,
    agent: agent
  } do
    conn = conn |> authed(agent) |> get(~p"/api/v1/sellers/search?q=#{seller.phone}")
    assert json_response(conn, 200) == []
  end

  test "a payment's owning agent can view it, but a different agent cannot", %{conn: conn} do
    payment = insert(:payment)
    other_agent = insert(:agent)

    conn = conn |> authed(other_agent) |> get(~p"/api/v1/payments/#{payment.id}")
    assert json_response(conn, 403)
  end

  test "an admin (lga_id nil) can read across LGAs", %{conn: conn, other_seller: seller} do
    admin = insert(:admin)
    conn = conn |> authed(admin) |> get(~p"/api/v1/sellers/#{seller.id}")
    assert json_response(conn, 200)["id"] == seller.id
  end
end
