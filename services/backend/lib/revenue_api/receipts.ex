defmodule RevenueApi.Receipts do
  @moduledoc """
  Receipt creation, PDF rendering, and public tamper-evident verification.
  SRS §2 explicitly keeps a *signed hash* in MVP scope while deferring
  cryptographic tamper-proofing "beyond" that — this module is that line.
  """

  import Ecto.Query
  alias RevenueApi.Repo
  alias RevenueApi.Receipts.Receipt
  alias RevenueApi.Payments.Payment

  def get_by_payment_id(payment_id), do: Repo.get_by(Receipt, payment_id: payment_id)

  def get_by_qr_payload(qr_payload) do
    Repo.one(from r in Receipt, where: r.qr_payload == ^qr_payload)
  end

  @doc "Idempotent: a payment can only ever have one receipt (unique_constraint on payment_id)."
  def create_for_payment(%Payment{} = payment) do
    case get_by_payment_id(payment.id) do
      %Receipt{} = existing ->
        {:ok, existing}

      nil ->
        verification_url = verification_url(payment.receipt_no)
        hash = sign(payment)

        %Receipt{}
        |> Receipt.changeset(%{
          payment_id: payment.id,
          qr_payload: payment.receipt_no,
          verification_url: verification_url,
          signed_hash: hash
        })
        |> Repo.insert()
    end
  end

  def put_pdf_url(%Receipt{} = receipt, pdf_url) do
    receipt |> Receipt.put_pdf_url(pdf_url) |> Repo.update()
  end

  @doc """
  Recomputes the signed hash from the payment's current DB fields and
  compares it to what was stored at receipt-creation time. A mismatch
  means the underlying payment row was altered after the receipt was
  issued (e.g. a direct DB edit bypassing the app), which is exactly the
  tampering this hash exists to catch.
  """
  def verify(qr_payload) do
    with %Receipt{} = receipt <- get_by_qr_payload(qr_payload),
         %Payment{} = payment <- Repo.get(Payment, receipt.payment_id) |> Repo.preload([:seller, :levy_type]) do
      valid? = sign(payment) == receipt.signed_hash

      {:ok,
       %{
         valid: valid?,
         receipt_no: payment.receipt_no,
         amount: payment.amount,
         business_name: payment.seller.business_name,
         levy_type_name: payment.levy_type.name,
         paid_at: payment.paid_at
       }}
    else
      _ -> {:error, :not_found}
    end
  end

  defp sign(%Payment{} = payment) do
    key = Application.fetch_env!(:revenue_api, :receipt_signing_key)

    payload =
      Enum.join(
        [
          payment.receipt_no,
          payment.seller_id,
          Decimal.to_string(payment.amount),
          DateTime.to_iso8601(payment.paid_at)
        ],
        "|"
      )

    :crypto.mac(:hmac, :sha256, key, payload) |> Base.encode16(case: :lower)
  end

  defp verification_url(receipt_no) do
    base = RevenueApiWeb.Endpoint.url()
    "#{base}/api/v1/verify/#{receipt_no}"
  end
end
