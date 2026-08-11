defmodule RevenueApi.Repo.Migrations.CreateReceipts do
  use Ecto.Migration

  def change do
    create table(:receipts) do
      add :payment_id, references(:payments, on_delete: :restrict), null: false
      add :pdf_url, :string
      add :qr_payload, :string, null: false
      add :verification_url, :string, null: false
      add :signed_hash, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:receipts, [:payment_id])
    create unique_index(:receipts, [:qr_payload])
  end
end
