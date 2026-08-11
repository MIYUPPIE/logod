defmodule RevenueApiWeb.SellerJSON do
  alias RevenueApi.Sellers.Seller
  alias RevenueApi.Storage

  def show(%{seller: seller}), do: data(seller)
  def index(%{sellers: sellers}), do: Enum.map(sellers, &data/1)

  def data(%Seller{} = seller) do
    %{
      id: seller.id,
      seller_uid: seller.seller_uid,
      client_uuid: seller.client_uuid,
      full_name: seller.full_name,
      photo_url: photo_url(seller.photo_url),
      phone: seller.phone,
      nin: seller.nin,
      dob: seller.dob,
      gender: seller.gender,
      home_address: seller.home_address,
      business_name: seller.business_name,
      business_category: seller.business_category,
      shop_number: seller.shop_number,
      market_id: seller.market_id,
      ward_id: seller.ward_id,
      lga_id: seller.lga_id,
      state_id: seller.state_id,
      lat: seller.lat,
      lng: seller.lng,
      gps_accuracy: seller.gps_accuracy,
      gps_captured_at: seller.gps_captured_at,
      registered_by_user_id: seller.registered_by_user_id,
      qr_payload: seller.qr_payload,
      duplicate_suspected: seller.duplicate_suspected,
      created_at: seller.inserted_at
    }
  end

  defp photo_url(nil), do: nil

  defp photo_url(key) do
    case Storage.signed_url(key) do
      {:ok, url} -> url
      _ -> nil
    end
  end
end
