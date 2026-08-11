defmodule RevenueApi.Repo.Migrations.CreateSmsLogs do
  use Ecto.Migration

  def change do
    create table(:sms_logs) do
      add :payment_id, references(:payments, on_delete: :restrict), null: false
      add :phone, :string, null: false
      add :message, :text, null: false
      add :status, :string, null: false
      add :provider_ref, :string
      add :sent_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:sms_logs, [:payment_id])
    create index(:sms_logs, [:status])
  end
end
