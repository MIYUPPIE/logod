defmodule RevenueApi.Geo.Lga do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lgas" do
    field :name, :string
    field :code, :string

    belongs_to :state, RevenueApi.Geo.State
    has_many :wards, RevenueApi.Geo.Ward

    timestamps(type: :utc_datetime)
  end

  def changeset(lga, attrs) do
    lga
    |> cast(attrs, [:name, :code, :state_id])
    |> validate_required([:name, :code, :state_id])
    |> foreign_key_constraint(:state_id)
    |> unique_constraint([:state_id, :code])
  end
end
