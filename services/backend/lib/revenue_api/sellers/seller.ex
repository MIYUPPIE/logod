defmodule RevenueApi.Sellers.Seller do
  use Ecto.Schema
  import Ecto.Changeset

  @genders [:male, :female, :other]

  schema "sellers" do
    field :client_uuid, Ecto.UUID
    field :seller_uid, :string

    field :full_name, :string
    field :photo_url, :string
    field :phone, :string
    field :nin, :string
    field :dob, :date
    field :gender, Ecto.Enum, values: @genders
    field :home_address, :string

    field :business_name, :string
    field :business_category, :string
    field :shop_number, :string

    field :lat, :float
    field :lng, :float
    field :gps_accuracy, :float
    field :gps_captured_at, :utc_datetime

    field :qr_payload, :string
    field :duplicate_suspected, :boolean, default: false
    field :deleted_at, :utc_datetime

    belongs_to :market, RevenueApi.Geo.Market
    belongs_to :ward, RevenueApi.Geo.Ward
    belongs_to :lga, RevenueApi.Geo.Lga
    belongs_to :state, RevenueApi.Geo.State
    belongs_to :registered_by, RevenueApi.Accounts.User, foreign_key: :registered_by_user_id

    timestamps(type: :utc_datetime)
  end

  @required [
    :client_uuid,
    :full_name,
    :phone,
    :dob,
    :gender,
    :business_name,
    :business_category,
    :market_id,
    :ward_id,
    :lga_id,
    :state_id,
    :lat,
    :lng,
    :registered_by_user_id
  ]

  @optional [
    :photo_url,
    :nin,
    :home_address,
    :shop_number,
    :gps_accuracy,
    :gps_captured_at,
    :seller_uid,
    :duplicate_suspected
  ]

  def changeset(seller, attrs) do
    seller
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_format(:nin, ~r/^[0-9]{11}$/, message: "must be 11 digits")
    |> validate_inclusion(:gender, @genders)
    |> validate_number(:lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:lng, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> unique_constraint(:client_uuid)
    |> unique_constraint(:seller_uid)
    |> foreign_key_constraint(:market_id)
    |> foreign_key_constraint(:ward_id)
    |> foreign_key_constraint(:lga_id)
    |> foreign_key_constraint(:state_id)
    |> foreign_key_constraint(:registered_by_user_id)
  end
end
