defmodule RevenueApiWeb.SupervisorDashboardLive do
  use RevenueApiWeb, :live_view

  alias RevenueApi.Dashboard

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(RevenueApi.PubSub, "dashboard")
    {:ok, assign(socket, :summary, Dashboard.summary(socket.assigns.current_user))}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, assign(socket, :summary, Dashboard.summary(socket.assigns.current_user))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user}>
      <h1 class="text-xl font-semibold mb-6">Supervisor Dashboard</h1>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Today's Collections</div>
          <div class="text-2xl font-bold">NGN {@summary.today_total_amount}</div>
        </div>
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Payments Today</div>
          <div class="text-2xl font-bold">{@summary.today_payment_count}</div>
        </div>
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Pending Review</div>
          <div class="text-2xl font-bold">{@summary.pending_sync_count}</div>
        </div>
      </div>

      <h2 class="text-lg font-semibold mb-2">Active Agents</h2>
      <table class="table mb-8">
        <thead>
          <tr><th>Agent</th><th>Today's Total</th></tr>
        </thead>
        <tbody>
          <tr :for={agent <- @summary.active_agents}>
            <td>{agent.name}</td>
            <td>NGN {agent.today_total}</td>
          </tr>
          <tr :if={@summary.active_agents == []}>
            <td colspan="2" class="opacity-60">No agents in this LGA yet.</td>
          </tr>
        </tbody>
      </table>

      <h2 class="text-lg font-semibold mb-2">Flagged for Review</h2>
      <table class="table">
        <thead>
          <tr><th>Type</th><th>ID</th><th>Reason</th></tr>
        </thead>
        <tbody>
          <tr :for={item <- @summary.flagged}>
            <td>{item.type}</td>
            <td>{item.id}</td>
            <td>{item.reason}</td>
          </tr>
          <tr :if={@summary.flagged == []}>
            <td colspan="3" class="opacity-60">Nothing flagged.</td>
          </tr>
        </tbody>
      </table>
    </Layouts.app>
    """
  end
end
