defmodule RevenueApiWeb.LoggerFilterTest do
  # async: false - this mutates the global Logger level for the duration
  # of the test, which would race other tests' log output if run
  # concurrently.
  use RevenueApiWeb.ConnCase, async: false
  import ExUnit.CaptureLog

  @moduledoc """
  SRS §8: "Passwords: argon2, never logged." Phoenix logs `Parameters:
  %{...}` at :debug level, and filters nothing by default
  (`filter_parameters` defaults to an empty list) - without the
  `config :phoenix, :filter_parameters` entry in config/config.exs, the
  raw password would show up verbatim in that line. Deliberately
  black-box (a real request against a real logger, not a direct call
  into Phoenix.Logger's internals) so this verifies actually-observed
  behavior. Note `ExUnit.CaptureLog`'s own `:level` option only filters
  what capture_log *keeps*; it does not raise the application's
  configured minimum level (config/test.exs sets :warning), so :debug
  messages never reach any handler unless the global level is raised
  for real - hence `Logger.configure/1` here instead of relying on
  capture_log's option alone.
  """

  test "a raw password sent to /auth/login never appears in the request log", %{conn: conn} do
    secret = "this-exact-string-must-never-appear-in-logs"
    original_level = Logger.level()
    Logger.configure(level: :debug)

    log =
      capture_log(fn ->
        post(conn, ~p"/api/v1/auth/login", %{identifier: "nobody@example.com", password: secret})
      end)

    Logger.configure(level: original_level)

    refute log =~ secret
    assert log =~ "[FILTERED]"
  end
end
