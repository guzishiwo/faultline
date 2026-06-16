defmodule FaultlineWeb.UserLive.Confirmation do
  use FaultlineWeb, :live_view

  alias Faultline.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-5">
        <div class="text-center">
          <.header>Welcome {@user.email}</.header>
        </div>

        <.form
          :if={!@user.confirmed_at}
          for={@form}
          id="confirmation_form"
          phx-mounted={JS.focus_first()}
          phx-submit="submit"
          action={~p"/users/log-in?_action=confirmed"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <.button
            id="confirm-stay-logged-in"
            name={@form[:remember_me].name}
            value="true"
            phx-disable-with="Confirming..."
            class={primary_button_class()}
          >
            Confirm and stay logged in
          </.button>
          <.button
            id="confirm-once"
            phx-disable-with="Confirming..."
            class={secondary_button_class()}
          >
            Confirm and log in only this time
          </.button>
        </.form>

        <.form
          :if={@user.confirmed_at}
          for={@form}
          id="login_form"
          phx-submit="submit"
          phx-mounted={JS.focus_first()}
          action={~p"/users/log-in"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <%= if @current_scope do %>
            <.button
              id="login-token-submit"
              phx-disable-with="Logging in..."
              class={primary_button_class()}
            >
              Log in
            </.button>
          <% else %>
            <.button
              id="login-token-stay-logged-in"
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Logging in..."
              class={primary_button_class()}
            >
              Keep me logged in on this device
            </.button>
            <.button
              id="login-token-once"
              phx-disable-with="Logging in..."
              class={secondary_button_class()}
            >
              Log me in only this time
            </.button>
          <% end %>
        </.form>

        <p
          :if={!@user.confirmed_at}
          class="rounded-lg border border-base-300 bg-base-100 px-4 py-3 text-sm text-base-content/70 shadow-sm"
        >
          Tip: If you prefer passwords, you can enable them in the user settings.
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end

  defp primary_button_class do
    "inline-flex h-12 w-full items-center justify-center gap-2 rounded-lg bg-base-content px-4 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-base-content/20"
  end

  defp secondary_button_class do
    "mt-2 inline-flex h-12 w-full items-center justify-center rounded-lg border border-base-300 bg-base-100 px-4 text-sm font-semibold text-base-content shadow-sm transition hover:-translate-y-0.5 hover:bg-base-200/70 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-base-content/20"
  end
end
