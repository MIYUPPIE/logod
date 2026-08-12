defmodule RevenueApi.SellersTest do
  use RevenueApi.DataCase, async: true

  import RevenueApi.Factory

  alias RevenueApi.Sellers

  setup do
    market = insert(:market) |> RevenueApi.Repo.preload(ward: [lga: :state])
    lga = market.ward.lga
    state = lga.state
    agent = insert(:agent, lga_id: lga.id)

    attrs = %{
      "client_uuid" => Ecto.UUID.generate(),
      "full_name" => "Amaka Obi",
      "phone" => "08031111111",
      "dob" => "1985-04-12",
      "gender" => "female",
      "business_name" => "Amaka Store",
      "business_category" => "Retail",
      "market_id" => market.id,
      "ward_id" => market.ward_id,
      "lga_id" => lga.id,
      "state_id" => state.id,
      "lat" => 6.5,
      "lng" => 3.3
    }

    %{agent: agent, attrs: attrs, market: market, lga: lga, state: state}
  end

  describe "register/3" do
    test "assigns a STATE-LGA-YEAR-SEQUENCE seller_uid", %{
      agent: agent,
      attrs: attrs,
      lga: lga,
      state: state
    } do
      assert {:ok, seller} = Sellers.register(attrs, agent, %{})
      year = DateTime.utc_now().year
      assert seller.seller_uid == "#{state.code}-#{lga.code}-#{year}-000001"
      assert seller.qr_payload == seller.seller_uid
    end

    test "is idempotent on client_uuid: retrying returns the same record, no duplicate insert", %{
      agent: agent,
      attrs: attrs
    } do
      assert {:ok, first} = Sellers.register(attrs, agent, %{})
      assert {:ok, second} = Sellers.register(attrs, agent, %{})

      assert first.id == second.id
      assert RevenueApi.Repo.aggregate(RevenueApi.Sellers.Seller, :count) == 1
    end

    test "a retried sync batch never produces two different seller_uids for the same registration",
         %{
           agent: agent,
           attrs: attrs
         } do
      {:ok, first} = Sellers.register(attrs, agent, %{})
      {:ok, second} = Sellers.register(attrs, agent, %{})
      assert first.seller_uid == second.seller_uid
    end

    test "an agent cannot register a seller outside their own LGA", %{agent: agent, attrs: attrs} do
      other_lga = insert(:lga)
      attrs = Map.put(attrs, "lga_id", other_lga.id)

      assert {:error, :forbidden} = Sellers.register(attrs, agent, %{})
    end

    test "rejects a market/ward/lga/state combination that isn't a real hierarchy", %{
      agent: agent,
      attrs: attrs
    } do
      unrelated_lga = insert(:lga)
      attrs = Map.put(attrs, "lga_id", unrelated_lga.id)
      agent = %{agent | lga_id: unrelated_lga.id}

      assert {:error, :inconsistent_geo_hierarchy} = Sellers.register(attrs, agent, %{})
    end

    test "admin can register into any LGA", %{attrs: attrs} do
      admin = insert(:admin)
      assert {:ok, _seller} = Sellers.register(attrs, admin, %{})
    end

    test "two offline registrations with the same phone are both flagged duplicate_suspected, not merged",
         %{
           agent: agent,
           attrs: attrs
         } do
      {:ok, first} = Sellers.register(attrs, agent, %{})
      refute first.duplicate_suspected

      second_attrs =
        attrs
        |> Map.put("client_uuid", Ecto.UUID.generate())
        |> Map.put("full_name", "Someone Else")

      {:ok, second} = Sellers.register(second_attrs, agent, %{})

      assert second.duplicate_suspected
      assert Sellers.get_seller!(first.id).duplicate_suspected
    end

    test "writes an audit log on registration", %{agent: agent, attrs: attrs} do
      {:ok, seller} = Sellers.register(attrs, agent, %{})
      log = RevenueApi.Repo.get_by!(RevenueApi.Audit.AuditLog, action: "seller_registered")
      assert log.entity_id == to_string(seller.id)
      assert log.user_id == agent.id
    end

    test "a client-supplied photo_url is ignored, not stored verbatim", %{
      agent: agent,
      attrs: attrs
    } do
      attrs = Map.put(attrs, "photo_url", "https://evil.example.com/not-a-real-key")
      {:ok, seller} = Sellers.register(attrs, agent, %{})
      refute seller.photo_url == "https://evil.example.com/not-a-real-key"
      assert seller.photo_url == nil
    end

    test "a valid photo_base64 is stored and photo_url becomes the real storage key", %{
      agent: agent,
      attrs: attrs
    } do
      png = Base.encode64(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0>>)
      attrs = Map.put(attrs, "photo_base64", png)

      {:ok, seller} = Sellers.register(attrs, agent, %{})
      assert String.starts_with?(seller.photo_url, "sellers/photos/")
      assert {:ok, _binary} = RevenueApi.Storage.fetch(seller.photo_url)
    end
  end

  describe "search/2" do
    test "finds by seller_uid, phone, or business name, scoped to the actor's LGA", %{
      agent: agent,
      attrs: attrs
    } do
      {:ok, seller} = Sellers.register(attrs, agent, %{})

      assert [found] = Sellers.search(seller.seller_uid, agent)
      assert found.id == seller.id
      assert [_] = Sellers.search("08031111111", agent)
      assert [_] = Sellers.search("Amaka Store", agent)
      assert [] == Sellers.search("nonexistent-xyz", agent)
    end

    test "an admin (lga_id nil) can search across all LGAs", %{agent: agent, attrs: attrs} do
      {:ok, seller} = Sellers.register(attrs, agent, %{})
      admin = insert(:admin)

      assert [found] = Sellers.search(seller.seller_uid, admin)
      assert found.id == seller.id
    end

    test "a different LGA's agent finds nothing", %{agent: agent, attrs: attrs} do
      {:ok, seller} = Sellers.register(attrs, agent, %{})
      other_agent = insert(:agent)

      assert [] == Sellers.search(seller.seller_uid, other_agent)
    end
  end
end
