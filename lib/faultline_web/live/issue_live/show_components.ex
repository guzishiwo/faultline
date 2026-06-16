defmodule FaultlineWeb.IssueLive.ShowComponents do
  @moduledoc false

  use FaultlineWeb, :html

  alias FaultlineWeb.IssueLive.EventDetail

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :open, :boolean, default: true
  attr :border, :boolean, default: true
  slot :inner_block, required: true

  def collapsible_section(assigns) do
    ~H"""
    <details
      id={@id}
      open={@open}
      class={[
        "group",
        @border && "border-t border-base-300 pt-5",
        !@border && "pt-0"
      ]}
    >
      <summary
        id={"#{@id}-summary"}
        class="flex cursor-pointer list-none items-center justify-between gap-3 text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50 transition hover:text-base-content [&::-webkit-details-marker]:hidden"
      >
        <span>{@title}</span>
        <.icon name="hero-chevron-right" class="size-4 shrink-0 transition group-open:rotate-90" />
      </summary>
      <div class="mt-4">
        {render_slot(@inner_block)}
      </div>
    </details>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, default: nil

  def kv(assigns) do
    ~H"""
    <div class="min-w-0">
      <dt class="text-base-content/50">{@label}</dt>
      <dd class="mt-1 break-words text-base-content">{@value || "-"}</dd>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :values, :map, required: true

  def map_section(assigns) do
    ~H"""
    <section>
      <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
        {@title}
      </h3>
      <div class="mt-2 grid gap-1 text-sm">
        <p :if={map_size(@values) == 0} class="text-base-content/50">None</p>
        <div :for={{key, value} <- @values} class="grid grid-cols-[7rem_minmax(0,1fr)] gap-2">
          <span class="break-words text-base-content/50">{key}</span>
          <span class="break-words text-base-content">{EventDetail.format_detail(value)}</span>
        </div>
      </div>
    </section>
    """
  end

  attr :contexts, :map, required: true

  def context_cards(assigns) do
    assigns = assign(assigns, :visible_contexts, EventDetail.visible_contexts(assigns.contexts))

    ~H"""
    <section id="event-contexts" class="lg:col-span-2">
      <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
        Contexts
      </h3>
      <div class="mt-2 grid gap-3 lg:grid-cols-2">
        <p :if={@visible_contexts == []} class="text-sm text-base-content/50">None</p>
        <article
          :for={{name, values} <- @visible_contexts}
          id={"event-context-#{name}"}
          class="rounded-lg border border-base-300 bg-base-200/50 p-3"
        >
          <h4 class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-base-content/50">
            {name}
          </h4>
          <dl class="mt-2 grid gap-1 text-sm">
            <div :for={{key, value} <- values} class="grid grid-cols-[7rem_minmax(0,1fr)] gap-2">
              <dt class="break-words text-base-content/50">{key}</dt>
              <dd class="break-words text-base-content">
                {EventDetail.format_context_detail(key, value)}
              </dd>
            </div>
          </dl>
        </article>
      </div>
    </section>
    """
  end

  attr :values, :map, required: true

  def modules(assigns) do
    assigns = assign(assigns, :modules, sorted_take(assigns.values, 12))

    ~H"""
    <section id="event-modules">
      <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
        Modules
      </h3>
      <div class="mt-2 grid gap-1 text-sm">
        <p :if={@modules == []} class="text-base-content/50">None</p>
        <div :for={{name, version} <- @modules} class="grid grid-cols-[minmax(0,1fr)_7rem] gap-2">
          <span class="truncate font-mono text-xs text-base-content/70">{name}</span>
          <span class="truncate text-right font-mono text-xs text-base-content/50">{version}</span>
        </div>
      </div>
    </section>
    """
  end

  attr :frames, :list, required: true
  attr :event_id, :string, required: true

  def stacktrace(assigns) do
    ~H"""
    <div class="stacktrace-list overflow-hidden rounded-lg border border-base-300 bg-base-200/60">
      <p :if={@frames == []} class="p-3 text-sm text-base-content/50">No frames</p>
      <div
        :for={{frame, index} <- Enum.with_index(Enum.reverse(@frames), 1)}
        id={"stack-frame-#{index}"}
        class="grid gap-3 border-b border-base-300 px-3 py-3 last:border-b-0 md:grid-cols-[2.5rem_minmax(0,1fr)]"
      >
        <div class="font-mono text-xs text-base-content/40 md:pt-1">
          #{index}
        </div>
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-2">
            <p class="break-words font-mono text-sm font-semibold text-base-content">
              {frame["function"] || frame["module"] || "anonymous"}
            </p>
            <span
              :if={frame["in_app"]}
              class="rounded border border-error/20 bg-error/10 px-1.5 py-0.5 text-[0.65rem] font-semibold uppercase tracking-[0.12em] text-error"
            >
              app
            </span>
          </div>
          <p class="mt-1 break-words font-mono text-xs leading-5 text-base-content/55">
            {EventDetail.frame_location(frame)}
          </p>
          <.frame_source frame={frame} index={index} event_id={@event_id} />
          <.frame_vars frame={frame} index={index} />
        </div>
      </div>
    </div>
    """
  end

  attr :values, :list, required: true

  def breadcrumbs(assigns) do
    ~H"""
    <div class="space-y-1">
      <p :if={@values == []} class="text-sm text-base-content/50">No breadcrumbs</p>
      <div :for={breadcrumb <- @values} class="rounded-md bg-base-200 px-3 py-2 text-xs">
        <p class="font-semibold text-base-content">{breadcrumb["category"] || "breadcrumb"}</p>
        <p class="text-base-content/60">{breadcrumb["message"] || inspect(breadcrumb)}</p>
      </div>
    </div>
    """
  end

  attr :frame, :map, required: true
  attr :index, :integer, required: true
  attr :event_id, :string, required: true

  defp frame_source(assigns) do
    assigns =
      assigns
      |> assign(:lines, EventDetail.frame_source_lines(assigns.frame))
      |> assign(:language, EventDetail.frame_language(assigns.frame))

    ~H"""
    <div
      :if={@lines != []}
      id={"stack-frame-#{@index}-source"}
      class="mt-3 overflow-x-auto rounded-lg border border-base-300 bg-base-100"
    >
      <div
        :for={line <- @lines}
        id={"stack-frame-#{@index}-source-line-#{line.id}"}
        class={[
          "grid grid-cols-[3.5rem_minmax(0,1fr)] font-mono text-xs leading-6",
          line.current? && "bg-primary/10 text-base-content",
          !line.current? && "text-base-content/65"
        ]}
      >
        <span class="select-none border-r border-base-300 px-3 text-right text-base-content/40">
          {line.number}
        </span>
        <code
          id={"stack-frame-#{@event_id}-#{@index}-source-line-#{line.id}-code"}
          phx-hook={if(@language, do: "CodeHighlight")}
          phx-update={if(@language, do: "ignore")}
          data-prism-language={@language}
          class={["min-w-max whitespace-pre px-3", @language && "language-#{@language}"]}
        >{line.source}</code>
      </div>
    </div>
    """
  end

  attr :frame, :map, required: true
  attr :index, :integer, required: true

  defp frame_vars(assigns) do
    assigns = assign(assigns, :vars, EventDetail.frame_var_pairs(assigns.frame))

    ~H"""
    <div
      :if={@vars != []}
      id={"stack-frame-#{@index}-vars"}
      class="mt-3 overflow-hidden rounded-lg border border-base-300 bg-base-100"
    >
      <div
        :for={{name, value} <- @vars}
        id={"stack-frame-#{@index}-var-#{EventDetail.dom_id_part(name)}"}
        class="grid border-b border-base-300 text-xs last:border-b-0 sm:grid-cols-[10rem_minmax(0,1fr)]"
      >
        <span class="border-b border-base-300 px-3 py-2 font-mono font-semibold text-base-content/70 sm:border-b-0 sm:border-r">
          {name}
        </span>
        <code class="break-words px-3 py-2 font-mono text-base-content/65">
          {EventDetail.format_detail(value)}
        </code>
      </div>
    </div>
    """
  end

  defp sorted_take(values, count) when is_map(values) do
    values
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> sorted_take(count)
  end

  defp sorted_take(values, count) when is_list(values) do
    values
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.take(count)
  end

  defp sorted_take(_values, _count), do: []
end
