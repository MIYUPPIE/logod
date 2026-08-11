defmodule RevenueApi.Guardian do
  use Guardian, otp_app: :revenue_api

  alias RevenueApi.Accounts

  @impl true
  def subject_for_token(user, _claims), do: {:ok, to_string(user.id)}

  @impl true
  def build_claims(claims, user, _opts) do
    {:ok, Map.merge(claims, %{"role" => to_string(user.role), "lga_id" => user.lga_id})}
  end

  @impl true
  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_active_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end

  def resource_from_claims(_claims), do: {:error, :invalid_claims}
end
