defmodule RevenueApi.AuthzTest do
  use RevenueApi.DataCase, async: true

  import RevenueApi.Factory

  alias RevenueApi.Authz

  test "a state-level admin (lga_id nil) is unrestricted" do
    admin = insert(:admin)
    assert Authz.authorize_lga(admin, insert(:lga).id) == :ok
  end

  test "an agent can only access their own LGA" do
    lga = insert(:lga)
    agent = insert(:agent, lga_id: lga.id)

    assert Authz.authorize_lga(agent, lga.id) == :ok
    assert Authz.authorize_lga(agent, insert(:lga).id) == {:error, :forbidden}
  end

  test "a supervisor is scoped the same way an agent is" do
    lga = insert(:lga)
    supervisor = insert(:supervisor, lga_id: lga.id)

    assert Authz.authorize_lga(supervisor, lga.id) == :ok
    assert Authz.authorize_lga(supervisor, insert(:lga).id) == {:error, :forbidden}
  end
end
