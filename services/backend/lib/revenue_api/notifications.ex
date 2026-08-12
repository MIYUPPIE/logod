defmodule RevenueApi.Notifications do
  @moduledoc "Sends the payment-confirmation SMS and logs the outcome regardless of success."

  alias RevenueApi.Repo
  alias RevenueApi.Notifications.SmsLog
  alias RevenueApi.Payments.Payment

  @doc """
  Never silently drops a failed send (SRS §5 design note): whatever
  happens, a `sms_logs` row is written with the outcome.
  """
  def send_payment_confirmation(%Payment{} = payment) do
    payment = Repo.preload(payment, :seller)
    message = build_message(payment)

    case RevenueApi.Notifier.send_sms(payment.seller.phone, message) do
      {:ok, provider_ref} ->
        {:ok, _log} = log(payment, message, "sent", provider_ref)
        {:ok, provider_ref}

      {:error, reason} ->
        {:ok, _log} = log(payment, message, "failed", nil)
        {:error, reason}
    end
  end

  defp log(payment, message, status, provider_ref) do
    sent_at = if status == "sent", do: DateTime.utc_now() |> DateTime.truncate(:second)

    %SmsLog{}
    |> SmsLog.changeset(%{
      payment_id: payment.id,
      phone: payment.seller.phone,
      message: message,
      status: status,
      provider_ref: provider_ref,
      sent_at: sent_at
    })
    |> Repo.insert()
  end

  defp build_message(%Payment{} = payment) do
    "Payment received. Seller: #{payment.seller.seller_uid}. " <>
      "Amount: NGN#{payment.amount}. Receipt: #{payment.receipt_no}. " <>
      "Date: #{Date.to_iso8601(DateTime.to_date(payment.paid_at))}."
  end
end
