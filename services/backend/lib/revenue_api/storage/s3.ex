defmodule RevenueApi.Storage.S3 do
  @moduledoc """
  Prod adapter: S3 or MinIO (S3-compatible) via req_s3. Credentials/region
  come from the standard AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY /
  AWS_REGION env vars; point AWS_ENDPOINT_URL_S3 at a MinIO endpoint to use
  MinIO instead of real S3, per SRS §3.
  """
  @behaviour RevenueApi.Storage

  defp req, do: Req.new() |> ReqS3.attach()
  defp bucket, do: Application.fetch_env!(:revenue_api, :storage_s3)[:bucket]

  @impl true
  def store(key, binary, content_type) do
    case Req.put(req(),
           url: "s3://#{bucket()}/#{key}",
           body: binary,
           headers: [{"content-type", content_type}]
         ) do
      {:ok, %{status: status}} when status in 200..299 -> {:ok, key}
      {:ok, response} -> {:error, {:http_error, response.status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def signed_url(key, opts \\ []) do
    expires_in = Keyword.get(opts, :expires_in, 3600)
    url = ReqS3.presign_url(bucket: bucket(), key: key, expires: expires_in)
    {:ok, url}
  end

  @impl true
  def fetch(key) do
    case Req.get(req(), url: "s3://#{bucket()}/#{key}") do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, response} -> {:error, {:http_error, response.status}}
      {:error, reason} -> {:error, reason}
    end
  end
end
