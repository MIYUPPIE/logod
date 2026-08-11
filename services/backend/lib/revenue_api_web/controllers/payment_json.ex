defmodule RevenueApiWeb.PaymentJSON do
  alias RevenueApi.Payments.Payment

  def show(%{payment: payment}), do: data(payment)
  def index(%{payments: payments}), do: Enum.map(payments, &data/1)

  def data(%Payment{} = payment) do
    %{
      id: payment.id,
      client_uuid: payment.client_uuid,
      seller_id: payment.seller_id,
      levy_type_id: payment.levy_type_id,
      amount: payment.amount,
      method: payment.method,
      agent_id: payment.agent_id,
      receipt_no: payment.receipt_no,
      status: payment.status,
      paid_at: payment.paid_at,
      synced_at: payment.synced_at
    }
  end
end
