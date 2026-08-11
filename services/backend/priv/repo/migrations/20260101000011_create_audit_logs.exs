defmodule RevenueApi.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :nilify_all)
      add :action, :string, null: false
      add :entity_type, :string, null: false
      add :entity_id, :string
      add :ip, :string
      add :device_id, :string
      add :gps, :map
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime, updated_at: false, inserted_at: :inserted_at)
    end

    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:entity_type, :entity_id])
    create index(:audit_logs, [:action])
    create index(:audit_logs, [:inserted_at])
  end
end
