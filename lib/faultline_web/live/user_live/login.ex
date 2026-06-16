defmodule FaultlineWeb.UserLive.Login do
  use FaultlineWeb, :live_view

  alias Faultline.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-5">
        <div class="text-center">
          <.header>
            <p>Log in</p>
            <:subtitle>
              <%= if @current_scope do %>
                You need to reauthenticate to perform sensitive actions on your account.
              <% else %>
                Don't have an account? <.link
                  navigate={~p"/users/register"}
                  class="font-semibold text-primary hover:underline"
                  phx-no-format
                >Sign up</.link> for an account now.
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <div
          :if={local_mail_adapter?()}
          id="local-mail-adapter-notice"
          class="flex items-start gap-3 rounded-lg border border-base-300 bg-base-100 px-4 py-3 text-sm text-base-content/70 shadow-sm"
        >
          <.icon name="hero-information-circle" class="mt-0.5 size-5 shrink-0 text-base-content/45" />
          <div>
            <p class="font-semibold text-base-content">You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link
                href="/dev/mailbox"
                class="font-semibold text-base-content underline underline-offset-4"
              >the mailbox page</.link>.
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.button id="login-magic-submit" class={primary_button_class()}>
            Log in with email <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div class="divider">or</div>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
            spellcheck="false"
          />
          <.button
            id="login-password-submit"
            class={primary_button_class()}
            name={@form[:remember_me].name}
            value="true"
          >
            Log in and stay logged in <span aria-hidden="true">→</span>
          </.button>
          <.button id="login-once-submit" class={secondary_button_class()}>
            Log in only this time
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:faultline, Faultline.Mailer)[:adapter] == Swoosh.Adapters.Local
  end

  defp primary_button_class do
    "inline-flex h-12 w-full items-center justify-center gap-2 rounded-lg bg-base-content px-4 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-base-content/20"
  end

  defp secondary_button_class do
    "mt-2 inline-flex h-12 w-full items-center justify-center rounded-lg border border-base-300 bg-base-100 px-4 text-sm font-semibold text-base-content shadow-sm transition hover:-translate-y-0.5 hover:bg-base-200/70 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-base-content/20"
  end
end
