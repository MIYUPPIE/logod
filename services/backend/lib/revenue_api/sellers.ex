defmodule RevenueApi.Sellers do
  @moduledoc """
  Seller registration. See specs/mvp_design.md "Feature: Seller
  Registration" and "Data model gap-fill" for the idempotency and
  seller_uid-assignment rules implemented here.
  """

  import Ecto.Query
  alias RevenueApi.Repo
  alias RevenueApi.Sellers.Seller
  alias RevenueApi.{Audit, Geo, Sequences}

  @type result :: {:ok, Seller.t()} | {:error, Ecto.Changeset.t() | atom()}

  def get_seller!(id), do: Repo.get!(Seller, id) |> Repo.preload([:market, :ward, :lga, :state])

  def get_seller(id) do
    case Repo.get(Seller, id) do
      nil -> nil
      seller -> Repo.preload(seller, [:market, :ward, :lga, :state])
    end
  end

  def get_by_seller_uid(seller_uid) do
    Repo.one(from s in Seller, where: s.seller_uid == ^seller_uid and is_nil(s.deleted_at))
  end

  def get_by_client_uuid(client_uuid) do
    Repo.one(from s in Seller, where: s.client_uuid == ^client_uuid)
  end

  def search(query) when is_binary(query) do
    like = "%#{query}%"

    Repo.all(
      from s in Seller,
        where:
          is_nil(s.deleted_at) and
            (ilike(s.seller_uid, ^like) or ilike(s.phone, ^like) or
               ilike(s.business_name, ^like)),
        order_by: s.full_name,
        limit: 25
    )
  end

  @doc """
  Registers a seller. Idempotent on `client_uuid`: a retried call with the
  same `client_uuid` returns the already-created record instead of
  inserting again or erroring. Enforces LGA ownership for agent actors,
  geo-hierarchy consistency, assigns `seller_uid` at insert time (this call
  IS "first successful sync" whether it arrived via the direct endpoint or
  the offline sync batch endpoint), and flags phone-number collisions as
  `duplicate_suspected` on both records rather than silently merging.
  """
  @spec register(map(), RevenueApi.Accounts.User.t(), Audit.request_context()) :: result()
  def register(attrs, actor, request_context) do
    client_uuid = attrs[:client_uuid] || attrs["client_uuid"]

    case client_uuid && get_by_client_uuid(client_uuid) do
      %Seller{} = existing ->
        {:ok, Repo.preload(existing, [:market, :ward, :lga, :state])}

      _ ->
        do_register(attrs, actor, request_context)
    end
  end

  defp do_register(attrs, actor, request_context) do
    lga_id = attrs[:lga_id] || attrs["lga_id"]

    with :ok <- authorize_lga(actor, lga_id),
         :ok <- validate_hierarchy(attrs) do
      Repo.transaction(fn ->
        attrs =
          attrs
          |> Map.new(fn {k, v} -> {to_string(k), v} end)
          |> Map.put("registered_by_user_id", actor.id)

        changeset = Seller.changeset(%Seller{}, attrs)

        if changeset.valid? do
          seller_uid = assign_seller_uid(changeset)
          duplicate? = phone_collision?(changeset)

          changeset =
            changeset
            |> Ecto.Changeset.put_change(:seller_uid, seller_uid)
            |> Ecto.Changeset.put_change(:qr_payload, seller_uid)
            |> Ecto.Changeset.put_change(:duplicate_suspected, duplicate?)

          case Repo.insert(changeset) do
            {:ok, seller} ->
              if duplicate?, do: flag_existing_duplicates(seller)

              Audit.record!(
                Audit.base(actor, "seller_registered", "seller", seller.id, request_context, %{
                  "duplicate_suspected" => duplicate?
                })
              )

              Phoenix.PubSub.broadcast(RevenueApi.PubSub, "dashboard", :refresh)
              Repo.preload(seller, [:market, :ward, :lga, :state])

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        else
          Repo.rollback(changeset)
        end
      end)
    end
  end

  defp authorize_lga(%{role: :agent, lga_id: agent_lga_id}, lga_id) do
    if agent_lga_id == lga_id, do: :ok, else: {:error, :forbidden}
  end

  defp authorize_lga(_actor, _lga_id), do: :ok

  defp validate_hierarchy(attrs) do
    market_id = attrs[:market_id] || attrs["market_id"]
    ward_id = attrs[:ward_id] || attrs["ward_id"]
    lga_id = attrs[:lga_id] || attrs["lga_id"]
    state_id = attrs[:state_id] || attrs["state_id"]

    if Enum.all?([market_id, ward_id, lga_id, state_id]) and
         Geo.consistent_hierarchy?(market_id, ward_id, lga_id, state_id) do
      :ok
    else
      {:error, :inconsistent_geo_hierarchy}
    end
  end

  defp assign_seller_uid(changeset) do
    lga_id = Ecto.Changeset.get_field(changeset, :lga_id)
    state_id = Ecto.Changeset.get_field(changeset, :state_id)
    lga = Geo.get_lga!(lga_id)
    state = state_id && Geo.get_state!(state_id)
    year = DateTime.utc_now().year

    seq = Sequences.next("seller_uid:#{state.code}:#{lga.code}:#{year}")
    padded = seq |> Integer.to_string() |> String.pad_leading(6, "0")

    "#{state.code}-#{lga.code}-#{year}-#{padded}"
  end

  defp phone_collision?(changeset) do
    phone = Ecto.Changeset.get_field(changeset, :phone)
    Repo.exists?(from s in Seller, where: s.phone == ^phone and is_nil(s.deleted_at))
  end

  defp flag_existing_duplicates(%Seller{phone: phone, id: id}) do
    from(s in Seller, where: s.phone == ^phone and s.id != ^id and is_nil(s.deleted_at))
    |> Repo.update_all(set: [duplicate_suspected: true])
  end
end
