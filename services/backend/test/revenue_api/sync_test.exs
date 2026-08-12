defmodule RevenueApi.SyncTest do
  use RevenueApi.DataCase, async: true

  import RevenueApi.Factory

  alias RevenueApi.Sync

  setup do
    market = insert(:market) |> RevenueApi.Repo.preload(ward: [lga: :state])
    lga = market.ward.lga
    agent = insert(:agent, lga_id: lga.id)
    levy_type = insert(:levy_type, lga_id: lga.id)

    seller_record = fn client_uuid ->
      %{
        "type" => "seller",
        "client_uuid" => client_uuid,
        "payload" => %{
          "full_name" => "Synced Seller",
          "phone" => "0803#{:rand.uniform(9_999_999)}",
          "dob" => "1990-01-01",
          "gender" => "male",
          "business_name" => "Synced Biz",
          "business_category" => "General",
          "market_id" => market.id,
          "ward_id" => market.ward_id,
          "lga_id" => lga.id,
          "state_id" => market.ward.lga.state_id,
          "lat" => 6.5,
          "lng" => 3.3
        }
      }
    end

    %{agent: agent, market: market, lga: lga, levy_type: levy_type, seller_record: seller_record}
  end

  test "processes a batch of seller records and returns per-record results", %{
    agent: agent,
    seller_record: seller_record
  } do
    client_uuid = Ecto.UUID.generate()
    results = Sync.process_batch([seller_record.(client_uuid)], agent, %{})

    assert [
             %{
               client_uuid: ^client_uuid,
               status: "synced",
               canonical_id: id,
               seller_uid: seller_uid
             }
           ] = results

    assert is_integer(id)
    assert is_binary(seller_uid)
  end

  test "retrying the exact same batch (simulating a response that never arrived) is idempotent",
       %{
         agent: agent,
         seller_record: seller_record
       } do
    client_uuid = Ecto.UUID.generate()
    batch = [seller_record.(client_uuid)]

    [first] = Sync.process_batch(batch, agent, %{})
    [second] = Sync.process_batch(batch, agent, %{})

    assert first.canonical_id == second.canonical_id
    assert first.seller_uid == second.seller_uid
    assert RevenueApi.Repo.aggregate(RevenueApi.Sellers.Seller, :count) == 1
  end

  test "a mixed batch processes each record independently - one bad record doesn't fail the rest",
       %{
         agent: agent,
         seller_record: seller_record
       } do
    good_uuid = Ecto.UUID.generate()
    bad_record = %{"type" => "seller", "client_uuid" => Ecto.UUID.generate(), "payload" => %{}}

    results = Sync.process_batch([seller_record.(good_uuid), bad_record], agent, %{})

    assert [%{status: "synced"}, %{status: "error"}] = results
  end

  test "a payment record in the batch is idempotent on client_uuid too", %{
    agent: agent,
    seller_record: seller_record,
    levy_type: levy_type
  } do
    seller_uuid = Ecto.UUID.generate()
    [%{canonical_id: seller_id}] = Sync.process_batch([seller_record.(seller_uuid)], agent, %{})

    payment_uuid = Ecto.UUID.generate()

    payment_record = %{
      "type" => "payment",
      "client_uuid" => payment_uuid,
      "payload" => %{
        "seller_id" => seller_id,
        "levy_type_id" => levy_type.id,
        "method" => "cash",
        "paid_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    [first] = Sync.process_batch([payment_record], agent, %{})
    [second] = Sync.process_batch([payment_record], agent, %{})

    assert first.status == "synced"
    assert first.canonical_id == second.canonical_id
    assert RevenueApi.Repo.aggregate(RevenueApi.Payments.Payment, :count) == 1
  end
end
