defmodule FaultlineWeb.ProjectLive.New do
  use FaultlineWeb, :live_view

  alias Faultline.Projects
  alias Faultline.Projects.Project

  @default_platform_category "popular"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:platform_categories, Projects.project_platform_categories())
     |> assign(:platforms, Projects.project_platforms())
     |> assign(:platform_category, @default_platform_category)
     |> assign(:platform_query, "")
     |> assign_form(Projects.change_project(%Project{}))}
  end

  @impl true
  def handle_event("validate", params, socket) do
    project_params = Map.get(params, "project", %{})

    form =
      %Project{}
      |> Projects.change_project(project_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign_platform_query(params)
     |> assign_form(form)}
  end

  def handle_event("save", %{"project" => project_params}, socket) do
    case Projects.create_project(project_params, dsn_base_url: FaultlineWeb.Endpoint.url()) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{project.name} is ready for SDK events.")
         |> push_navigate(to: ~p"/p/#{project.slug}/platform/getting-started")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("set_platform_category", %{"category" => category}, socket) do
    category =
      if Enum.any?(socket.assigns.platform_categories, &(&1.id == category)) do
        category
      else
        @default_platform_category
      end

    {:noreply, assign(socket, :platform_category, category)}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :visible_platforms, visible_platforms(assigns))

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto grid w-full max-w-7xl gap-8 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <section class="space-y-6">
          <.link
            id="back-to-projects-link"
            navigate={~p"/projects"}
            class="inline-flex items-center gap-2 text-sm font-semibold text-base-content/60 transition hover:text-base-content"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Projects
          </.link>

          <div class="space-y-3">
            <p class="text-sm font-semibold uppercase tracking-[0.18em] text-primary">
              New project
            </p>
            <h1 class="text-4xl font-semibold tracking-normal text-base-content sm:text-5xl">
              Generate a DSN for a platform.
            </h1>
            <p class="max-w-2xl text-base leading-7 text-base-content/70">
              Pick the SDK platform, name the service, and set the first ingest limits. Faultline generates the public key, secret key, and DSN.
            </p>
          </div>

          <.form
            for={@form}
            id="project-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-5 rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
          >
            <section id="project-platform-picker" class="space-y-4">
              <div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_20rem] lg:items-start">
                <div class="pt-1">
                  <p class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/55">
                    1. Choose your platform
                  </p>
                  <p class="mt-1 text-sm text-base-content/60">
                    The platform is saved with the project and can drive SDK onboarding.
                  </p>
                </div>

                <div class="w-full">
                  <.input
                    id="platform-filter-input"
                    name="platform_query"
                    type="search"
                    label="Filter platforms"
                    value={@platform_query}
                    placeholder="Filter platforms"
                    phx-debounce="200"
                    class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/20"
                  />
                </div>
              </div>

              <div
                id="platform-category-tabs"
                class="flex gap-1 overflow-x-auto border-b border-base-300"
              >
                <button
                  :for={category <- @platform_categories}
                  id={"platform-category-#{category.id}"}
                  type="button"
                  phx-click="set_platform_category"
                  phx-value-category={category.id}
                  class={[
                    "shrink-0 border-b-2 px-3 py-2 text-sm font-semibold transition",
                    @platform_category == category.id &&
                      "border-primary text-primary",
                    @platform_category != category.id &&
                      "border-transparent text-base-content/55 hover:text-base-content"
                  ]}
                >
                  {category.label}
                </button>
              </div>

              <.input field={@form[:platform]} type="hidden" />

              <div
                id="platform-options"
                class="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-3"
              >
                <label
                  :for={platform <- @visible_platforms}
                  id={"platform-option-#{platform.id}"}
                  class={[
                    "group relative flex min-h-20 cursor-pointer items-center gap-3 rounded-lg border p-3 text-left transition",
                    @selected_platform == platform.id &&
                      "border-primary bg-primary/10 ring-2 ring-primary/15 dark:bg-primary/10",
                    @selected_platform != platform.id &&
                      "border-base-300 bg-base-100 hover:border-base-content/25 hover:bg-base-200/50"
                  ]}
                >
                  <input
                    type="radio"
                    id={"project_platform_#{platform.id}"}
                    name={@form[:platform].name}
                    value={platform.id}
                    checked={@selected_platform == platform.id}
                    class="sr-only"
                  />
                  <span class={[
                    "flex size-12 shrink-0 items-center justify-center rounded-lg text-base font-black tracking-normal shadow-sm ring-1 ring-black/5 transition group-hover:scale-105",
                    platform_tone_class(platform.id)
                  ]}>
                    {platform.mark}
                  </span>
                  <span class="min-w-0 flex-1">
                    <span class="block truncate text-sm font-semibold text-base-content">
                      {platform.name}
                    </span>
                    <span
                      :if={platform.badge}
                      class={[
                        "mt-1 inline-flex rounded px-1.5 py-0.5 text-[0.65rem] font-black leading-none",
                        platform_badge_class(platform.badge)
                      ]}
                    >
                      {platform.badge}
                    </span>
                    <span
                      :if={!platform.badge}
                      class="mt-1 block text-xs capitalize text-base-content/45"
                    >
                      {platform.category}
                    </span>
                  </span>
                  <span
                    :if={@selected_platform == platform.id}
                    class="flex size-6 shrink-0 items-center justify-center rounded-full bg-primary text-primary-content"
                  >
                    <.icon name="hero-check-mini" class="size-4" />
                  </span>
                </label>

                <div
                  :if={@visible_platforms == []}
                  id="platform-options-empty"
                  class="col-span-full rounded-lg border border-dashed border-base-300 px-4 py-8 text-center text-sm text-base-content/60"
                >
                  No platforms match this filter.
                </div>
              </div>

              <p
                :for={error <- @form[:platform].errors}
                class="flex items-center gap-2 text-sm text-error"
              >
                <.icon name="hero-exclamation-circle" class="size-5" />
                {translate_error(error)}
              </p>
            </section>

            <div class="border-t border-base-300 pt-5">
              <p class="mb-4 text-sm font-semibold uppercase tracking-[0.14em] text-base-content/55">
                2. Project details
              </p>

              <.input
                field={@form[:name]}
                type="text"
                label="Project name"
                placeholder="Web checkout"
                required
              />

              <div class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={@form[:rate_limit_max_events]}
                  type="number"
                  label="Max events"
                  min="1"
                  max="1000000"
                  required
                />
                <.input
                  field={@form[:rate_limit_window_seconds]}
                  type="number"
                  label="Window seconds"
                  min="1"
                  max="86400"
                  required
                />
              </div>
            </div>

            <div class="flex items-center justify-end gap-3 pt-2">
              <.link
                id="cancel-project-link"
                navigate={~p"/projects"}
                class="rounded-lg px-4 py-2.5 text-sm font-semibold text-base-content/60 transition hover:bg-base-200 hover:text-base-content"
              >
                Cancel
              </.link>
              <button
                id="save-project-button"
                type="submit"
                class="inline-flex items-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
              >
                <.icon name="hero-key" class="size-4" /> Create project
              </button>
            </div>
          </.form>
        </section>

        <aside class="rounded-lg border border-base-300 bg-base-200/70 p-5 text-sm leading-6 text-base-content/70 lg:mt-40">
          <p class="font-semibold text-base-content">Selected platform</p>
          <p id="selected-platform-label" class="mt-2 text-2xl font-semibold text-base-content">
            {Projects.project_platform_label(@selected_platform)}
          </p>
          <p class="mt-3">
            SDK setup instructions can use this value after project creation.
          </p>

          <div class="my-5 border-t border-base-300"></div>

          <p class="font-semibold text-base-content">DSN shape</p>
          <code class="mt-3 block overflow-x-auto rounded-md border border-base-300 bg-base-100 px-3 py-2 font-mono text-xs">
            https://public:secret@example.com/123
          </code>
          <p class="mt-4">
            The numeric path becomes the project id used by Sentry SDK ingest endpoints.
          </p>
        </aside>
      </div>
    </Layouts.app>
    """
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset)

    socket
    |> assign(:form, form)
    |> assign(
      :selected_platform,
      Phoenix.HTML.Form.input_value(form, :platform) || Project.default_platform()
    )
  end

  defp assign_platform_query(socket, params) do
    assign(
      socket,
      :platform_query,
      Map.get(params, "platform_query", socket.assigns.platform_query)
    )
  end

  defp visible_platforms(assigns) do
    assigns.platforms
    |> filter_by_category(assigns.platform_category)
    |> filter_by_query(assigns.platform_query)
  end

  defp filter_by_category(platforms, "all"), do: platforms

  defp filter_by_category(platforms, "popular") do
    Enum.filter(platforms, & &1.popular?)
  end

  defp filter_by_category(platforms, category) do
    Enum.filter(platforms, &(&1.category == category))
  end

  defp filter_by_query(platforms, query) when query in [nil, ""], do: platforms

  defp filter_by_query(platforms, query) do
    query = String.downcase(query)

    Enum.filter(platforms, fn platform ->
      platform.name
      |> String.downcase()
      |> String.contains?(query)
    end)
  end

  defp platform_badge_class("JS"), do: "bg-yellow-300 text-zinc-950"
  defp platform_badge_class("PY"), do: "bg-blue-600 text-white"
  defp platform_badge_class("PHP"), do: "bg-indigo-600 text-white"
  defp platform_badge_class("RB"), do: "bg-red-700 text-white"
  defp platform_badge_class("JV"), do: "bg-green-700 text-white"
  defp platform_badge_class(".NET"), do: "bg-violet-600 text-white"
  defp platform_badge_class(_badge), do: "bg-base-300 text-base-content"

  defp platform_tone_class("nextjs"), do: "bg-zinc-950 text-white"
  defp platform_tone_class("other"), do: "bg-base-content text-base-100"
  defp platform_tone_class("react"), do: "bg-cyan-950 text-cyan-200"
  defp platform_tone_class("react_native"), do: "bg-sky-600 text-white"
  defp platform_tone_class("nodejs"), do: "bg-zinc-800 text-lime-400"
  defp platform_tone_class("laravel"), do: "bg-red-600 text-white"
  defp platform_tone_class("fastapi"), do: "bg-emerald-600 text-white"
  defp platform_tone_class("flutter"), do: "bg-sky-500 text-white"
  defp platform_tone_class("django"), do: "bg-emerald-950 text-white"
  defp platform_tone_class("python"), do: "bg-blue-700 text-yellow-300"
  defp platform_tone_class("express"), do: "bg-zinc-950 text-white"
  defp platform_tone_class("browser_javascript"), do: "bg-yellow-300 text-zinc-950"
  defp platform_tone_class("php"), do: "bg-indigo-600 text-white"
  defp platform_tone_class("rails"), do: "bg-red-700 text-white"
  defp platform_tone_class("ios"), do: "bg-zinc-950 text-white"
  defp platform_tone_class("nestjs"), do: "bg-rose-600 text-white"
  defp platform_tone_class("flask"), do: "bg-cyan-700 text-white"
  defp platform_tone_class("vue"), do: "bg-emerald-500 text-white"
  defp platform_tone_class("aspnet_core"), do: "bg-violet-600 text-white"
  defp platform_tone_class("nuxt"), do: "bg-zinc-950 text-emerald-300"
  defp platform_tone_class("dotnet_maui"), do: "bg-violet-600 text-white"
  defp platform_tone_class("angular"), do: "bg-fuchsia-600 text-white"
  defp platform_tone_class("android"), do: "bg-green-600 text-white"
  defp platform_tone_class("spring_boot"), do: "bg-green-700 text-white"
  defp platform_tone_class("symfony"), do: "bg-zinc-950 text-white"
  defp platform_tone_class("cloudflare_workers"), do: "bg-orange-500 text-white"
  defp platform_tone_class("electron"), do: "bg-slate-800 text-cyan-200"
  defp platform_tone_class("unity"), do: "bg-zinc-950 text-white"
  defp platform_tone_class("remix"), do: "bg-zinc-900 text-white"
  defp platform_tone_class(_platform_id), do: "bg-base-300 text-base-content"
end
