defmodule RevenueApi.ReceiptPdf do
  @moduledoc """
  Renders a payment receipt to PDF via headless Chrome (ChromicPDF).

  Every field sourced from user input (seller name, business name, etc.)
  is HTML-escaped before interpolation. ChromicPDF renders full HTML+JS in
  a real browser engine, so unescaped input here would be an HTML/script
  injection into a document our own headless Chrome executes — a
  meaningfully different, easier-to-miss risk than ordinary server-rendered
  page XSS, not merely a formatting nicety.
  """

  alias RevenueApi.Payments.Payment
  alias RevenueApi.Receipts.Receipt

  @spec render(Payment.t(), Receipt.t()) :: {:ok, binary()} | {:error, term()}
  def render(%Payment{} = payment, %Receipt{} = receipt) do
    payment = RevenueApi.Repo.preload(payment, [:seller, :levy_type, :agent])
    qr_svg = receipt.qr_payload |> EQRCode.encode() |> EQRCode.svg(width: 160)

    html = build_html(payment, receipt, qr_svg)

    case ChromicPDF.print_to_pdf({:html, html}) do
      {:ok, base64} -> {:ok, Base.decode64!(base64)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_html(payment, receipt, qr_svg) do
    e = &esc/1

    """
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, Helvetica, Arial, sans-serif; padding: 32px; color: #1a1a1a; }
          h1 { font-size: 20px; margin-bottom: 4px; }
          .muted { color: #666; font-size: 12px; }
          table { width: 100%; border-collapse: collapse; margin-top: 24px; }
          td { padding: 8px 0; border-bottom: 1px solid #eee; font-size: 14px; }
          td.label { color: #666; width: 40%; }
          .qr { margin-top: 24px; text-align: center; }
          .hash { font-family: monospace; font-size: 10px; color: #999; word-break: break-all; margin-top: 16px; }
        </style>
      </head>
      <body>
        <h1>Levy Payment Receipt</h1>
        <div class="muted">Receipt No: #{e.(payment.receipt_no)}</div>
        <table>
          <tr><td class="label">Seller</td><td>#{e.(payment.seller.full_name)} (#{e.(payment.seller.seller_uid)})</td></tr>
          <tr><td class="label">Business</td><td>#{e.(payment.seller.business_name)}</td></tr>
          <tr><td class="label">Levy Type</td><td>#{e.(payment.levy_type.name)}</td></tr>
          <tr><td class="label">Amount</td><td>NGN #{e.(Decimal.to_string(payment.amount))}</td></tr>
          <tr><td class="label">Method</td><td>#{e.(to_string(payment.method))}</td></tr>
          <tr><td class="label">Collected By</td><td>#{e.(payment.agent.name)}</td></tr>
          <tr><td class="label">Date</td><td>#{e.(DateTime.to_string(payment.paid_at))}</td></tr>
        </table>
        <div class="qr">#{qr_svg}</div>
        <div class="hash">Verification: #{e.(receipt.verification_url)}<br>Hash: #{e.(receipt.signed_hash)}</div>
      </body>
    </html>
    """
  end

  defp esc(nil), do: ""

  defp esc(value) do
    value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end
end
