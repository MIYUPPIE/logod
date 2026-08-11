defmodule RevenueApi.Geo.Ward do
  use Ecto.Schema
  import Ecto.Changeset

  schema "wards" do
    field :name, :string

    belongs_to :lga, RevenueApi.Geo.Lga
    has_many :markets, RevenueApi.Geo.Market

    timestamps(type: :utc_datetime)
  end

  def changeset(ward, attrs) do
    ward
    |> cast(attrs, [:name, :lga_id])
    |> validate_required([:name, :lga_id])
    |> foreign_key_constraint(:lga_id)
    |> unique_constraint([:lga_id, :name])
  end
end
