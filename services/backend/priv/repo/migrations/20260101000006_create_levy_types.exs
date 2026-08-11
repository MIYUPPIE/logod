defmodule RevenueApi.Repo.Migrations.CreateLevyTypes do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE levy_frequency AS ENUM ('daily', 'weekly', 'monthly', 'one_off')",
            "DROP TYPE levy_frequency"

    create table(:levy_types) do
      add :lga_id, references(:lgas, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :amount, :decimal, null: false
      add :frequency, :levy_frequency, null: false
      add :active, :boolean, null: false, default: true
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:levy_types, [:lga_id])
    create unique_index(:levy_types, [:lga_id, :name], where: "deleted_at IS NULL")
  end
end
