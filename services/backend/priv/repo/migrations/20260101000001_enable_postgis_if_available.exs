defmodule RevenueApi.Repo.Migrations.EnablePostgisIfAvailable do
  use Ecto.Migration

  @moduledoc """
  Enables PostGIS from day one per SRS §3 ("even if unused, avoids a painful
  migration later"). No MVP table uses PostGIS types yet (lat/lng are plain
  floats), so this is guarded to skip silently on hosts where the postgis
  extension package isn't installed, instead of failing every migration.
  """

  def up do
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'postgis') THEN
        CREATE EXTENSION IF NOT EXISTS postgis;
      END IF;
    END
    $$;
    """
  end

  def down do
    execute "DROP EXTENSION IF EXISTS postgis"
  end
end
