defmodule RevenueApi.Audit do
  @moduledoc """
  Every mutating action in the system writes here: who, what, when, where.
  SRS §2/§8 requirement, enforced by calling `record/1` inside the context
  function that performs the write (not left to controllers to remember).
  """

  alias RevenueApi.Repo
  alias RevenueApi.Audit.AuditLog

  @type request_context :: %{
          optional(:ip) => String.t() | nil,
          optional(:device_id) => String.t() | nil,
          optional(:gps) => map() | nil
        }

  @spec record(map()) :: {:ok, AuditLog.t()} | {:error, Ecto.Changeset.t()}
  def record(attrs) do
    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Same as `record/1`, inside the given transaction's Multi if one is passed, else direct."
  def record!(attrs) do
    case record(attrs) do
      {:ok, log} -> log
      {:error, changeset} -> raise "failed to write audit log: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Builds the base attrs shared by every audit entry from a user (or nil, for
  a failed pre-auth event like a bad login) and a request_context map.
  """
  def base(user, action, entity_type, entity_id, request_context, metadata \\ %{}) do
    %{
      user_id: user && user.id,
      action: action,
      entity_type: entity_type,
      entity_id: entity_id && to_string(entity_id),
      ip: Map.get(request_context || %{}, :ip),
      device_id: Map.get(request_context || %{}, :device_id),
      gps: Map.get(request_context || %{}, :gps),
      metadata: metadata
    }
  end
end
