defmodule RevenueApiWeb.ControllerHelpers do
  @moduledoc "Small helpers imported into every controller. See RevenueApiWeb.controller/0."

  def current_user(conn), do: Guardian.Plug.current_resource(conn)
  def request_context(conn), do: conn.assigns[:request_context] || %{}

  @doc "Renders an Ecto.Changeset's errors as {field: [messages]} for a 422 response."
  def render_changeset_errors(conn, changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    conn
    |> Plug.Conn.put_status(:unprocessable_entity)
    |> Phoenix.Controller.json(%{errors: errors})
  end
end
