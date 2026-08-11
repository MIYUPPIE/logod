defmodule RevenueApi.Sequences do
  @moduledoc """
  Race-safe, gapless-per-key counters backed by an atomic upsert against the
  `sequences` table. Two concurrent agents syncing in the same LGA/year can
  never receive the same `next/1` value for the same key, because the
  increment happens in a single `INSERT ... ON CONFLICT DO UPDATE ...
  RETURNING` round trip rather than a read-then-write.
  """

  alias RevenueApi.Repo

  @spec next(String.t()) :: pos_integer()
  def next(key) when is_binary(key) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, %{rows: [[value]]}} =
      Repo.query(
        """
        INSERT INTO sequences (key, value, inserted_at, updated_at)
        VALUES ($1, 1, $2, $2)
        ON CONFLICT (key) DO UPDATE SET value = sequences.value + 1, updated_at = $2
        RETURNING value
        """,
        [key, now]
      )

    value
  end
end
