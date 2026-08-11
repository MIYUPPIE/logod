defmodule RevenueApi.Notifier.Termii do
  @moduledoc "Prod adapter: Termii's SMS API (https://developers.termii.com/sms-api)."
  @behaviour RevenueApi.Notifier

  @impl true
  def send_sms(phone, message) do
    config = Application.fetch_env!(:revenue_api, :termii)
    api_key = config[:api_key] || raise "TERMII_API_KEY is not configured"

    body = %{
      to: phone,
      from: config[:sender_id],
      sms: message,
      type: "plain",
      channel: "generic",
      api_key: api_key
    }

    case Req.post("#{config[:base_url]}/api/sms/send", json: body) do
      {:ok, %{status: 200, body: %{"message_id" => ref}}} ->
        {:ok, ref}

      {:ok, %{status: 200, body: body}} ->
        {:error, {:unexpected_response, body}}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
