defmodule RevenueApi.Storage do
  @moduledoc """
  Swappable object storage boundary (SRS §3: MinIO or S3; §8: private
  bucket, signed URLs only). `Local` (dev/test) writes to disk and signs a
  short-lived app-route token; `S3` (prod) is a real S3/MinIO bucket via
  req_s3. Schemas store the opaque storage *key* returned by `store/3`,
  never a URL — `signed_url/2` mints a fresh short-lived URL at read time,
  so nothing long-lived and world-readable ever sits in the database.
  """

  @callback store(key :: String.t(), binary :: binary(), content_type :: String.t()) ::
              {:ok, key :: String.t()} | {:error, term()}
  @callback signed_url(key :: String.t(), opts :: keyword()) :: {:ok, String.t()}
  @callback fetch(key :: String.t()) :: {:ok, binary()} | {:error, term()}

  def impl, do: Application.fetch_env!(:revenue_api, :storage)

  def store(key, binary, content_type), do: impl().store(key, binary, content_type)
  def signed_url(key, opts \\ []), do: impl().signed_url(key, opts)
  def fetch(key), do: impl().fetch(key)
end
