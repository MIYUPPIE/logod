defmodule RevenueApi.Accounts.RefreshToken do
  use Ecto.Schema
  import Ecto.Changeset

  @ttl_days 14

  schema "refresh_tokens" do
    field :token_hash, :string
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :user, RevenueApi.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a fresh opaque token. Returns `{plaintext, changeset}` — the
  plaintext is handed to the client once and never stored; only its SHA-256
  hash is persisted, so a DB leak doesn't hand out usable refresh tokens.
  """
  def build(user_id) do
    plaintext = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    hash = hash(plaintext)

    changeset =
      %__MODULE__{}
      |> cast(
        %{
          user_id: user_id,
          token_hash: hash,
          expires_at:
            DateTime.utc_now() |> DateTime.add(@ttl_days, :day) |> DateTime.truncate(:second)
        },
        [:user_id, :token_hash, :expires_at]
      )
      |> validate_required([:user_id, :token_hash, :expires_at])
      |> foreign_key_constraint(:user_id)

    {plaintext, changeset}
  end

  def hash(plaintext), do: :crypto.hash(:sha256, plaintext) |> Base.encode16(case: :lower)

  def revoke_changeset(refresh_token) do
    change(refresh_token, revoked_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def valid?(%__MODULE__{revoked_at: nil, expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :gt
  end

  def valid?(%__MODULE__{}), do: false
end
