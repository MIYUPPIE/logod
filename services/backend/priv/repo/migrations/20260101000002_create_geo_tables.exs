defmodule RevenueApi.Repo.Migrations.CreateGeoTables do
  use Ecto.Migration

  def change do
    create table(:states) do
      add :name, :string, null: false
      add :code, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:states, [:code])
    create unique_index(:states, [:name])

    create table(:lgas) do
      add :state_id, references(:states, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :code, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:lgas, [:state_id, :code])
    create index(:lgas, [:state_id])

    create table(:wards) do
      add :lga_id, references(:lgas, on_delete: :restrict), null: false
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:wards, [:lga_id])
    create unique_index(:wards, [:lga_id, :name])

    create table(:markets) do
      add :ward_id, references(:wards, on_delete: :restrict), null: false
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:markets, [:ward_id])
    create unique_index(:markets, [:ward_id, :name])
  end
end
