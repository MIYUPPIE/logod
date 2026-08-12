defmodule RevenueApiWeb.Admin.UsersLive do
  use RevenueApiWeb, :live_view

  alias RevenueApi.Accounts
  alias RevenueApi.Accounts.User
  alias RevenueApi.Geo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:users, Accounts.list_users())
     |> assign(:states, Geo.list_states())
     |> assign(:form, to_form(User.create_changeset(%User{}, %{})))}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset = %User{} |> User.create_changeset(params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.create_user(params, socket.assigns.current_user, %{}) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User created.")
         |> assign(:users, Accounts.list_users())
         |> assign(:form, to_form(User.create_changeset(%User{}, %{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user}>
      <h1 class="text-xl font-semibold mb-6">Users &amp; Agents</h1>

      <.form
        for={@form}
        phx-change="validate"
        phx-submit="save"
        class="grid grid-cols-2 gap-2 mb-8 max-w-2xl"
      >
        <.input field={@form[:name]} label="Name" />
        <.input field={@form[:email]} label="Email" />
        <.input field={@form[:phone]} label="Phone" />
        <.input field={@form[:password]} type="password" label="Password" />
        <.input
          field={@form[:role]}
          type="select"
          label="Role"
          options={Enum.map(User.roles(), &{Phoenix.Naming.humanize(&1), &1})}
        />
        <.input
          field={@form[:lga_id]}
          type="select"
          label="LGA"
          prompt="State-level (all LGAs)"
          options={
            Enum.flat_map(@states, fn s ->
              Enum.map(Geo.list_lgas(s.id), &{"#{s.name} / #{&1.name}", &1.id})
            end)
          }
        />
        <button type="submit" class="btn btn-primary col-span-2">Create User</button>
      </.form>

      <table class="table">
        <thead>
          <tr>
            <th>Name</th><th>Role</th><th>Contact</th><th>Active</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={user <- @users}>
            <td>{user.name}</td>
            <td>{user.role}</td>
            <td>{user.email || user.phone}</td>
            <td>{user.active}</td>
          </tr>
        </tbody>
      </table>
    </Layouts.app>
    """
  end
end
