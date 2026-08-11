defmodule RevenueApi.Accounts do
  @moduledoc """
  Users, authentication, and refresh-token lifecycle. See
  specs/mvp_design.md "Feature: Auth" for the access/refresh token policy.
  """

  import Ecto.Query
  alias RevenueApi.Repo
  alias RevenueApi.Accounts.{User, RefreshToken}
  alias RevenueApi.Audit

  @access_ttl {15, :minute}

  def get_active_user(id) do
    Repo.one(from u in User, where: u.id == ^id and u.active == true and is_nil(u.deleted_at))
  rescue
    Ecto.Query.CastError -> nil
  end

  def get_user!(id), do: Repo.get!(User, id)

  def list_users, do: Repo.all(from u in User, where: is_nil(u.deleted_at), order_by: u.name)

  def list_users(lga_id) do
    Repo.all(
      from u in User,
        where: is_nil(u.deleted_at) and u.lga_id == ^lga_id,
        order_by: u.name
    )
  end

  def create_user(attrs, actor, request_context) do
    Repo.transaction(fn ->
      case %User{} |> User.create_changeset(attrs) |> Repo.insert() do
        {:ok, user} ->
          Audit.record!(Audit.base(actor, "user_created", "user", user.id, request_context))
          user

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Verifies `identifier` (email or phone) + `password`. Always runs the
  Argon2 hash check even on a not-found user (against a fixed dummy hash)
  so the response time doesn't leak whether the identifier exists.
  """
  def authenticate_user(identifier, password, request_context) do
    user =
      Repo.one(
        from u in User,
          where:
            (u.email == ^identifier or u.phone == ^identifier) and u.active == true and
              is_nil(u.deleted_at)
      )

    case user do
      nil ->
        Argon2.no_user_verify()
        audit_login_failed(identifier, request_context)
        {:error, :invalid_credentials}

      %User{password_hash: hash} = user ->
        if Argon2.verify_pass(password, hash) do
          {:ok, user}
        else
          audit_login_failed(identifier, request_context, user)
          {:error, :invalid_credentials}
        end
    end
  end

  defp audit_login_failed(identifier, request_context, user \\ nil) do
    Audit.record!(
      Audit.base(user, "login_failed", "user", user && user.id, request_context, %{
        "identifier" => identifier
      })
    )
  end

  @doc "Issues an access token + a fresh rotating refresh token for `user`."
  def issue_tokens(user) do
    {:ok, access_token, _claims} =
      RevenueApi.Guardian.encode_and_sign(user, %{}, ttl: @access_ttl)

    {plaintext_refresh, changeset} = RefreshToken.build(user.id)
    {:ok, _refresh_token} = Repo.insert(changeset)

    {:ok,
     %{
       access_token: access_token,
       refresh_token: plaintext_refresh,
       expires_in: ttl_seconds(@access_ttl),
       user: user
     }}
  end

  @doc """
  Rotating refresh: the presented token is looked up by hash, must be
  valid (not expired/revoked), gets revoked, and a brand new access +
  refresh token pair is issued. A replayed (already-revoked) refresh token
  is rejected outright, bounding the blast radius of a stolen token to a
  single use.
  """
  def refresh(plaintext_token) do
    hash = RefreshToken.hash(plaintext_token)

    with %RefreshToken{} = token <- Repo.get_by(RefreshToken, token_hash: hash),
         true <- RefreshToken.valid?(token),
         %User{} = user <- get_active_user(token.user_id) do
      Repo.update!(RefreshToken.revoke_changeset(token))
      issue_tokens(user)
    else
      _ -> {:error, :invalid_refresh_token}
    end
  end

  def revoke_refresh_token(plaintext_token) do
    hash = RefreshToken.hash(plaintext_token)

    case Repo.get_by(RefreshToken, token_hash: hash) do
      nil -> :ok
      token -> token |> RefreshToken.revoke_changeset() |> Repo.update()
    end

    :ok
  end

  defp ttl_seconds({amount, :minute}), do: amount * 60
  defp ttl_seconds({amount, :day}), do: amount * 86_400
end
