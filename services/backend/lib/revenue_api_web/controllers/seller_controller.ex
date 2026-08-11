defmodule RevenueApiWeb.SellerController do
  use RevenueApiWeb, :controller

  alias RevenueApi.{Sellers, Payments}

  action_fallback RevenueApiWeb.FallbackController

  def create(conn, params) do
    with {:ok, seller} <- Sellers.register(params, current_user(conn), request_context(conn)) do
      conn |> put_status(:created) |> render(:show, seller: seller)
    end
  end

  def show(conn, %{"id" => id}) do
    case Sellers.get_seller(id) do
      nil -> {:error, :not_found}
      seller -> render(conn, :show, seller: seller)
    end
  end

  def show_by_qr(conn, %{"seller_uid" => seller_uid}) do
    case Sellers.get_by_seller_uid(seller_uid) do
      nil -> {:error, :not_found}
      seller -> render(conn, :show, seller: seller)
    end
  end

  def search(conn, %{"q" => query}) do
    render(conn, :index, sellers: Sellers.search(query))
  end

  def payments(conn, %{"id" => id}) do
    json(conn, RevenueApiWeb.PaymentJSON.index(%{payments: Payments.list_for_seller(id)}))
  end
end
