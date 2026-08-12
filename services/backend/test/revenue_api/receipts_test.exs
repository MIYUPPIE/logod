defmodule RevenueApi.ReceiptsTest do
  use RevenueApi.DataCase, async: true

  import RevenueApi.Factory

  alias RevenueApi.Receipts

  test "create_for_payment/1 is idempotent - a payment can only ever have one receipt" do
    payment = insert(:payment)
    assert {:ok, receipt1} = Receipts.create_for_payment(payment)
    assert {:ok, receipt2} = Receipts.create_for_payment(payment)
    assert receipt1.id == receipt2.id
  end

  test "verify/1 returns valid: true for an untampered receipt" do
    payment = insert(:payment)
    {:ok, _receipt} = Receipts.create_for_payment(payment)

    assert {:ok, result} = Receipts.verify(payment.receipt_no)
    assert result.valid
    assert result.receipt_no == payment.receipt_no
    assert Decimal.equal?(result.amount, payment.amount)
  end

  test "verify/1 returns valid: false if the underlying payment was tampered with after issuance" do
    payment = insert(:payment)
    {:ok, _receipt} = Receipts.create_for_payment(payment)

    # Simulate a direct DB edit bypassing the app (the exact scenario the
    # signed hash exists to catch) - bump the amount after the receipt
    # was signed.
    payment
    |> Ecto.Changeset.change(amount: Decimal.add(payment.amount, Decimal.new("500.00")))
    |> RevenueApi.Repo.update!()

    assert {:ok, result} = Receipts.verify(payment.receipt_no)
    refute result.valid
  end

  test "verify/1 returns :not_found for an unknown qr payload" do
    assert {:error, :not_found} = Receipts.verify("RCT-DOES-NOT-EXIST")
  end
end
