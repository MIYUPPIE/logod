defmodule RevenueApiWeb.PaymentController do
  use RevenueApiWeb, :controller

  alias RevenueApi.Payments

  action_fallback RevenueApiWeb.FallbackController

  def create(conn, params) do
    with {:ok, payment} <- Payments.create(params, current_user(conn), request_context(conn)) do
      conn |> put_status(:created) |> render(:show, payment: payment)
    end
  end

  def show(conn, %{"id" => id}) do
    case Payments.get_payment(id) do
      nil -> {:error, :not_found}
      payment -> render(conn, :show, payment: payment)
    end
  end
end
