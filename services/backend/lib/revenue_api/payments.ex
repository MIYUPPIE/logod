defmodule RevenueApi.Payments do
  @moduledoc """
  Payment recording. See specs/mvp_design.md "Feature: Revenue Collection
  (Payments)" — amount is always resolved server-side from the selected
  levy type, never accepted from the client, so a compromised or buggy
  mobile client cannot submit an arbitrary amount.
  """

  import Ecto.Query
  alias RevenueApi.Repo
  alias RevenueApi.Payments.Payment
  alias RevenueApi.{Audit, Sellers, Levies, Sequences}
  alias RevenueApi.Workers.ProcessPaymentWorker

  @type result :: {:ok, Payment.t()} | {:error, Ecto.Changeset.t() | atom()}

  def get_payment!(id), do: Repo.get!(Payment, id) |> Repo.preload([:seller, :levy_type, :agent])

  def get_payment(id) do
    case Repo.get(Payment, id) do
      nil -> nil
      payment -> Repo.preload(payment, [:seller, :levy_type, :agent])
    end
  end

  def get_by_client_uuid(client_uuid) do
    Repo.one(from p in Payment, where: p.client_uuid == ^client_uuid)
  end

  def list_for_seller(seller_id) do
    Repo.all(
      from p in Payment,
        where: p.seller_id == ^seller_id and is_nil(p.deleted_at),
        order_by: [desc: p.paid_at]
    )
  end

  @spec create(map(), RevenueApi.Accounts.User.t(), Audit.request_context()) :: result()
  def create(attrs, actor, request_context) do
    client_uuid = attrs[:client_uuid] || attrs["client_uuid"]

    case client_uuid && get_by_client_uuid(client_uuid) do
      %Payment{} = existing ->
        {:ok, existing}

      _ ->
        do_create(attrs, actor, request_context)
    end
  end

  defp do_create(attrs, actor, request_context) do
    seller_id = attrs[:seller_id] || attrs["seller_id"]
    levy_type_id = attrs[:levy_type_id] || attrs["levy_type_id"]

    with %{} = seller <- Sellers.get_seller(seller_id) || {:error, :seller_not_found},
         :ok <- authorize_lga(actor, seller.lga_id),
         %{} = levy_type <- Levies.get_active_levy_type(levy_type_id, seller.lga_id) ||
                               {:error, :levy_type_not_found} do
      insert_payment(attrs, seller, levy_type, actor, request_context)
    end
  end

  defp insert_payment(attrs, seller, levy_type, actor, request_context) do
    Repo.transaction(fn ->
      receipt_no = generate_receipt_no(seller)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      changeset_attrs =
        attrs
        |> Map.new(fn {k, v} -> {to_string(k), v} end)
        |> Map.merge(%{
          "amount" => levy_type.amount,
          "agent_id" => actor.id,
          "receipt_no" => receipt_no,
          "status" => :synced,
          "synced_at" => now
        })

      case %Payment{} |> Payment.changeset(changeset_attrs) |> Repo.insert() do
        {:ok, payment} ->
          Audit.record!(
            Audit.base(actor, "payment_recorded", "payment", payment.id, request_context, %{
              "amount" => Decimal.to_string(payment.amount)
            })
          )

          {:ok, _job} = Oban.insert(ProcessPaymentWorker.new(%{"payment_id" => payment.id}))
          Phoenix.PubSub.broadcast(RevenueApi.PubSub, "dashboard", :refresh)

          Repo.preload(payment, [:seller, :levy_type, :agent])

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp authorize_lga(%{role: :agent, lga_id: agent_lga_id}, seller_lga_id) do
    if agent_lga_id == seller_lga_id, do: :ok, else: {:error, :forbidden}
  end

  defp authorize_lga(_actor, _lga_id), do: :ok

  defp generate_receipt_no(seller) do
    lga = RevenueApi.Geo.get_lga!(seller.lga_id)
    year = DateTime.utc_now().year
    seq = Sequences.next("receipt_no:#{lga.code}:#{year}")
    padded = seq |> Integer.to_string() |> String.pad_leading(6, "0")
    "RCT-#{lga.code}-#{year}-#{padded}"
  end
end
