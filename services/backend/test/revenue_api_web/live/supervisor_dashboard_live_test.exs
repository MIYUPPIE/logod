defmodule RevenueApiWeb.SupervisorDashboardLiveTest do
  use RevenueApiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  import RevenueApi.Factory

  defp login(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end

  test "a supervisor can view the dashboard and sees today's totals", %{conn: conn} do
    payment = insert(:payment)
    seller = RevenueApi.Sellers.get_seller!(payment.seller_id)
    supervisor = insert(:supervisor, lga_id: seller.lga_id)

    conn = login(conn, supervisor)
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    assert html =~ "Supervisor Dashboard"
    assert html =~ Decimal.to_string(payment.amount)
  end

  test "an agent (wrong role) is redirected to /login instead of seeing the dashboard", %{
    conn: conn
  } do
    agent = insert(:agent)
    conn = login(conn, agent)

    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard")
  end

  test "an unauthenticated visitor is redirected to /login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard")
  end
end
