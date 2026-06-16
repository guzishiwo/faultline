defmodule FaultlineWeb.UserLive.Settings do
  use FaultlineWeb, :live_view

  alias Faultline.Accounts

  @sudo_minutes -10

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="account-settings-page" class="mx-auto max-w-sm space-y-5">
        <div class="text-center">
          <div class="mx-auto mb-3 flex size-12 items-center justify-center rounded-2xl bg-base-content text-base-100 shadow-sm">
            <.icon name="hero-user-circle" class="size-6" />
          </div>
          <.header>
            Account Settings
            <:subtitle>Manage your account email address and password settings</:subtitle>
          </.header>
        </div>

        <section class="rounded-lg border border-base-300 bg-base-100 p-4 shadow-sm">
          <div class="mb-4">
            <h2 class="text-sm font-semibold text-base-content">Email</h2>
            <p class="mt-1 text-sm text-base-content/65">
              Update where account notifications are sent.
            </p>
          </div>

          <.form
            for={@email_form}
            id="email_form"
            class="space-y-4"
            phx-submit="update_email"
            phx-change="validate_email"
          >
            <.input
              field={@email_form[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              spellcheck="false"
              required
            />
            <.button class={primary_button_class()} phx-disable-with="Changing...">
              Change Email
            </.button>
          </.form>
        </section>

        <section class="rounded-lg border border-base-300 bg-base-100 p-4 shadow-sm">
          <div class="mb-4">
            <h2 class="text-sm font-semibold text-base-content">Password</h2>
            <p class="mt-1 text-sm text-base-content/65">
              Choose a strong password for future logins.
            </p>
          </div>

          <.form
            for={@password_form}
            id="password_form"
            class="space-y-4"
            action={~p"/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
          >
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_user_email"
              spellcheck="false"
              value={@current_email}
            />
            <.input
              field={@password_form[:password]}
              type="password"
              label="New password"
              autocomplete="new-password"
              spellcheck="false"
              required
            />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              autocomplete="new-password"
              spellcheck="false"
            />
            <.button class={primary_button_class()} phx-disable-with="Saving...">
              Save Password
            </.button>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if sudo_mode?(socket) do
      socket =
        case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
          {:ok, _user} ->
            put_flash(socket, :info, "Email changed successfully.")

          {:error, _} ->
            put_flash(socket, :error, "Email change link is invalid or it has expired.")
        end

      {:ok, push_navigate(socket, to: ~p"/users/settings")}
    else
      {:ok, redirect_to_reauthentication(socket)}
    end
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user

    if sudo_mode?(socket) do
      case Accounts.change_user_email(user, user_params) do
        %{valid?: true} = changeset ->
          Accounts.deliver_user_update_email_instructions(
            Ecto.Changeset.apply_action!(changeset, :insert),
            user.email,
            &url(~p"/users/settings/confirm-email/#{&1}")
          )

          info = "A link to confirm your email change has been sent to the new address."
          {:noreply, socket |> put_flash(:info, info)}

        changeset ->
          {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
      end
    else
      {:noreply, redirect_to_reauthentication(socket)}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user

    if sudo_mode?(socket) do
      case Accounts.change_user_password(user, user_params) do
        %{valid?: true} = changeset ->
          {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

        changeset ->
          {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
      end
    else
      {:noreply, redirect_to_reauthentication(socket)}
    end
  end

  defp sudo_mode?(socket) do
    Accounts.sudo_mode?(socket.assigns.current_scope.user, @sudo_minutes)
  end

  defp redirect_to_reauthentication(socket) do
    socket
    |> put_flash(:error, "You must re-authenticate to access this page.")
    |> redirect(to: ~p"/users/log-in")
  end

  defp primary_button_class do
    "inline-flex h-12 w-full items-center justify-center gap-2 rounded-lg bg-base-content px-4 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-base-content/20"
  end
end
