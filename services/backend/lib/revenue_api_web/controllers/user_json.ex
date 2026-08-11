defmodule RevenueApiWeb.UserJSON do
  alias RevenueApi.Accounts.User

  def show(%{user: user}), do: data(user)
  def index(%{users: users}), do: Enum.map(users, &data/1)

  @doc "Explicit field allowlist — password_hash never leaves this module, even by accident."
  def data(%User{} = user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      lga_id: user.lga_id,
      device_id: user.device_id,
      active: user.active
    }
  end
end
