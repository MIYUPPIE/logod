defmodule RevenueApiWeb.SyncController do
  use RevenueApiWeb, :controller

  alias RevenueApi.Sync

  @max_batch_size 200

  def batch(conn, %{"records" => records}) when is_list(records) do
    if length(records) > @max_batch_size do
      conn
      |> put_status(:bad_request)
      |> json(%{errors: %{detail: "batch too large, max #{@max_batch_size} records"}})
    else
      results = Sync.process_batch(records, current_user(conn), request_context(conn))
      json(conn, %{results: results})
    end
  end

  def batch(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{errors: %{detail: "records must be a list"}})
  end
end
