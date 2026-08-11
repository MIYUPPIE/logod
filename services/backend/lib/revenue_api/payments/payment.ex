defmodule RevenueApi.Payments.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @methods [:cash, :pos, :transfer]
  @statuses [:pending_sync, :synced, :flagged, :duplicate_suspected]

  schema "payments" do
    field :client_uuid, Ecto.UUID
    field :amount, :decimal
    field :method, Ecto.Enum, values: @methods
    field :receipt_no, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending_sync
    field :flag_reason, :string
    field :paid_at, :utc_datetime
    field :synced_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :seller, RevenueApi.Sellers.Seller
    belongs_to :levy_type, RevenueApi.Levies.LevyType
    belongs_to :agent, RevenueApi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def methods, do: @methods

  @required [:client_uuid, :seller_id, :levy_type_id, :amount, :method, :agent_id, :paid_at]
  @optional [:receipt_no, :status, :flag_reason, :synced_at]

  def changeset(payment, attrs) do
    payment
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:method, @methods)
    |> validate_number(:amount, greater_than: 0)
    |> unique_constraint(:client_uuid)
    |> unique_constraint(:receipt_no)
    |> foreign_key_constraint(:seller_id)
    |> foreign_key_constraint(:levy_type_id)
    |> foreign_key_constraint(:agent_id)
  end
end
