defmodule RevenueApiWeb.GeoJSON do
  def index(%{nodes: nodes}), do: Enum.map(nodes, &data/1)

  defp data(%{id: id, name: name} = node) do
    %{id: id, name: name, code: Map.get(node, :code)}
  end
end
