defmodule RevenueApi.Workers.ProcessPaymentWorker do
  @moduledoc """
  Post-payment side effects, off the request path: create the receipt
  record, render + store the PDF, send the confirmation SMS. Retries with
  Oban's default backoff on failure; a failed SMS still leaves a `sms_logs`
  row (written by Notifications.send_payment_confirmation itself) so
  nothing is silently dropped even if this job eventually gives up.
  """

  use Oban.Worker, queue: :sms, max_attempts: 5

  alias RevenueApi.{Payments, Receipts, ReceiptPdf, Storage, Notifications}
  alias RevenueApi.Receipts.Receipt

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"payment_id" => payment_id}}) do
    payment = Payments.get_payment!(payment_id)
    {:ok, receipt} = Receipts.create_for_payment(payment)
    _receipt = ensure_pdf(payment, receipt)

    case Notifications.send_payment_confirmation(payment) do
      {:ok, _log} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_pdf(_payment, %Receipt{pdf_url: pdf_url} = receipt) when not is_nil(pdf_url) do
    receipt
  end

  defp ensure_pdf(payment, receipt) do
    with {:ok, pdf_binary} <- ReceiptPdf.render(payment, receipt),
         key <- "receipts/#{receipt.id}.pdf",
         {:ok, ^key} <- Storage.store(key, pdf_binary, "application/pdf"),
         {:ok, updated} <- Receipts.put_pdf_url(receipt, key) do
      updated
    else
      _ -> receipt
    end
  end
end
