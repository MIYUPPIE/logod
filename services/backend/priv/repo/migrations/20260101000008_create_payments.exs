defmodule RevenueApi.Repo.Migrations.CreatePayments do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE payment_method AS ENUM ('cash', 'pos', 'transfer')",
            "DROP TYPE payment_method"

    execute """
            CREATE TYPE payment_status AS ENUM
              ('pending_sync', 'synced', 'flagged', 'duplicate_suspected')
            """,
            "DROP TYPE payment_status"

    create table(:payments) do
      add :client_uuid, :uuid, null: false
      add :seller_id, references(:sellers, on_delete: :restrict), null: false
      add :levy_type_id, references(:levy_types, on_delete: :restrict), null: false
      add :amount, :decimal, null: false
      add :method, :payment_method, null: false
      add :agent_id, references(:users, on_delete: :restrict), null: false
      add :receipt_no, :string
      add :status, :payment_status, null: false, default: "pending_sync"
      add :flag_reason, :string
      add :paid_at, :utc_datetime, null: false
      add :synced_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:payments, [:client_uuid])
    create unique_index(:payments, [:receipt_no], where: "receipt_no IS NOT NULL")
    create index(:payments, [:seller_id])
    create index(:payments, [:agent_id])
    create index(:payments, [:status])
    create index(:payments, [:paid_at])
  end
end
