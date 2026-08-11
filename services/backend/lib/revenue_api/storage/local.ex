defmodule RevenueApi.Storage.Local do
  @moduledoc """
  Dev/test adapter: writes under `base_dir` on disk. `signed_url/2` returns
  a Phoenix.Token-signed `/uploads/:token` app route (see
  RevenueApiWeb.UploadController) rather than a raw file path, so the dev
  adapter still exercises "signed URL, not a public path."
  """
  @behaviour RevenueApi.Storage

  # Dev-only convenience: unlike the S3 adapter's presign (which supports a
  # genuine per-call TTL), the local token's expiry is fixed so
  # UploadController can verify it with a single, constant `max_age` rather
  # than a signature-then-payload double-verify dance.
  @max_age_seconds 3600

  @impl true
  def store(key, binary, _content_type) do
    path = safe_path(key)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, binary)
    {:ok, key}
  end

  @impl true
  def signed_url(key, _opts \\ []) do
    _ = safe_path(key)
    token = Phoenix.Token.sign(RevenueApiWeb.Endpoint, "storage", key)
    {:ok, "#{RevenueApiWeb.Endpoint.url()}/uploads/#{token}"}
  end

  def max_age_seconds, do: @max_age_seconds

  @impl true
  def fetch(key) do
    case File.read(safe_path(key)) do
      {:ok, binary} -> {:ok, binary}
      {:error, reason} -> {:error, reason}
    end
  end

  defp safe_path(key) do
    if String.contains?(key, "..") do
      raise ArgumentError, "invalid storage key: #{key}"
    end

    base_dir = Application.fetch_env!(:revenue_api, :storage_local)[:base_dir]
    Path.join(base_dir, key)
  end
end
