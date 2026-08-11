defmodule RevenueApi.Sync do
  @moduledoc """
  Offline batch sync (SRS §6). Each record is processed independently in
  its own transaction (delegated to Sellers.register/3 or Payments.create/3,
  which already wrap themselves) so one bad record in a batch never fails
  the rest. Records are capped at 200 per contracts/openapi.yaml
  SyncBatchRequest.records.maxItems by the controller before this is called.
  """

  alias RevenueApi.{Sellers, Payments}

  @spec process_batch([map()], RevenueApi.Accounts.User.t(), RevenueApi.Audit.request_context()) ::
          [map()]
  def process_batch(records, actor, request_context) do
    Enum.map(records, &process_record(&1, actor, request_context))
  end

  defp process_record(%{"type" => "seller", "client_uuid" => client_uuid} = record, actor, ctx) do
    payload = Map.put(record["payload"] || %{}, "client_uuid", client_uuid)

    case Sellers.register(payload, actor, ctx) do
      {:ok, seller} ->
        result(client_uuid, seller.duplicate_suspected && "flagged" || "synced",
          canonical_id: seller.id,
          seller_uid: seller.seller_uid,
          reason: seller.duplicate_suspected && "duplicate_suspected"
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        result(client_uuid, "error", reason: changeset_error_summary(changeset))

      {:error, reason} ->
        result(client_uuid, "error", reason: to_string(reason))
    end
  end

  defp process_record(%{"type" => "payment", "client_uuid" => client_uuid} = record, actor, ctx) do
    payload = Map.put(record["payload"] || %{}, "client_uuid", client_uuid)

    case Payments.create(payload, actor, ctx) do
      {:ok, payment} ->
        result(client_uuid, "synced", canonical_id: payment.id, receipt_no: payment.receipt_no)

      {:error, %Ecto.Changeset{} = changeset} ->
        result(client_uuid, "error", reason: changeset_error_summary(changeset))

      {:error, reason} ->
        result(client_uuid, "error", reason: to_string(reason))
    end
  end

  defp process_record(%{"client_uuid" => client_uuid}, _actor, _ctx) do
    result(client_uuid, "error", reason: "unknown record type")
  end

  defp result(client_uuid, status, opts) do
    %{
      client_uuid: client_uuid,
      status: status,
      canonical_id: Keyword.get(opts, :canonical_id),
      seller_uid: Keyword.get(opts, :seller_uid),
      receipt_no: Keyword.get(opts, :receipt_no),
      reason: Keyword.get(opts, :reason)
    }
  end

  defp changeset_error_summary(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Jason.encode!()
  end
end
