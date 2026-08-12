defmodule RevenueApi.AccountsTest do
  use RevenueApi.DataCase, async: true

  import RevenueApi.Factory

  alias RevenueApi.Accounts

  describe "authenticate_user/3" do
    test "succeeds with correct email + password" do
      user =
        insert(:agent,
          email: "auth1@example.com",
          password_hash: Argon2.hash_pwd_salt("correct-horse")
        )

      assert {:ok, authenticated} =
               Accounts.authenticate_user("auth1@example.com", "correct-horse", %{})

      assert authenticated.id == user.id
    end

    test "fails with wrong password and does not leak which part was wrong" do
      insert(:agent,
        email: "auth2@example.com",
        password_hash: Argon2.hash_pwd_salt("correct-horse")
      )

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("auth2@example.com", "wrong-password", %{})
    end

    test "fails for an identifier that does not exist, same error as wrong password" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("nobody@example.com", "whatever", %{})
    end

    test "fails for a deactivated user even with correct password" do
      insert(:agent,
        email: "auth3@example.com",
        password_hash: Argon2.hash_pwd_salt("pw"),
        active: false
      )

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("auth3@example.com", "pw", %{})
    end

    test "a failed login writes an audit_logs row" do
      insert(:agent, email: "auth4@example.com", password_hash: Argon2.hash_pwd_salt("pw"))
      Accounts.authenticate_user("auth4@example.com", "wrong", %{ip: "1.2.3.4"})

      log = RevenueApi.Repo.one!(RevenueApi.Audit.AuditLog)
      assert log.action == "login_failed"
      assert log.ip == "1.2.3.4"
    end
  end

  describe "issue_tokens/1 and refresh/1" do
    test "issues a working access token and a rotating refresh token" do
      user = insert(:agent)
      assert {:ok, tokens} = Accounts.issue_tokens(user)
      assert {:ok, %{"sub" => sub}} = RevenueApi.Guardian.decode_and_verify(tokens.access_token)
      assert sub == to_string(user.id)
      assert is_binary(tokens.refresh_token)
    end

    test "refresh with a valid token issues a new pair and invalidates the old refresh token" do
      user = insert(:agent)
      {:ok, tokens} = Accounts.issue_tokens(user)

      assert {:ok, new_tokens} = Accounts.refresh(tokens.refresh_token)
      assert new_tokens.access_token != tokens.access_token
      assert new_tokens.refresh_token != tokens.refresh_token

      # replaying the original (now-revoked) refresh token must fail
      assert {:error, :invalid_refresh_token} = Accounts.refresh(tokens.refresh_token)
    end

    test "refresh with a bogus token fails" do
      assert {:error, :invalid_refresh_token} = Accounts.refresh("not-a-real-token")
    end

    test "revoke_refresh_token prevents future use" do
      user = insert(:agent)
      {:ok, tokens} = Accounts.issue_tokens(user)

      :ok = Accounts.revoke_refresh_token(tokens.refresh_token)
      assert {:error, :invalid_refresh_token} = Accounts.refresh(tokens.refresh_token)
    end
  end

  describe "create_user/3" do
    test "hashes the password and never stores it raw" do
      admin = insert(:admin)
      lga = insert(:lga)

      assert {:ok, user} =
               Accounts.create_user(
                 %{
                   name: "New Agent",
                   email: "newagent@example.com",
                   password: "supersecret1",
                   role: "agent",
                   lga_id: lga.id
                 },
                 admin,
                 %{}
               )

      assert user.password_hash != "supersecret1"
      assert Argon2.verify_pass("supersecret1", user.password_hash)
    end

    test "writes an audit log" do
      admin = insert(:admin)

      {:ok, user} =
        Accounts.create_user(
          %{name: "X", email: "x@example.com", password: "supersecret1", role: "agent"},
          admin,
          %{}
        )

      log = RevenueApi.Repo.get_by!(RevenueApi.Audit.AuditLog, action: "user_created")
      assert log.entity_id == to_string(user.id)
    end

    test "rejects a short password" do
      admin = insert(:admin)

      assert {:error, changeset} =
               Accounts.create_user(
                 %{name: "X", email: "y@example.com", password: "short", role: "agent"},
                 admin,
                 %{}
               )

      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end
  end
end
