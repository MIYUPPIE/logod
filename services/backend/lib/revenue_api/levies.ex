defmodule RevenueApi.Levies do
  @moduledoc "Levy type catalog: an LGA-scoped price list for what agents can collect."

  import Ecto.Query
  alias RevenueApi.Repo
  alias RevenueApi.Levies.LevyType
  alias RevenueApi.Audit

  def list_levy_types(lga_id) do
    Repo.all(
      from lt in LevyType,
        where: lt.lga_id == ^lga_id and lt.active == true and is_nil(lt.deleted_at),
        order_by: lt.name
    )
  end

  def get_levy_type!(id), do: Repo.get!(LevyType, id)

  def get_active_levy_type(id, lga_id) do
    Repo.one(
      from lt in LevyType,
        where:
          lt.id == ^id and lt.lga_id == ^lga_id and lt.active == true and is_nil(lt.deleted_at)
    )
  end

  def create_levy_type(attrs, actor, request_context) do
    Repo.transaction(fn ->
      case %LevyType{} |> LevyType.changeset(attrs) |> Repo.insert() do
        {:ok, levy_type} ->
          Audit.record!(
            Audit.base(actor, "levy_type_created", "levy_type", levy_type.id, request_context)
          )

          levy_type

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def update_levy_type(%LevyType{} = levy_type, attrs, actor, request_context) do
    Repo.transaction(fn ->
      case levy_type |> LevyType.changeset(attrs) |> Repo.update() do
        {:ok, updated} ->
          Audit.record!(
            Audit.base(actor, "levy_type_updated", "levy_type", updated.id, request_context, %{
              "changes" => Map.take(attrs, ["amount", "frequency", :amount, :frequency])
            })
          )

          updated

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end
end
