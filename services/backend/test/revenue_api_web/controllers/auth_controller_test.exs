defmodule RevenueApiWeb.AuthControllerTest do
  use RevenueApiWeb.ConnCase, async: true

  import RevenueApi.Factory

  describe "POST /api/v1/auth/login" do
    test "returns tokens for correct credentials", %{conn: conn} do
      insert(:agent,
        email: "login1@example.com",
        password_hash: Argon2.hash_pwd_salt("correct-horse")
      )

      conn =
        post(conn, ~p"/api/v1/auth/login", %{
          identifier: "login1@example.com",
          password: "correct-horse"
        })

      assert %{"access_token" => token, "refresh_token" => refresh, "user" => user} =
               json_response(conn, 200)

      assert is_binary(token)
      assert is_binary(refresh)
      refute Map.has_key?(user, "password_hash")
    end

    test "returns 401 for wrong password", %{conn: conn} do
      insert(:agent,
        email: "login2@example.com",
        password_hash: Argon2.hash_pwd_salt("correct-horse")
      )

      conn =
        post(conn, ~p"/api/v1/auth/login", %{identifier: "login2@example.com", password: "nope"})

      assert json_response(conn, 401)
    end

    test "rate-limits repeated failed attempts for the same identifier", %{conn: _conn} do
      identifier = "ratelimited@example.com"
      insert(:agent, email: identifier, password_hash: Argon2.hash_pwd_salt("correct-horse"))

      responses =
        for _ <- 1..6 do
          conn = build_conn()

          post(conn, ~p"/api/v1/auth/login", %{identifier: identifier, password: "wrong"})
          |> Map.get(:status)
        end

      assert 429 in responses
    end
  end

  describe "POST /api/v1/auth/refresh" do
    test "issues a new pair for a valid refresh token", %{conn: conn} do
      user = insert(:agent)
      {:ok, tokens} = RevenueApi.Accounts.issue_tokens(user)

      conn = post(conn, ~p"/api/v1/auth/refresh", %{refresh_token: tokens.refresh_token})
      assert %{"access_token" => _} = json_response(conn, 200)
    end

    test "returns 401 for an invalid refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/refresh", %{refresh_token: "bogus"})
      assert json_response(conn, 401)
    end
  end

  describe "authenticated routes" do
    test "reject requests with no Authorization header", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/levy-types?lga_id=1")
      assert json_response(conn, 401)
    end
  end
end
