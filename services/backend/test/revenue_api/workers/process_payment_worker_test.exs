defmodule RevenueApi.Workers.ProcessPaymentWorkerTest do
  use RevenueApi.DataCase, async: false
  use Oban.Testing, repo: RevenueApi.Repo

  import RevenueApi.Factory
  import Mox

  alias RevenueApi.Workers.ProcessPaymentWorker
  alias RevenueApi.{Receipts, Repo}

  setup :verify_on_exit!

  test "creates a receipt, renders + stores a PDF, and sends the confirmation SMS" do
    payment = insert(:payment)

    expect(RevenueApi.NotifierMock, :send_sms, fn phone, message ->
      assert phone == Repo.get!(RevenueApi.Sellers.Seller, payment.seller_id).phone
      assert message =~ payment.receipt_no
      {:ok, "mock-ref-1"}
    end)

    assert :ok = perform_job(ProcessPaymentWorker, %{"payment_id" => payment.id})

    receipt = Receipts.get_by_payment_id(payment.id)
    assert receipt
    assert receipt.pdf_url
    assert {:ok, pdf_binary} = RevenueApi.Storage.fetch(receipt.pdf_url)
    assert String.starts_with?(pdf_binary, "%PDF")

    sms_log = Repo.get_by!(RevenueApi.Notifications.SmsLog, payment_id: payment.id)
    assert sms_log.status == "sent"
    assert sms_log.provider_ref == "mock-ref-1"
  end

  test "still logs the sms_logs row (as failed) when the notifier errors, and the job reports the failure" do
    payment = insert(:payment)

    expect(RevenueApi.NotifierMock, :send_sms, fn _phone, _message -> {:error, :timeout} end)

    assert {:error, :timeout} = perform_job(ProcessPaymentWorker, %{"payment_id" => payment.id})

    sms_log = Repo.get_by!(RevenueApi.Notifications.SmsLog, payment_id: payment.id)
    assert sms_log.status == "failed"
  end

  test "running the job twice does not create a second receipt or re-render the PDF" do
    payment = insert(:payment)
    stub(RevenueApi.NotifierMock, :send_sms, fn _phone, _message -> {:ok, "ref"} end)

    assert :ok = perform_job(ProcessPaymentWorker, %{"payment_id" => payment.id})
    receipt_after_first = Receipts.get_by_payment_id(payment.id)

    assert :ok = perform_job(ProcessPaymentWorker, %{"payment_id" => payment.id})
    receipt_after_second = Receipts.get_by_payment_id(payment.id)

    assert receipt_after_first.id == receipt_after_second.id
    assert Repo.aggregate(RevenueApi.Receipts.Receipt, :count) == 1
  end
end
