defmodule RevenueApiWeb.Admin.ReportsLive do
  use RevenueApiWeb, :live_view

  alias RevenueApi.Reports

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    from = Date.add(today, -7)

    {:ok,
     socket
     |> assign(:from, from)
     |> assign(:to, today)
     |> assign(:payments, load(socket.assigns.current_user, from, today))}
  end

  @impl true
  def handle_event("filter", %{"from" => from_str, "to" => to_str}, socket) do
    with {:ok, from} <- Date.from_iso8601(from_str),
         {:ok, to} <- Date.from_iso8601(to_str) do
      {:noreply,
       socket
       |> assign(:from, from)
       |> assign(:to, to)
       |> assign(:payments, load(socket.assigns.current_user, from, to))}
    else
      _ -> {:noreply, socket}
    end
  end

  defp load(user, from, to) do
    Reports.revenue(
      user,
      DateTime.new!(from, ~T[00:00:00], "Etc/UTC"),
      DateTime.new!(to, ~T[23:59:59], "Etc/UTC")
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_user}>
      <h1 class="text-xl font-semibold mb-6">Revenue Reports</h1>

      <form phx-submit="filter" class="flex gap-2 items-end mb-4">
        <div>
          <label class="label">From</label>
          <input type="date" name="from" value={@from} class="input" />
        </div>
        <div>
          <label class="label">To</label>
          <input type="date" name="to" value={@to} class="input" />
        </div>
        <button type="submit" class="btn btn-primary">Filter</button>
        <a
          href={
            ~p"/admin/reports/revenue.csv?from=#{Date.to_iso8601(@from)}&to=#{Date.to_iso8601(@to)}"
          }
          class="btn btn-outline"
        >
          Download CSV
        </a>
      </form>

      <table class="table">
        <thead>
          <tr>
            <th>Receipt</th><th>Seller</th><th>Levy</th><th>Amount</th><th>Method</th><th>Agent</th><th>
              Date
            </th>
          </tr>
        </thead>
        <tbody>
          <tr :for={p <- @payments}>
            <td>{p.receipt_no}</td>
            <td>{p.seller.business_name}</td>
            <td>{p.levy_type.name}</td>
            <td>NGN {p.amount}</td>
            <td>{p.method}</td>
            <td>{p.agent.name}</td>
            <td>{Calendar.strftime(p.paid_at, "%Y-%m-%d %H:%M")}</td>
          </tr>
          <tr :if={@payments == []}>
            <td colspan="7" class="opacity-60">No payments in this range.</td>
          </tr>
        </tbody>
      </table>
    </Layouts.app>
    """
  end
end
