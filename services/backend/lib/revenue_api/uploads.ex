defmodule RevenueApi.Uploads do
  @moduledoc """
  Resolves a client-supplied photo into a stored object. Per
  specs/mvp_design.md "Feature: Seller Registration" [Security]: content
  type is sniffed from the actual bytes (magic numbers), never trusted
  from what the client claims, and size is capped server-side.
  """

  @max_bytes 5 * 1024 * 1024

  @doc """
  Decodes `base64` and stores it via the configured Storage adapter.
  Returns `{:ok, storage_key}` on success. The caller is responsible for
  putting that key on the `photo_url` field - never pass a client-supplied
  `photo_url` straight through, or you've handed upload validation to the
  client.
  """
  @spec store_seller_photo(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def store_seller_photo(base64) when is_binary(base64) do
    with {:ok, binary} <- decode(base64),
         :ok <- check_size(binary),
         {:ok, ext, content_type} <- sniff_image_type(binary) do
      key = "sellers/photos/#{Ecto.UUID.generate()}.#{ext}"
      RevenueApi.Storage.store(key, binary, content_type)
    end
  end

  defp decode(base64) do
    # Tolerate a data: URI prefix (e.g. "data:image/jpeg;base64,...") since
    # that's the most common shape a client-side image picker produces.
    base64 =
      case String.split(base64, ",", parts: 2) do
        [_meta, data] -> data
        [data] -> data
      end

    case Base.decode64(base64) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, :invalid_base64}
    end
  end

  defp check_size(binary) do
    if byte_size(binary) <= @max_bytes, do: :ok, else: {:error, :photo_too_large}
  end

  defp sniff_image_type(<<0xFF, 0xD8, 0xFF, _::binary>>), do: {:ok, "jpg", "image/jpeg"}

  defp sniff_image_type(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>),
    do: {:ok, "png", "image/png"}

  defp sniff_image_type(_binary), do: {:error, :unsupported_image_type}
end
