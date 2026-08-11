defmodule RevenueApi.Geo.State do
  use Ecto.Schema
  import Ecto.Changeset

  schema "states" do
    field :name, :string
    field :code, :string

    has_many :lgas, RevenueApi.Geo.Lga

    timestamps(type: :utc_datetime)
  end

  def changeset(state, attrs) do
    state
    |> cast(attrs, [:name, :code])
    |> validate_required([:name, :code])
    |> unique_constraint(:code)
    |> unique_constraint(:name)
  end
end
