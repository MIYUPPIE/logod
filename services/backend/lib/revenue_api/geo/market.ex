defmodule RevenueApi.Geo.Market do
  use Ecto.Schema
  import Ecto.Changeset

  schema "markets" do
    field :name, :string

    belongs_to :ward, RevenueApi.Geo.Ward

    timestamps(type: :utc_datetime)
  end

  def changeset(market, attrs) do
    market
    |> cast(attrs, [:name, :ward_id])
    |> validate_required([:name, :ward_id])
    |> foreign_key_constraint(:ward_id)
    |> unique_constraint([:ward_id, :name])
  end
end
