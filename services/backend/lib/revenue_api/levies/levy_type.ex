defmodule RevenueApi.Levies.LevyType do
  use Ecto.Schema
  import Ecto.Changeset

  @frequencies [:daily, :weekly, :monthly, :one_off]

  schema "levy_types" do
    field :name, :string
    field :amount, :decimal
    field :frequency, Ecto.Enum, values: @frequencies
    field :active, :boolean, default: true
    field :deleted_at, :utc_datetime

    belongs_to :lga, RevenueApi.Geo.Lga

    timestamps(type: :utc_datetime)
  end

  def frequencies, do: @frequencies

  def changeset(levy_type, attrs) do
    levy_type
    |> cast(attrs, [:name, :amount, :frequency, :lga_id, :active])
    |> validate_required([:name, :amount, :frequency, :lga_id])
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:frequency, @frequencies)
    |> foreign_key_constraint(:lga_id)
    |> unique_constraint([:lga_id, :name])
  end
end
