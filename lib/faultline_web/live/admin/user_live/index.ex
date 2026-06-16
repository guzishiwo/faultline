defmodule FaultlineWeb.Admin.UserLive.Index do
  use FaultlineWeb, :live_view

  alias Faultline.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:admin_count, Accounts.count_admins())
     |> stream(:users, Accounts.list_users())}
  end

  @impl true
  def handle_event("set-role", %{"id" => id, "role" => role}, socket)
      when role in ["admin", "member"] do
    user = Accounts.get_user!(id)

    if last_admin_demotion?(user, role, socket.assigns.admin_count) do
      {:noreply, put_flash(socket, :error, "Faultline needs at least one admin user.")}
    else
      case Accounts.update_user_role(user, %{role: role}) do
        {:ok, user} ->
          {:noreply,
           socket
           |> assign(:admin_count, Accounts.count_admins())
           |> stream_insert(:users, user)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Could not update the user role.")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="w-full space-y-8">
        <section class="grid gap-5 lg:grid-cols-[minmax(0,1fr)_16rem] lg:items-end">
          <div class="space-y-3">
            <p class="text-sm font-semibold uppercase tracking-[0.18em] text-primary">
              Admin
            </p>
            <h1 class="text-4xl font-semibold tracking-normal text-base-content sm:text-5xl">
              User access control.
            </h1>
            <p class="max-w-2xl text-base leading-7 text-base-content/70">
              Promote trusted operators to admin and keep regular users scoped to project triage workflows.
            </p>
          </div>

          <div class="rounded-lg border border-base-300 bg-base-200/70 p-4">
            <p class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
              Admin users
            </p>
            <p id="admin-count" class="mt-2 text-3xl font-semibold">{@admin_count}</p>
          </div>
        </section>

        <section class="overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm">
          <div class="grid grid-cols-[minmax(0,1fr)_7rem_8rem_13rem] gap-4 border-b border-base-300 px-5 py-3 text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
            <span>User</span>
            <span>Role</span>
            <span>Status</span>
            <span>Controls</span>
          </div>

          <div id="admin-users" phx-update="stream" class="divide-y divide-base-300">
            <div id="admin-users-empty-state" class="hidden px-5 py-12 text-center only:block">
              No users yet
            </div>

            <article
              :for={{id, user} <- @streams.users}
              id={id}
              class="grid grid-cols-[minmax(0,1fr)_7rem_8rem_13rem] items-center gap-4 px-5 py-4 text-sm"
            >
              <div class="min-w-0">
                <p class="truncate font-semibold text-base-content">{user.email}</p>
                <p class="mt-1 text-xs text-base-content/50">id: {user.id}</p>
              </div>

              <span
                id={"user-role-#{user.id}"}
                class={[
                  "w-fit rounded-md px-2 py-1 text-xs font-semibold",
                  user.role == "admin" && "bg-primary/10 text-primary",
                  user.role == "member" && "bg-base-200 text-base-content/70"
                ]}
              >
                {user.role}
              </span>

              <span class="text-base-content/70">
                {if user.confirmed_at, do: "confirmed", else: "pending"}
              </span>

              <div class="flex flex-wrap gap-2">
                <button
                  id={"make-admin-#{user.id}"}
                  type="button"
                  phx-click="set-role"
                  phx-value-id={user.id}
                  phx-value-role="admin"
                  disabled={user.role == "admin"}
                  class="rounded-lg border border-base-300 px-3 py-1.5 text-xs font-semibold transition hover:bg-base-200 disabled:cursor-not-allowed disabled:opacity-40"
                >
                  Make admin
                </button>
                <button
                  id={"make-member-#{user.id}"}
                  type="button"
                  phx-click="set-role"
                  phx-value-id={user.id}
                  phx-value-role="member"
                  disabled={user.role == "member"}
                  class="rounded-lg border border-base-300 px-3 py-1.5 text-xs font-semibold transition hover:bg-base-200 disabled:cursor-not-allowed disabled:opacity-40"
                >
                  Make member
                </button>
              </div>
            </article>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp last_admin_demotion?(user, "member", 1), do: Accounts.admin?(user)
  defp last_admin_demotion?(_user, _role, _admin_count), do: false
end
