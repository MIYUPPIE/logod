defmodule RevenueApi.Factory do
  use ExMachina.Ecto, repo: RevenueApi.Repo

  alias RevenueApi.Geo.{State, Lga, Ward, Market}
  alias RevenueApi.Accounts.User
  alias RevenueApi.Levies.LevyType
  alias RevenueApi.Sellers.Seller
  alias RevenueApi.Payments.Payment

  # Every factory below sets foreign keys as plain `_id` fields rather than
  # nested association structs (e.g. `lga_id: lga.id`, not `lga: build(:lga)`).
  # Ecto raises if a struct has both an association field AND its own
  # foreign key set at once, which is exactly what happens the moment a
  # caller does `insert(:levy_type, lga_id: some_id)` to override it -
  # plain `_id` fields don't have that failure mode.

  def state_factory do
    seq = sequence(:state, & &1)
    %State{name: "State #{seq}", code: "S#{seq}"}
  end

  def lga_factory do
    seq = sequence(:lga, & &1)
    state = insert(:state)
    %Lga{name: "LGA #{seq}", code: "L#{seq}", state_id: state.id}
  end

  def ward_factory do
    lga = insert(:lga)
    %Ward{name: sequence(:ward, &"Ward #{&1}"), lga_id: lga.id}
  end

  def market_factory do
    ward = insert(:ward)
    %Market{name: sequence(:market, &"Market #{&1}"), ward_id: ward.id}
  end

  def user_factory do
    %User{
      name: sequence(:user_name, &"User #{&1}"),
      email: sequence(:email, &"user#{&1}@example.com"),
      role: :agent,
      active: true,
      password_hash: Argon2.hash_pwd_salt("password12345")
    }
  end

  def admin_factory, do: struct!(user_factory(), role: :admin, lga_id: nil)

  def agent_factory do
    lga = insert(:lga)
    struct!(user_factory(), role: :agent, lga_id: lga.id)
  end

  def supervisor_factory do
    lga = insert(:lga)
    struct!(user_factory(), role: :supervisor, lga_id: lga.id)
  end

  def levy_type_factory do
    lga = insert(:lga)

    %LevyType{
      name: sequence(:levy_name, &"Levy #{&1}"),
      amount: Decimal.new("1000.00"),
      frequency: :daily,
      active: true,
      lga_id: lga.id
    }
  end

  def seller_factory do
    market = insert(:market) |> RevenueApi.Repo.preload(ward: [lga: :state])
    agent = insert(:agent, lga_id: market.ward.lga_id)

    %Seller{
      client_uuid: Ecto.UUID.generate(),
      seller_uid: nil,
      full_name: sequence(:seller_name, &"Seller #{&1}"),
      phone: sequence(:phone, &"0803000#{String.pad_leading(to_string(&1), 4, "0")}"),
      dob: ~D[1990-01-01],
      gender: :male,
      business_name: sequence(:biz_name, &"Business #{&1}"),
      business_category: "General",
      market_id: market.id,
      ward_id: market.ward_id,
      lga_id: market.ward.lga_id,
      state_id: market.ward.lga.state_id,
      lat: 6.5,
      lng: 3.3,
      registered_by_user_id: agent.id
    }
  end

  def payment_factory do
    seller = insert(:seller)
    levy_type = insert(:levy_type, lga_id: seller.lga_id)

    %Payment{
      client_uuid: Ecto.UUID.generate(),
      seller_id: seller.id,
      levy_type_id: levy_type.id,
      amount: levy_type.amount,
      method: :cash,
      agent_id: seller.registered_by_user_id,
      receipt_no:
        sequence(:receipt_no, &"RCT-TST-2026-#{String.pad_leading(to_string(&1), 6, "0")}"),
      status: :synced,
      paid_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end
end
