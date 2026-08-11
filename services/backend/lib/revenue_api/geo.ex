defmodule RevenueApi.Geo do
  @moduledoc """
  States, LGAs, wards, markets — the administrative hierarchy sellers and
  levy types are scoped to.
  """

  import Ecto.Query
  alias RevenueApi.Repo
  alias RevenueApi.Geo.{State, Lga, Ward, Market}

  def list_states, do: Repo.all(from s in State, order_by: s.name)

  def list_lgas(state_id) do
    Repo.all(from l in Lga, where: l.state_id == ^state_id, order_by: l.name)
  end

  def list_wards(lga_id) do
    Repo.all(from w in Ward, where: w.lga_id == ^lga_id, order_by: w.name)
  end

  def list_markets(ward_id) do
    Repo.all(from m in Market, where: m.ward_id == ^ward_id, order_by: m.name)
  end

  def get_state!(id), do: Repo.get!(State, id)
  def get_lga!(id), do: Repo.get!(Lga, id)
  def get_ward!(id), do: Repo.get!(Ward, id)
  def get_market!(id), do: Repo.get!(Market, id)

  def create_state(attrs), do: %State{} |> State.changeset(attrs) |> Repo.insert()
  def create_lga(attrs), do: %Lga{} |> Lga.changeset(attrs) |> Repo.insert()
  def create_ward(attrs), do: %Ward{} |> Ward.changeset(attrs) |> Repo.insert()
  def create_market(attrs), do: %Market{} |> Market.changeset(attrs) |> Repo.insert()

  @doc """
  True when `market_id`/`ward_id`/`lga_id`/`state_id` actually form one
  consistent chain (market belongs to ward belongs to lga belongs to state).
  Used to reject a registration payload with a syntactically valid but
  mismatched geo hierarchy (e.g. a market from LGA A submitted with lga_id
  pointing at LGA B).
  """
  def consistent_hierarchy?(market_id, ward_id, lga_id, state_id) do
    Repo.exists?(
      from m in Market,
        join: w in Ward,
        on: w.id == m.ward_id,
        join: l in Lga,
        on: l.id == w.lga_id,
        join: s in State,
        on: s.id == l.state_id,
        where:
          m.id == ^market_id and w.id == ^ward_id and l.id == ^lga_id and s.id == ^state_id
    )
  end
end
