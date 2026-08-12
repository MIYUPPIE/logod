defmodule RevenueApi.UploadsTest do
  use RevenueApi.DataCase, async: true

  alias RevenueApi.Uploads

  @tiny_png Base.encode64(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0, "IHDR", 0, 0, 0, 0>>)

  test "stores a valid base64-encoded PNG and returns a storage key" do
    assert {:ok, key} = Uploads.store_seller_photo(@tiny_png)
    assert String.starts_with?(key, "sellers/photos/")
    assert String.ends_with?(key, ".png")
    assert {:ok, _binary} = RevenueApi.Storage.fetch(key)
  end

  test "accepts a data: URI prefix" do
    assert {:ok, _key} = Uploads.store_seller_photo("data:image/png;base64,#{@tiny_png}")
  end

  test "rejects invalid base64" do
    assert {:error, :invalid_base64} = Uploads.store_seller_photo("not-base64-!!!")
  end

  test "rejects a payload that isn't a real image (content sniffed, not trusted from a claimed type)" do
    fake = Base.encode64("this is not an image, just text pretending to be one")
    assert {:error, :unsupported_image_type} = Uploads.store_seller_photo(fake)
  end

  test "rejects a photo over the 5MB cap" do
    huge = Base.encode64(<<0xFF, 0xD8, 0xFF>> <> :binary.copy(<<0>>, 6 * 1024 * 1024))
    assert {:error, :photo_too_large} = Uploads.store_seller_photo(huge)
  end
end
