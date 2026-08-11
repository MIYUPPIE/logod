defmodule RevenueApiWeb.AuthJSON do
  def tokens(%{tokens: tokens}) do
    %{
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_in: tokens.expires_in,
      user: RevenueApiWeb.UserJSON.data(tokens.user)
    }
  end
end
