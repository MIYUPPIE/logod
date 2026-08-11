defmodule RevenueApiWeb.Admin.LevyTypesLive do
  use RevenueApiWeb, :live_view

  alias RevenueApi.{Levies, Geo}
  alias RevenueApi.Levies.LevyType

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:states, Geo.list_states())
     |> assign(:selected_lga_id, nil)
     |> assign(:levy_types, [])
     |> assign(:form, to_form(LevyType.changeset(%LevyType{}, %{})))}
  end

  @impl true
  def handle_event("select_lga", %{"lga_id" => ""}, socket) do
    {:noreply, assign(socket, selected_lga_id: nil, levy_types: [])}
  end

  def handle_event("select_lga", %{"lga_id" => lga_id}, socket) do
    {lga_id, _} = Integer.parse(lga_id)

    {:noreply,
     socket
     |> assign(:selected_lga_id, lga_id)
     |> assign(:levy_types, Levies.list_levy_types(lga_id))
     |> assign(:form, to_form(LevyType.changeset(%LevyType{}, %{"lga_id" => lga_id})))}
  end

  def handle_event("validate", %{"levy_type" => params}, socket) do
    changeset = %LevyType{} |> LevyType.changeset(params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"levy_type" => params}, socket) do
    params = Map.put(params, "lga_id", socket.assigns.selected_lga_id)

    case Levies.create_levy_type(params, socket.assigns.current_user, %{}) do
      {:ok, _levy_type} ->
        {:noreply,
         socket
         |> put_flash(:info, "Levy type created.")
         |> assign(:levy_types, Levies.list_levy_types(socket.assigns.selected_lga_id))
         |> assign(:form, to_form(LevyType.changeset(%LevyType{}, %{"lga_id" => socket.assigns.selected_lga_id})))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("update_amount", %{"levy_type_id" => id, "amount" => amount}, socket) do
    levy_type = Levies.get_levy_type!(id)
    {:ok, _} = Levies.update_levy_type(levy_type, %{"amount" => amount}, socket.assigns.current_user, %{})
    {:noreply, assign(socket, :levy_types, Levies.list_levy_types(socket.assigns.selected_lga_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user}>
      <h1 class="text-xl font-semibold mb-6">Levy Types</h1>

      <form phx-change="select_lga" class="mb-6 max-w-sm">
        <.input
          name="lga_id"
          type="select"
          label="LGA"
          prompt="Choose an LGA"
          options={Enum.flat_map(@states, fn s -> Enum.map(Geo.list_lgas(s.id), &{"#{s.name} / #{&1.name}", &1.id}) end)}
        />
      </form>

      <div :if={@selected_lga_id}>
        <table class="table mb-6">
          <thead><tr><th>Name</th><th>Amount</th><th>Frequency</th></tr></thead>
          <tbody>
            <tr :for={lt <- @levy_types}>
              <td>{lt.name}</td>
              <td>
                <form phx-submit="update_amount" class="flex gap-2 items-center">
                  <input type="hidden" name="levy_type_id" value={lt.id} />
                  <input type="number" step="0.01" name="amount" value={lt.amount} class="input input-sm w-28" />
                  <button type="submit" class="btn btn-xs">Update</button>
                </form>
              </td>
              <td>{lt.frequency}</td>
            </tr>
            <tr :if={@levy_types == []}>
              <td colspan="3" class="opacity-60">No levy types for this LGA yet.</td>
            </tr>
          </tbody>
        </table>

        <h2 class="text-lg font-semibold mb-2">Add Levy Type</h2>
        <.form for={@form} phx-change="validate" phx-submit="save" class="grid grid-cols-3 gap-2 max-w-xl">
          <.input field={@form[:name]} label="Name" />
          <.input field={@form[:amount]} type="number" label="Amount" step="0.01" />
          <.input
            field={@form[:frequency]}
            type="select"
            label="Frequency"
            options={Enum.map(LevyType.frequencies(), &{Phoenix.Naming.humanize(&1), &1})}
          />
          <button type="submit" class="btn btn-primary col-span-3">Add</button>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
