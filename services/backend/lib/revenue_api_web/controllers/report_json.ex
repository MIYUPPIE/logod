defmodule RevenueApiWeb.ReportJSON do
  @moduledoc """
  Enriched revenue report rows - the plain PaymentJSON view only carries
  seller_id/levy_type_id (fine for the payment CRUD endpoints, useless for
  a report a human or a mobile reports screen has to read), so this mirrors
  Reports.to_csv/1's column set instead of reusing PaymentJSON. Reports.revenue/3
  already preloads :seller/:levy_type/:agent, so this is free.
  """
  alias RevenueApi.Payments.Payment

  def index(%{payments: payments}), do: Enum.map(payments, &data/1)

  defp data(%Payment{} = payment) do
    %{
      id: payment.id,
      receipt_no: payment.receipt_no,
      seller_uid: payment.seller.seller_uid,
      business_name: payment.seller.business_name,
      levy_type_name: payment.levy_type.name,
      amount: payment.amount,
      method: payment.method,
      agent_name: payment.agent.name,
      paid_at: payment.paid_at
    }
  end
end
