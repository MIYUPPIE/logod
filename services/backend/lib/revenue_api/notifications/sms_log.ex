defmodule RevenueApi.Notifications.SmsLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sms_logs" do
    field :phone, :string
    field :message, :string
    field :status, :string
    field :provider_ref, :string
    field :sent_at, :utc_datetime

    belongs_to :payment, RevenueApi.Payments.Payment

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:payment_id, :phone, :message, :status, :provider_ref, :sent_at])
    |> validate_required([:payment_id, :phone, :message, :status])
    |> foreign_key_constraint(:payment_id)
  end
end
