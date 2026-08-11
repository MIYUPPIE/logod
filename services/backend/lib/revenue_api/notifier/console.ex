defmodule RevenueApi.Notifier.Console do
  @moduledoc "Dev adapter: logs the SMS instead of sending it. No network calls."
  @behaviour RevenueApi.Notifier

  require Logger

  @impl true
  def send_sms(phone, message) do
    Logger.info("[SMS -> #{phone}] #{message}")
    {:ok, "console-#{System.unique_integer([:positive])}"}
  end
end
