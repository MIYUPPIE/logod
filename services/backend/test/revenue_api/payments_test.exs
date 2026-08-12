defmodule RevenueApi.PaymentsTest do
  use RevenueApi.DataCase, async: true
  use Oban.Testing, repo: RevenueApi.Repo

  import RevenueApi.Factory

  alias RevenueApi.Payments

  setup do
    seller = insert(:seller)
    agent = RevenueApi.Repo.get!(RevenueApi.Accounts.User, seller.registered_by_user_id)
    levy_type = insert(:levy_type, lga_id: seller.lga_id, amount: Decimal.new("2500.00"))

    attrs = %{
      "client_uuid" => Ecto.UUID.generate(),
      "seller_id" => seller.id,
      "levy_type_id" => levy_type.id,
      "method" => "cash",
      "paid_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    %{seller: seller, agent: agent, levy_type: levy_type, attrs: attrs}
  end

  describe "create/3" do
    test "resolves amount from the levy type server-side, ignoring any client-supplied amount", %{
      agent: agent,
      attrs: attrs,
      levy_type: levy_type
    } do
      attrs_with_forged_amount = Map.put(attrs, "amount", "1.00")

      assert {:ok, payment} = Payments.create(attrs_with_forged_amount, agent, %{})
      assert Decimal.equal?(payment.amount, levy_type.amount)
      refute Decimal.equal?(payment.amount, Decimal.new("1.00"))
    end

    test "is idempotent on client_uuid: a retried sync never double-charges", %{
      agent: agent,
      attrs: attrs
    } do
      assert {:ok, first} = Payments.create(attrs, agent, %{})
      assert {:ok, second} = Payments.create(attrs, agent, %{})

      assert first.id == second.id
      assert RevenueApi.Repo.aggregate(RevenueApi.Payments.Payment, :count) == 1
    end

    test "generates a unique receipt_no per payment", %{agent: agent, attrs: attrs} do
      {:ok, p1} = Payments.create(attrs, agent, %{})
      {:ok, p2} = Payments.create(Map.put(attrs, "client_uuid", Ecto.UUID.generate()), agent, %{})

      assert p1.receipt_no != p2.receipt_no
    end

    test "an agent cannot record a payment for a seller outside their LGA", %{attrs: attrs} do
      other_agent = insert(:agent)
      assert {:error, :forbidden} = Payments.create(attrs, other_agent, %{})
    end

    test "rejects a levy_type_id that doesn't belong to the seller's LGA", %{
      agent: agent,
      attrs: attrs
    } do
      other_levy_type = insert(:levy_type)
      attrs = Map.put(attrs, "levy_type_id", other_levy_type.id)

      assert {:error, :levy_type_not_found} = Payments.create(attrs, agent, %{})
    end

    test "rejects an unknown seller_id", %{agent: agent, attrs: attrs} do
      attrs = Map.put(attrs, "seller_id", 999_999)
      assert {:error, :seller_not_found} = Payments.create(attrs, agent, %{})
    end

    test "enqueues a ProcessPaymentWorker job", %{agent: agent, attrs: attrs} do
      {:ok, payment} = Payments.create(attrs, agent, %{})

      assert_enqueued(
        worker: RevenueApi.Workers.ProcessPaymentWorker,
        args: %{"payment_id" => payment.id}
      )
    end

    test "writes an audit log", %{agent: agent, attrs: attrs} do
      {:ok, payment} = Payments.create(attrs, agent, %{})
      log = RevenueApi.Repo.get_by!(RevenueApi.Audit.AuditLog, action: "payment_recorded")
      assert log.entity_id == to_string(payment.id)
    end
  end
end
