defmodule RevenueApiWeb.PaymentController do
  use RevenueApiWeb, :controller

  alias RevenueApi.{Payments, Authz}

  action_fallback RevenueApiWeb.FallbackController

  def create(conn, params) do
    with {:ok, payment} <- Payments.create(params, current_user(conn), request_context(conn)) do
      conn |> put_status(:created) |> render(:show, payment: payment)
    end
  end

  def show(conn, %{"id" => id}) do
    with %{} = payment <- Payments.get_payment(id) || {:error, :not_found},
         :ok <- Authz.authorize_lga(current_user(conn), payment.seller.lga_id) do
      render(conn, :show, payment: payment)
    end
  end
end
