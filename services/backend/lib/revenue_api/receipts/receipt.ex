defmodule RevenueApi.Receipts.Receipt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "receipts" do
    field :pdf_url, :string
    field :qr_payload, :string
    field :verification_url, :string
    field :signed_hash, :string

    belongs_to :payment, RevenueApi.Payments.Payment

    timestamps(type: :utc_datetime)
  end

  def changeset(receipt, attrs) do
    receipt
    |> cast(attrs, [:payment_id, :pdf_url, :qr_payload, :verification_url, :signed_hash])
    |> validate_required([:payment_id, :qr_payload, :verification_url, :signed_hash])
    |> unique_constraint(:payment_id)
    |> unique_constraint(:qr_payload)
    |> foreign_key_constraint(:payment_id)
  end

  def put_pdf_url(receipt, pdf_url), do: change(receipt, pdf_url: pdf_url)
end
