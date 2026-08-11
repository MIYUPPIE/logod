defmodule RevenueApi.Repo.Migrations.CreateSequences do
  use Ecto.Migration

  @moduledoc """
  Generic named counter table. Used via an atomic upsert (INSERT ... ON
  CONFLICT DO UPDATE ... RETURNING) to hand out gapless, race-safe sequence
  numbers scoped by an arbitrary key (e.g. "seller_uid:LAG:IKJ:2026"),
  instead of creating a native Postgres SEQUENCE per LGA/year at runtime.
  """

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext"

    create table(:sequences, primary_key: false) do
      add :key, :string, primary_key: true
      add :value, :bigint, null: false, default: 0

      timestamps(type: :utc_datetime)
    end
  end
end
