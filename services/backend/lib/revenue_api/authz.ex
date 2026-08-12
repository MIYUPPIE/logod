defmodule RevenueApi.Authz do
  @moduledoc """
  Centralized LGA-scoping check, reused by every context/controller that
  touches LGA-scoped data (sellers, payments, receipts). An actor with a
  non-nil `lga_id` (agent, supervisor, or an LGA-scoped admin) may only
  act on or view data belonging to that same LGA; an actor with
  `lga_id: nil` (a state-level admin, by convention) is unrestricted.

  Kept as one function so the rule can't drift between the write path
  and the read path — the gap that existed here (writes were LGA-scoped,
  reads weren't) was a real IDOR: any authenticated agent could read any
  other LGA's seller PII (phone, NIN, DOB, GPS, photo) by id, found
  during a security review pass.
  """

  @spec authorize_lga(RevenueApi.Accounts.User.t(), integer() | nil) ::
          :ok | {:error, :forbidden}
  def authorize_lga(%{lga_id: nil}, _lga_id), do: :ok

  def authorize_lga(%{lga_id: actor_lga_id}, lga_id) do
    if actor_lga_id == lga_id, do: :ok, else: {:error, :forbidden}
  end
end
