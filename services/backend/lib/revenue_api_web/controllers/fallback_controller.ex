defmodule RevenueApiWeb.FallbackController do
  @moduledoc "Central error -> HTTP status mapping for controller `with` blocks."
  use RevenueApiWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    render_changeset_errors(conn, changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn |> put_status(:not_found) |> json(%{errors: %{detail: "not_found"}})
  end

  def call(conn, {:error, :seller_not_found}) do
    conn |> put_status(:not_found) |> json(%{errors: %{detail: "seller_not_found"}})
  end

  def call(conn, {:error, :levy_type_not_found}) do
    conn |> put_status(:not_found) |> json(%{errors: %{detail: "levy_type_not_found"}})
  end

  def call(conn, {:error, :forbidden}) do
    conn |> put_status(:forbidden) |> json(%{errors: %{detail: "forbidden"}})
  end

  def call(conn, {:error, :not_ready}) do
    conn |> put_status(:conflict) |> json(%{errors: %{detail: "receipt_pdf_not_ready"}})
  end

  def call(conn, {:error, :inconsistent_geo_hierarchy}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{detail: "inconsistent_geo_hierarchy"}})
  end

  def call(conn, {:error, reason}) do
    conn |> put_status(:unprocessable_entity) |> json(%{errors: %{detail: to_string(reason)}})
  end
end
