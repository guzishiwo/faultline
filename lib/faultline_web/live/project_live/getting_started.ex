defmodule FaultlineWeb.ProjectLive.GettingStarted do
  use FaultlineWeb, :live_view

  alias Faultline.Projects
  alias Faultline.Projects.PlatformGuide

  @impl true
  def mount(params, _session, socket) do
    project = Projects.get_project_by_route_param!(params)
    guide = PlatformGuide.build(project)

    {:ok, assign(socket, project: project, guide: guide)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="project-getting-started-page" class="mx-auto w-full max-w-7xl space-y-6">
        <header class="flex flex-col gap-4 border-b border-base-300 pb-5 lg:flex-row lg:items-start lg:justify-between">
          <div class="min-w-0 space-y-3">
            <.link
              id="back-to-projects-link"
              navigate={~p"/projects"}
              class="inline-flex items-center gap-2 text-sm font-semibold text-base-content/60 transition hover:text-base-content"
            >
              <.icon name="hero-arrow-left" class="size-4" /> Projects
            </.link>
            <div>
              <p class="text-sm font-semibold uppercase tracking-[0.18em] text-primary">
                {@project.name}
              </p>
              <h1 class="mt-2 text-3xl font-semibold tracking-normal text-base-content">
                Set up {@guide.platform_label}
              </h1>
              <p class="mt-2 max-w-2xl text-base leading-7 text-base-content/70">
                Use this DSN and platform-specific SDK snippet to start sending events to Faultline.
              </p>
            </div>
          </div>

          <div class="flex flex-wrap gap-2">
            <.link
              id="project-settings-link"
              navigate={~p"/p/#{@project.slug}/settings"}
              class="inline-flex w-fit items-center gap-2 rounded-lg border border-base-300 px-4 py-2.5 text-sm font-semibold text-base-content/70 transition hover:-translate-y-0.5 hover:bg-base-200 hover:text-base-content"
            >
              Settings <.icon name="hero-cog-6-tooth" class="size-4" />
            </.link>
            <.link
              id="project-issues-link"
              navigate={~p"/issues?project=#{@project.id}"}
              class="inline-flex w-fit items-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
            >
              Open triage <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
        </header>

        <section class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_22rem]">
          <div class="space-y-6">
            <section
              id="getting-started-dsn"
              class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
            >
              <div class="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                <div class="min-w-0">
                  <h2 class="text-lg font-semibold text-base-content">Project DSN</h2>
                  <p class="mt-1 text-sm leading-6 text-base-content/60">
                    This value is unique to {@project.name}. Keep it with the SDK setup for this project.
                  </p>
                </div>
                <.copy_button id="copy-dsn-button" copy={@project.dsn} label="Copy DSN" />
              </div>
              <code
                id="getting-started-dsn-value"
                class="mt-4 block overflow-x-auto rounded-md border border-base-300 bg-base-200 px-3 py-2 font-mono text-xs text-base-content"
              >
                {@project.dsn}
              </code>
            </section>

            <section
              id="getting-started-install"
              class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
            >
              <h2 class="text-lg font-semibold text-base-content">Install</h2>
              <p class="mt-1 text-sm leading-6 text-base-content/60">
                Add the Sentry-compatible SDK package for {@guide.platform_label}.
              </p>

              <div
                :if={@guide.install == []}
                class="mt-4 rounded-lg border border-dashed border-base-300 p-4 text-sm text-base-content/60"
              >
                Pick a concrete platform later to get package-manager specific install commands.
              </div>

              <div :if={@guide.install != []} class="mt-4 grid gap-3">
                <.command_panel
                  :for={install <- @guide.install}
                  id={"install-command-#{install.label}"}
                  label={install.label}
                  command={install.command}
                />
              </div>
            </section>

            <section
              id="getting-started-configure"
              class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
            >
              <div class="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                <div>
                  <h2 class="text-lg font-semibold text-base-content">Configure SDK</h2>
                  <p class="mt-1 text-sm leading-6 text-base-content/60">
                    Add this near application startup so events include the project DSN.
                  </p>
                </div>
                <.copy_button
                  id="copy-configure-button"
                  copy={@guide.configure_code}
                  label="Copy config"
                />
              </div>

              <.code_panel
                id="configure-sdk-code"
                title={@guide.configure_title}
                language={@guide.configure_language}
                code={@guide.configure_code}
              />
            </section>
          </div>

          <aside class="h-fit space-y-4 rounded-lg border border-base-300 bg-base-200/70 p-5 text-sm leading-6 text-base-content/70">
            <div>
              <p class="font-semibold text-base-content">Platform</p>
              <p id="getting-started-platform" class="mt-2 text-2xl font-semibold text-base-content">
                {@guide.platform_label}
              </p>
            </div>

            <div class="border-t border-base-300 pt-4">
              <p class="font-semibold text-base-content">Next step</p>
              <p class="mt-2">{@guide.note}</p>
            </div>

            <.link
              :if={@guide.docs_url}
              id="platform-docs-link"
              href={@guide.docs_url}
              target="_blank"
              class="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-base-300 bg-base-100 px-4 py-2.5 text-sm font-semibold text-base-content/70 transition hover:bg-base-200 hover:text-base-content"
            >
              Platform docs <.icon name="hero-arrow-top-right-on-square" class="size-4" />
            </.link>
          </aside>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :copy, :string, required: true
  attr :label, :string, required: true

  defp copy_button(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      phx-hook="ClipboardCopy"
      phx-update="ignore"
      data-copy={@copy}
      class="inline-flex w-fit shrink-0 items-center gap-2 rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm font-semibold text-base-content/70 transition hover:-translate-y-0.5 hover:bg-base-200 hover:text-base-content"
    >
      <.icon name="hero-clipboard-document" class="size-4" />
      <span data-copy-label>{@label}</span>
    </button>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :command, :string, required: true

  defp command_panel(assigns) do
    ~H"""
    <div id={@id} class="overflow-hidden rounded-lg border border-base-300 bg-zinc-950 text-zinc-100">
      <div class="flex items-center justify-between border-b border-white/10 px-4 py-2">
        <p class="font-mono text-sm font-semibold text-zinc-300">{@label}</p>
        <.copy_button id={"copy-#{@id}"} copy={@command} label="Copy" />
      </div>
      <pre class="overflow-x-auto px-4 py-3 text-sm"><code
          id={"#{@id}-code"}
          phx-hook="CodeHighlight"
          phx-update="ignore"
          data-prism-language="bash"
          class="font-mono"
        >{@command}</code></pre>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :language, :string, required: true
  attr :code, :string, required: true

  defp code_panel(assigns) do
    ~H"""
    <div class="mt-4 overflow-hidden rounded-lg border border-base-300 bg-zinc-950 text-zinc-100">
      <div class="border-b border-white/10 px-4 py-2">
        <p class="font-mono text-sm font-semibold text-zinc-300">{@title}</p>
      </div>
      <pre class="overflow-x-auto px-4 py-4 text-sm leading-6"><code
          id={@id}
          phx-hook="CodeHighlight"
          phx-update="ignore"
          data-prism-language={@language}
          class="font-mono"
        >{String.trim(@code)}</code></pre>
    </div>
    """
  end
end
