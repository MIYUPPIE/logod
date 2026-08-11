defmodule RevenueApi.RateLimiter do
  @moduledoc """
  Thin wrapper around Hammer for the two SRS §8-mandated limits: login
  brute force and public /verify scraping.
  """

  @login_limit 5
  @login_scale_ms 15 * 60 * 1000
  @verify_limit 30
  @verify_scale_ms 60 * 1000

  def check_login(identifier, ip) do
    Hammer.check_rate("login:#{ip}:#{identifier}", @login_scale_ms, @login_limit)
  end

  def check_verify(ip) do
    Hammer.check_rate("verify:#{ip}", @verify_scale_ms, @verify_limit)
  end
end
