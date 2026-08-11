defmodule RevenueApiWeb.UploadController do
  @moduledoc """
  Serves files stored by RevenueApi.Storage.Local. Not part of
  contracts/openapi.yaml — an implementation detail of the dev-only local
  storage adapter; the S3 adapter used in prod serves signed URLs directly
  from the bucket instead of routing through the app.
  """
  use RevenueApiWeb, :controller

  alias RevenueApi.Storage.Local

  def show(conn, %{"token" => token}) do
    case Phoenix.Token.verify(RevenueApiWeb.Endpoint, "storage", token,
           max_age: Local.max_age_seconds()
         ) do
      {:ok, key} ->
        case RevenueApi.Storage.fetch(key) do
          {:ok, binary} ->
            conn
            |> put_resp_content_type(content_type_for(key))
            |> send_resp(200, binary)

          {:error, _reason} ->
            conn |> put_status(:not_found) |> json(%{errors: %{detail: "not_found"}})
        end

      {:error, _reason} ->
        conn |> put_status(:forbidden) |> json(%{errors: %{detail: "invalid_or_expired_token"}})
    end
  end

  defp content_type_for(key) do
    case Path.extname(key) do
      ".pdf" -> "application/pdf"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      _ -> "application/octet-stream"
    end
  end
end
