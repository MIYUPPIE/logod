defmodule RevenueApiWeb.LevyTypeJSON do
  alias RevenueApi.Levies.LevyType

  def show(%{levy_type: levy_type}), do: data(levy_type)
  def index(%{levy_types: levy_types}), do: Enum.map(levy_types, &data/1)

  def data(%LevyType{} = levy_type) do
    %{
      id: levy_type.id,
      lga_id: levy_type.lga_id,
      name: levy_type.name,
      amount: levy_type.amount,
      frequency: levy_type.frequency
    }
  end
end
