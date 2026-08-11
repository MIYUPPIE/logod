defmodule RevenueApi.Notifier do
  @moduledoc """
  Swappable SMS gateway boundary (SRS §9 open decision, resolved to Termii
  — see specs/mvp_design.md). `RevenueApi.Notifier.Termii` is the prod
  adapter; `Console` (dev) and the Mox-based mock (test) never touch the
  network, so the whole app runs with zero SMS credentials outside prod.
  """

  @callback send_sms(phone :: String.t(), message :: String.t()) ::
              {:ok, provider_ref :: String.t()} | {:error, term()}

  def impl, do: Application.fetch_env!(:revenue_api, :notifier)

  def send_sms(phone, message), do: impl().send_sms(phone, message)
end
