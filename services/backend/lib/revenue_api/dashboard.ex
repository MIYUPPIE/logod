defmodule RevenueApi.Dashboard do
  @moduledoc """
  Supervisor/admin live summary — SRS §2 "Live agent list, today's
  collections, pending sync queue, basic revenue totals." Scoped to the
  requesting user's LGA unless they're a state-level admin (lga_id nil).
  """

  import Ecto.Query
  alias RevenueApi.Repo
  alias RevenueApi.Payments.Payment
  alias RevenueApi.Accounts.User
  alias RevenueApi.Sellers.Seller

  def summary(actor) do
    today_start = Date.utc_today() |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    payments_scope = payments_scope(actor)

    today_payments =
      from p in Payment,
        where: p.paid_at >= ^today_start and is_nil(p.deleted_at),
        select: {p.amount, p.agent_id}

    today_payments =
      payments_scope
      |> apply_scope(today_payments, :agent_id)
      |> Repo.all()

    flagged = flagged(actor)

    %{
      today_total_amount: Enum.reduce(today_payments, Decimal.new(0), fn {a, _}, acc -> Decimal.add(acc, a) end),
      today_payment_count: length(today_payments),
      active_agents: active_agents(actor, today_payments),
      # The server only ever sees a record once it's synced, so it can't
      # count what's still queued on a disconnected device. What it *can*
      # show is the queue of already-synced records still awaiting
      # supervisor resolution (duplicate_suspected etc.) — that's this count.
      pending_sync_count: length(flagged),
      flagged: flagged
    }
  end

  defp payments_scope(%{role: :admin, lga_id: nil}), do: nil
  defp payments_scope(%{lga_id: lga_id}), do: lga_id

  defp apply_scope(nil, query, _field), do: query

  defp apply_scope(lga_id, query, _field) do
    from [p] in query,
      join: a in User,
      on: a.id == p.agent_id,
      where: a.lga_id == ^lga_id
  end

  defp active_agents(actor, today_payments) do
    totals = Enum.group_by(today_payments, fn {_a, agent_id} -> agent_id end, fn {a, _} -> a end)

    actor
    |> agents_query()
    |> Repo.all()
    |> Enum.map(fn agent ->
      total = Map.get(totals, agent.id, []) |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
      %{agent_id: agent.id, name: agent.name, last_seen_at: nil, today_total: total}
    end)
  end

  defp agents_query(%{role: :admin, lga_id: nil}) do
    from u in User, where: u.role == :agent and u.active == true and is_nil(u.deleted_at)
  end

  defp agents_query(%{lga_id: lga_id}) do
    from u in User,
      where:
        u.role == :agent and u.active == true and is_nil(u.deleted_at) and u.lga_id == ^lga_id
  end

  defp flagged(actor) do
    seller_scope = fn q ->
      case actor do
        %{role: :admin, lga_id: nil} -> q
        %{lga_id: lga_id} -> from s in q, where: s.lga_id == ^lga_id
      end
    end

    sellers =
      from(s in Seller, where: s.duplicate_suspected == true and is_nil(s.deleted_at))
      |> seller_scope.()
      |> Repo.all()

    Enum.map(sellers, fn s ->
      %{type: "seller", id: s.id, reason: "duplicate_suspected"}
    end)
  end
end
