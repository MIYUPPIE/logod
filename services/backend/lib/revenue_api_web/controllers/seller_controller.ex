defmodule RevenueApiWeb.SellerController do
  use RevenueApiWeb, :controller

  alias RevenueApi.{Sellers, Payments, Authz}

  action_fallback RevenueApiWeb.FallbackController

  def create(conn, params) do
    with {:ok, seller} <- Sellers.register(params, current_user(conn), request_context(conn)) do
      conn |> put_status(:created) |> render(:show, seller: seller)
    end
  end

  def show(conn, %{"id" => id}) do
    with %{} = seller <- Sellers.get_seller(id) || {:error, :not_found},
         :ok <- Authz.authorize_lga(current_user(conn), seller.lga_id) do
      render(conn, :show, seller: seller)
    end
  end

  def show_by_qr(conn, %{"seller_uid" => seller_uid}) do
    with %{} = seller <- Sellers.get_by_seller_uid(seller_uid) || {:error, :not_found},
         :ok <- Authz.authorize_lga(current_user(conn), seller.lga_id) do
      render(conn, :show, seller: seller)
    end
  end

  def search(conn, %{"q" => query}) do
    render(conn, :index, sellers: Sellers.search(query, current_user(conn)))
  end

  def payments(conn, %{"id" => id}) do
    with %{} = seller <- Sellers.get_seller(id) || {:error, :not_found},
         :ok <- Authz.authorize_lga(current_user(conn), seller.lga_id) do
      json(conn, RevenueApiWeb.PaymentJSON.index(%{payments: Payments.list_for_seller(id)}))
    end
  end
end
