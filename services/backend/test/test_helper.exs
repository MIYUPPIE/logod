ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(RevenueApi.Repo, :manual)

Mox.defmock(RevenueApi.NotifierMock, for: RevenueApi.Notifier)
Mox.stub_with(RevenueApi.NotifierMock, RevenueApi.Notifier.Console)
