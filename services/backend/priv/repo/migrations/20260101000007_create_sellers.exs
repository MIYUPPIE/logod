defmodule RevenueApi.Repo.Migrations.CreateSellers do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE gender AS ENUM ('male', 'female', 'other')", "DROP TYPE gender"

    create table(:sellers) do
      add :client_uuid, :uuid, null: false
      add :seller_uid, :string

      add :full_name, :string, null: false
      add :photo_url, :string
      add :phone, :string, null: false
      add :nin, :string
      add :dob, :date, null: false
      add :gender, :gender, null: false
      add :home_address, :string

      add :business_name, :string, null: false
      add :business_category, :string, null: false
      add :shop_number, :string

      add :market_id, references(:markets, on_delete: :restrict), null: false
      add :ward_id, references(:wards, on_delete: :restrict), null: false
      add :lga_id, references(:lgas, on_delete: :restrict), null: false
      add :state_id, references(:states, on_delete: :restrict), null: false

      add :lat, :float, null: false
      add :lng, :float, null: false
      add :gps_accuracy, :float
      add :gps_captured_at, :utc_datetime

      add :registered_by_user_id, references(:users, on_delete: :restrict), null: false
      add :qr_payload, :string
      add :duplicate_suspected, :boolean, null: false, default: false
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sellers, [:client_uuid])
    create unique_index(:sellers, [:seller_uid], where: "seller_uid IS NOT NULL")
    create index(:sellers, [:lga_id])
    create index(:sellers, [:phone])
    create index(:sellers, [:business_name])
    create index(:sellers, [:registered_by_user_id])
    create index(:sellers, [:duplicate_suspected], where: "duplicate_suspected = true")
  end
end
