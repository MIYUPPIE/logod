defmodule RevenueApiWeb.LiveUserAuth do
  @moduledoc """
  on_mount hook for the browser (session-cookie) LiveViews — Supervisor
  Dashboard and Admin panel. Separate from RevenueApiWeb.AuthPipeline,
  which gates the JWT-based mobile API; LiveView sockets don't go through
  the HTTP router's plug pipeline after the initial mount, so the role
  check has to happen here too (see specs/mvp_design.md "Security" note
  under Supervisor Dashboard / Admin Panel).
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView

  alias RevenueApi.Accounts

  def on_mount({:ensure_role, allowed_roles}, _params, session, socket) do
    user = session["user_id"] && Accounts.get_active_user(session["user_id"])

    if user && user.role in allowed_roles do
      {:cont, assign(socket, :current_user, user)}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must sign in to access this page.")
       |> redirect(to: "/login")}
    end
  end
end
