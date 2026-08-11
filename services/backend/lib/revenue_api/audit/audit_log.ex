defmodule RevenueApi.Audit.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "audit_logs" do
    field :action, :string
    field :entity_type, :string
    field :entity_id, :string
    field :ip, :string
    field :device_id, :string
    field :gps, :map
    field :metadata, :map, default: %{}

    belongs_to :user, RevenueApi.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :user_id,
      :action,
      :entity_type,
      :entity_id,
      :ip,
      :device_id,
      :gps,
      :metadata
    ])
    |> validate_required([:action, :entity_type])
  end
end
