defmodule RevenueApi.Reports do
  @moduledoc "Revenue reporting: CSV/JSON export scoped to the requester's LGA (SRS §2 Admin Panel)."

  import Ecto.Query
  alias RevenueApi.Repo
  alias RevenueApi.Payments.Payment
  alias RevenueApi.Accounts.User

  NimbleCSV.define(RevenueApi.Reports.CSV, separator: ",", escape: "\"")

  def revenue(actor, from, to) do
    base =
      from p in Payment,
        join: a in User,
        on: a.id == p.agent_id,
        where: p.paid_at >= ^from and p.paid_at <= ^to and is_nil(p.deleted_at),
        order_by: [desc: p.paid_at],
        preload: [:seller, :levy_type, :agent]

    base
    |> scope(actor)
    |> Repo.all()
  end

  defp scope(query, %{role: :admin, lga_id: nil}), do: query
  defp scope(query, %{lga_id: lga_id}) do
    from [p, a] in query, where: a.lga_id == ^lga_id
  end

  def to_csv(payments) do
    header = ["receipt_no", "seller_uid", "business_name", "levy_type", "amount", "method", "agent", "paid_at"]

    rows =
      Enum.map(payments, fn p ->
        [
          p.receipt_no,
          p.seller.seller_uid,
          p.seller.business_name,
          p.levy_type.name,
          Decimal.to_string(p.amount),
          to_string(p.method),
          p.agent.name,
          DateTime.to_iso8601(p.paid_at)
        ]
      end)

    RevenueApi.Reports.CSV.dump_to_iodata([header | rows]) |> IO.iodata_to_binary()
  end
end
