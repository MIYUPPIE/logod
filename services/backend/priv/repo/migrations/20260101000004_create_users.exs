defmodule RevenueApi.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE user_role AS ENUM ('admin', 'supervisor', 'agent', 'seller')",
            "DROP TYPE user_role"

    create table(:users) do
      add :name, :string, null: false
      add :email, :citext
      add :phone, :string
      add :password_hash, :string, null: false
      add :role, :user_role, null: false
      add :lga_id, references(:lgas, on_delete: :nilify_all)
      add :device_id, :string
      add :active, :boolean, null: false, default: true
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email], where: "email IS NOT NULL")
    create unique_index(:users, [:phone], where: "phone IS NOT NULL")
    create index(:users, [:role])
    create index(:users, [:lga_id])
  end
end
