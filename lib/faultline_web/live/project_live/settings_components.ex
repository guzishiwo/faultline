defmodule FaultlineWeb.ProjectLive.SettingsComponents do
  use FaultlineWeb, :html

  attr :project, :map, required: true
  attr :settings_tabs, :list, required: true
  attr :active_tab, :string, required: true

  def settings_tabs(assigns) do
    ~H"""
    <nav
      id="project-settings-tabs"
      class="flex gap-2 overflow-x-auto border-b border-base-300"
      aria-label="Project settings sections"
    >
      <.link
        :for={tab <- @settings_tabs}
        id={"settings-tab-#{tab.id}"}
        patch={~p"/p/#{@project.slug}/settings?tab=#{tab.id}"}
        aria-current={if(@active_tab == tab.id, do: "page", else: "false")}
        class={[
          "inline-flex shrink-0 items-center gap-2 border-b-2 px-3 py-3 text-sm font-semibold transition",
          @active_tab == tab.id && "border-primary text-base-content",
          @active_tab != tab.id &&
            "border-transparent text-base-content/55 hover:border-base-300 hover:text-base-content"
        ]}
      >
        <.icon name={tab.icon} class="size-4" /> {tab.label}
      </.link>
    </nav>
    """
  end

  attr :project, :map, required: true
  attr :current_scope, :map, default: nil

  def sdk_tab(assigns) do
    ~H"""
    <section id="project-sdk-tab" class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_22rem]">
      <section
        id="project-sdk-settings"
        class="overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm"
      >
        <div class="border-b border-base-300 bg-base-200/30 px-5 py-4">
          <div class="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
            <div class="min-w-0">
              <p class="text-xs font-semibold uppercase tracking-[0.18em] text-primary">
                Primary setup value
              </p>
              <h2 class="mt-2 text-xl font-semibold text-base-content">SDK DSN</h2>
              <p class="mt-1 max-w-2xl text-sm leading-6 text-base-content/60">
                Use this endpoint in the SDK configuration for {@project.name}.
              </p>
            </div>
            <.copy_button id="copy-project-dsn-button" copy={@project.dsn} label="Copy DSN" />
          </div>
        </div>

        <div class="p-5">
          <div class="flex items-start gap-3">
            <div class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
              <.icon name="hero-key" class="size-5" />
            </div>
            <code
              id="project-dsn"
              class="block min-w-0 flex-1 overflow-x-auto rounded-md border border-base-300 bg-base-200 px-3 py-2.5 font-mono text-xs text-base-content"
            >
              {@project.dsn}
            </code>
          </div>
        </div>
      </section>

      <aside
        id="project-sdk-domain-card"
        class="h-fit space-y-4 rounded-lg border border-base-300 bg-base-200/70 p-5 text-sm leading-6 text-base-content/70"
      >
        <div>
          <p class="font-semibold text-base-content">Public ingest origin</p>
          <p id="project-sdk-dsn-origin" class="mt-2 break-all font-mono text-xs">
            {dsn_origin(@project.dsn)}
          </p>
        </div>
        <p>
          This origin is embedded in the project DSN. Configure it before creating production projects, or regenerate project DSNs after changing domains.
        </p>
        <.link
          :if={admin_scope?(@current_scope)}
          id="project-sdk-admin-settings-link"
          navigate={~p"/admin/settings"}
          class="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-base-300 bg-base-100 px-4 py-2.5 text-sm font-semibold text-base-content/70 transition hover:bg-base-200 hover:text-base-content"
        >
          <.icon name="hero-cog-6-tooth" class="size-4" /> Instance settings
        </.link>
      </aside>
    </section>
    """
  end

  attr :project, :map, required: true
  attr :project_form, :any, required: true

  def ingest_tab(assigns) do
    ~H"""
    <section id="project-ingest-tab" class="grid gap-6 xl:grid-cols-[22rem_minmax(0,1fr)]">
      <section
        id="project-ingest-settings"
        class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
      >
        <div class="flex items-start gap-3">
          <div class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-base-200 text-base-content/70">
            <.icon name="hero-bolt" class="size-5" />
          </div>
          <div>
            <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
              Ingest limit
            </h2>
            <p class="mt-3 text-3xl font-semibold text-base-content">
              {@project.rate_limit_max_events}
            </p>
            <p class="text-sm text-base-content/60">
              events per {@project.rate_limit_window_seconds}s
            </p>
          </div>
        </div>

        <dl class="mt-5 grid grid-cols-2 gap-3 border-t border-base-300 pt-4">
          <div>
            <dt class="text-xs font-semibold uppercase tracking-[0.12em] text-base-content/45">
              Retention
            </dt>
            <dd class="mt-1 font-semibold text-base-content">{@project.retention_days} days</dd>
          </div>
          <div>
            <dt class="text-xs font-semibold uppercase tracking-[0.12em] text-base-content/45">
              Event cap
            </dt>
            <dd class="mt-1 font-semibold text-base-content">
              {@project.retention_event_limit}
            </dd>
          </div>
        </dl>
      </section>

      <section
        id="project-cost-controls"
        class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
      >
        <div class="flex items-start gap-3">
          <div class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-base-200 text-base-content/70">
            <.icon name="hero-circle-stack" class="size-5" />
          </div>
          <div>
            <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
              Cost controls
            </h2>
            <p class="mt-1 text-sm leading-6 text-base-content/60">
              Tune intake and retention without changing SDK setup.
            </p>
          </div>
        </div>

        <.form
          for={@project_form}
          id="project-cost-controls-form"
          phx-change="validate_project_settings"
          phx-submit="save_project_settings"
          class="mt-5 grid gap-4 sm:grid-cols-2"
        >
          <.input
            field={@project_form[:rate_limit_max_events]}
            type="number"
            label="Rate limit events"
            min="1"
            max="1000000"
            required
          />
          <.input
            field={@project_form[:rate_limit_window_seconds]}
            type="number"
            label="Rate limit window seconds"
            min="1"
            max="86400"
            required
          />
          <.input
            field={@project_form[:retention_days]}
            type="number"
            label="Retention days"
            min="1"
            max="3650"
            required
          />
          <.input
            field={@project_form[:retention_event_limit]}
            type="number"
            label="Event retention cap"
            min="1"
            max="10000000"
            required
          />
          <button
            id="save-project-cost-controls-button"
            type="submit"
            class="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md sm:col-span-2"
          >
            <.icon name="hero-circle-stack" class="size-4" /> Save cost controls
          </button>
        </.form>
      </section>
    </section>
    """
  end

  attr :alert_rule_count, :integer, required: true
  attr :drop_rule_count, :integer, required: true
  attr :alert_rules, :any, required: true
  attr :drop_rules, :any, required: true
  attr :rule_builder, :any, required: true
  attr :editing_rule, :any, required: true
  attr :form, :any, required: true
  attr :drop_form, :any, required: true
  attr :notify_on_options, :list, required: true
  attr :channel_options, :list, required: true
  attr :drop_rule_field_options, :list, required: true
  attr :drop_rule_type_options, :list, required: true

  def rules_workspace(assigns) do
    ~H"""
    <div id="project-rules-tab" class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_24rem]">
      <section id="project-policy-settings" class="space-y-5">
        <.rules_workspace_header
          alert_rule_count={@alert_rule_count}
          drop_rule_count={@drop_rule_count}
        />
        <.alert_rules_panel alert_rules={@alert_rules} />
        <.drop_rules_panel drop_rules={@drop_rules} />
      </section>

      <.rule_builder
        rule_builder={@rule_builder}
        editing_rule={@editing_rule}
        form={@form}
        drop_form={@drop_form}
        notify_on_options={@notify_on_options}
        channel_options={@channel_options}
        drop_rule_field_options={@drop_rule_field_options}
        drop_rule_type_options={@drop_rule_type_options}
      />
    </div>
    """
  end

  attr :alert_rule_count, :integer, required: true
  attr :drop_rule_count, :integer, required: true

  def rules_workspace_header(assigns) do
    ~H"""
    <section
      id="rules-workspace-header"
      class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
    >
      <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div class="min-w-0">
          <p class="text-xs font-semibold uppercase tracking-[0.18em] text-primary">
            Rule workspace
          </p>
          <h2 class="mt-2 text-xl font-semibold text-base-content">Rules</h2>
          <p class="mt-1 text-sm leading-6 text-base-content/60">
            Control what gets stored and where alerts are delivered.
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <button
            id="new-alert-rule-button"
            type="button"
            phx-click="show_rule_builder"
            phx-value-type="alert"
            class="inline-flex items-center justify-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
          >
            <.icon name="hero-bell-alert" class="size-4" /> New alert rule
          </button>
          <button
            id="new-drop-rule-button"
            type="button"
            phx-click="show_rule_builder"
            phx-value-type="drop"
            class="inline-flex items-center justify-center gap-2 rounded-lg border border-base-300 px-4 py-2.5 text-sm font-semibold text-base-content/70 transition hover:-translate-y-0.5 hover:bg-base-200 hover:text-base-content"
          >
            <.icon name="hero-no-symbol" class="size-4" /> New drop rule
          </button>
        </div>
      </div>
      <dl class="mt-5 grid gap-3 border-t border-base-300 pt-4 sm:grid-cols-2">
        <div class="rounded-lg bg-base-200/60 px-4 py-3">
          <dt class="text-xs font-semibold uppercase tracking-[0.12em] text-base-content/45">
            Alert rules
          </dt>
          <dd class="mt-1 text-2xl font-semibold text-base-content">
            {@alert_rule_count}
          </dd>
        </div>
        <div class="rounded-lg bg-base-200/60 px-4 py-3">
          <dt class="text-xs font-semibold uppercase tracking-[0.12em] text-base-content/45">
            Drop rules
          </dt>
          <dd class="mt-1 text-2xl font-semibold text-base-content">
            {@drop_rule_count}
          </dd>
        </div>
      </dl>
    </section>
    """
  end

  attr :alert_rules, :any, required: true

  def alert_rules_panel(assigns) do
    ~H"""
    <section
      id="project-alert-settings"
      class="overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm"
    >
      <div class="border-b border-base-300 px-5 py-4">
        <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
          Alert rules
        </h2>
      </div>

      <div id="alert-rules" phx-update="stream" class="divide-y divide-base-300">
        <div
          id="alert-rules-empty-state"
          class="hidden items-center justify-between gap-4 px-5 py-6 only:flex"
        >
          <div class="flex min-w-0 items-center gap-3">
            <div class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
              <.icon name="hero-bell-alert" class="size-5" />
            </div>
            <div class="min-w-0">
              <p class="font-semibold text-base-content">No alert rules yet</p>
              <p class="mt-1 text-sm leading-6 text-base-content/60">
                Notify your team when this project receives new or regressed issues.
              </p>
            </div>
          </div>
          <button
            id="empty-alert-rules-create-button"
            type="button"
            phx-click="show_rule_builder"
            phx-value-type="alert"
            class="inline-flex shrink-0 items-center gap-2 rounded-lg border border-base-300 px-3 py-2 text-sm font-semibold text-base-content/70 transition hover:bg-base-200 hover:text-base-content"
          >
            <.icon name="hero-bell-alert" class="size-4" /> Create
          </button>
        </div>

        <article
          :for={{id, rule} <- @alert_rules}
          id={id}
          class="grid gap-4 px-5 py-5 lg:grid-cols-[minmax(0,1fr)_12rem]"
        >
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <p class="font-semibold text-base-content">{rule.name}</p>
              <span class={[
                "rounded border px-2 py-0.5 text-xs font-semibold",
                rule.enabled && "border-success/20 bg-success/10 text-success",
                !rule.enabled && "border-base-300 bg-base-200 text-base-content/50"
              ]}>
                {if(rule.enabled, do: "enabled", else: "disabled")}
              </span>
            </div>

            <dl class="mt-3 grid gap-2 text-sm sm:grid-cols-2">
              <.rule_kv label="Trigger" value={trigger_label(rule.notify_on)} />
              <.rule_kv label="Channel" value={channel_label(rule.channel)} />
              <.rule_kv label="Target" value={rule.target} />
              <.rule_kv label="Cooldown" value={"#{rule.cooldown_seconds}s"} />
              <.rule_kv label="Threshold" value={Integer.to_string(rule.threshold_count)} />
            </dl>
          </div>

          <div class="flex flex-wrap items-start gap-2 lg:justify-end">
            <button
              id={"toggle-alert-rule-#{rule.id}"}
              type="button"
              phx-click="toggle"
              phx-value-id={rule.id}
              class="inline-flex items-center gap-1 rounded-lg border border-base-300 px-3 py-2 text-sm font-semibold text-base-content/70 transition hover:bg-base-200 hover:text-base-content"
            >
              <.icon
                name={if(rule.enabled, do: "hero-pause", else: "hero-play")}
                class="size-4"
              /> {if(rule.enabled, do: "Disable", else: "Enable")}
            </button>
            <button
              id={"edit-alert-rule-#{rule.id}"}
              type="button"
              phx-click="edit"
              phx-value-id={rule.id}
              class="inline-flex items-center gap-1 rounded-lg border border-base-300 px-3 py-2 text-sm font-semibold text-base-content/70 transition hover:bg-base-200 hover:text-base-content"
            >
              <.icon name="hero-pencil-square" class="size-4" /> Edit
            </button>
            <button
              id={"delete-alert-rule-#{rule.id}"}
              type="button"
              phx-click="delete"
              phx-value-id={rule.id}
              data-confirm="Delete this alert rule?"
              class="inline-flex items-center gap-1 rounded-lg border border-error/20 px-3 py-2 text-sm font-semibold text-error transition hover:bg-error/10"
            >
              <.icon name="hero-trash" class="size-4" /> Delete
            </button>
          </div>
        </article>
      </div>
    </section>
    """
  end

  attr :drop_rules, :any, required: true

  def drop_rules_panel(assigns) do
    ~H"""
    <section
      id="project-drop-settings"
      class="overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm"
    >
      <div class="border-b border-base-300 px-5 py-4">
        <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
          Drop rules
        </h2>
      </div>
      <div id="drop-rules" phx-update="stream" class="divide-y divide-base-300">
        <div
          id="drop-rules-empty-state"
          class="hidden items-center justify-between gap-4 px-5 py-6 only:flex"
        >
          <div>
            <p class="font-semibold text-base-content">No drop rules yet</p>
            <p class="mt-1 text-sm text-base-content/60">
              Drop noisy classes before they consume storage.
            </p>
          </div>
          <button
            id="empty-drop-rules-create-button"
            type="button"
            phx-click="show_rule_builder"
            phx-value-type="drop"
            class="inline-flex shrink-0 items-center gap-2 rounded-lg border border-base-300 px-3 py-2 text-sm font-semibold text-base-content/70 transition hover:bg-base-200 hover:text-base-content"
          >
            <.icon name="hero-no-symbol" class="size-4" /> Create
          </button>
        </div>
        <article
          :for={{id, drop_rule} <- @drop_rules}
          id={id}
          class="grid gap-4 px-5 py-4 md:grid-cols-[minmax(0,1fr)_12rem]"
        >
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <p class="font-semibold text-base-content">{drop_rule.name}</p>
              <span class={[
                "rounded border px-2 py-0.5 text-xs font-semibold",
                drop_rule.enabled && "border-success/20 bg-success/10 text-success",
                !drop_rule.enabled && "border-base-300 bg-base-200 text-base-content/50"
              ]}>
                {if(drop_rule.enabled, do: "enabled", else: "disabled")}
              </span>
            </div>
            <p class="mt-2 font-mono text-xs text-base-content/60">
              {drop_rule.match_field} {drop_rule.match_type} "{drop_rule.match_value}"
            </p>
          </div>
          <div class="flex flex-wrap gap-2 md:justify-end">
            <button
              id={"toggle-drop-rule-#{drop_rule.id}"}
              type="button"
              phx-click="toggle_drop_rule"
              phx-value-id={drop_rule.id}
              class="inline-flex items-center gap-1 rounded-lg border border-base-300 px-3 py-2 text-sm font-semibold text-base-content/70 transition hover:bg-base-200 hover:text-base-content"
            >
              <.icon
                name={if(drop_rule.enabled, do: "hero-pause", else: "hero-play")}
                class="size-4"
              /> {if(drop_rule.enabled, do: "Disable", else: "Enable")}
            </button>
            <button
              id={"delete-drop-rule-#{drop_rule.id}"}
              type="button"
              phx-click="delete_drop_rule"
              phx-value-id={drop_rule.id}
              data-confirm="Delete this drop rule?"
              class="inline-flex items-center gap-1 rounded-lg border border-error/20 px-3 py-2 text-sm font-semibold text-error transition hover:bg-error/10"
            >
              <.icon name="hero-trash" class="size-4" /> Delete
            </button>
          </div>
        </article>
      </div>
    </section>
    """
  end

  attr :rule_builder, :any, required: true
  attr :editing_rule, :any, required: true
  attr :form, :any, required: true
  attr :drop_form, :any, required: true
  attr :notify_on_options, :list, required: true
  attr :channel_options, :list, required: true
  attr :drop_rule_field_options, :list, required: true
  attr :drop_rule_type_options, :list, required: true

  def rule_builder(assigns) do
    ~H"""
    <aside id="project-rule-builder" class="xl:sticky xl:top-6 xl:self-start">
      <section
        :if={@rule_builder == nil}
        id="rule-builder-empty-state"
        class="rounded-lg border border-dashed border-base-300 bg-base-100 p-5 shadow-sm"
      >
        <div class="flex size-10 items-center justify-center rounded-lg bg-base-200 text-base-content/65">
          <.icon name="hero-wrench-screwdriver" class="size-5" />
        </div>
        <h2 class="mt-4 text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
          Rule builder
        </h2>
        <p class="mt-2 text-sm leading-6 text-base-content/60">
          Choose a rule type to configure storage filtering or alert delivery.
        </p>
        <div class="mt-5 grid gap-2">
          <button
            id="empty-new-alert-rule-button"
            type="button"
            phx-click="show_rule_builder"
            phx-value-type="alert"
            class="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
          >
            <.icon name="hero-bell-alert" class="size-4" /> New alert rule
          </button>
          <button
            id="empty-new-drop-rule-button"
            type="button"
            phx-click="show_rule_builder"
            phx-value-type="drop"
            class="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-base-300 px-4 py-2.5 text-sm font-semibold text-base-content/70 transition hover:-translate-y-0.5 hover:bg-base-200 hover:text-base-content"
          >
            <.icon name="hero-no-symbol" class="size-4" /> New drop rule
          </button>
        </div>
        <div class="mt-5 rounded-lg bg-base-200/60 p-4 text-sm leading-6 text-base-content/60">
          Alert channels are isolated behind the channel selector, so Feishu and DingTalk can be added without changing this page structure.
        </div>
      </section>

      <.drop_rule_form_panel
        :if={@rule_builder == "drop"}
        drop_form={@drop_form}
        drop_rule_field_options={@drop_rule_field_options}
        drop_rule_type_options={@drop_rule_type_options}
      />

      <.alert_rule_form_panel
        :if={@rule_builder == "alert"}
        form={@form}
        editing_rule={@editing_rule}
        notify_on_options={@notify_on_options}
        channel_options={@channel_options}
      />
    </aside>
    """
  end

  attr :drop_form, :any, required: true
  attr :drop_rule_field_options, :list, required: true
  attr :drop_rule_type_options, :list, required: true

  def drop_rule_form_panel(assigns) do
    ~H"""
    <section
      id="project-drop-rule-form-panel"
      class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
    >
      <div class="flex items-start justify-between gap-3">
        <div>
          <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
            Create drop rule
          </h2>
          <p class="mt-1 text-sm leading-6 text-base-content/60">
            Reject noisy events before they are stored.
          </p>
        </div>
        <button
          id="cancel-drop-rule-builder"
          type="button"
          phx-click="clear_rule_builder"
          class="rounded-lg px-2 py-1 text-sm font-semibold text-base-content/60 transition hover:bg-base-200 hover:text-base-content"
        >
          Cancel
        </button>
      </div>
      <.form
        for={@drop_form}
        id="drop-rule-form"
        phx-change="validate_drop_rule"
        phx-submit="save_drop_rule"
        class="mt-5 space-y-4"
      >
        <.input field={@drop_form[:name]} type="text" label="Name" required />
        <.input field={@drop_form[:enabled]} type="checkbox" label="Enabled" />
        <.input
          field={@drop_form[:match_field]}
          type="select"
          label="Field"
          options={@drop_rule_field_options}
          required
        />
        <.input
          field={@drop_form[:match_type]}
          type="select"
          label="Match"
          options={@drop_rule_type_options}
          required
        />
        <.input field={@drop_form[:match_value]} type="text" label="Value" required />
        <button
          id="save-drop-rule-button"
          type="submit"
          class="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
        >
          <.icon name="hero-no-symbol" class="size-4" /> Create drop rule
        </button>
      </.form>
    </section>
    """
  end

  attr :form, :any, required: true
  attr :editing_rule, :any, required: true
  attr :notify_on_options, :list, required: true
  attr :channel_options, :list, required: true

  def alert_rule_form_panel(assigns) do
    ~H"""
    <section class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm">
      <div class="flex items-start justify-between gap-3">
        <div>
          <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
            {if(@editing_rule, do: "Edit alert rule", else: "Create alert rule")}
          </h2>
          <p class="mt-1 text-sm leading-6 text-base-content/60">
            Alert delivery is deduplicated per issue and rule by cooldown.
          </p>
        </div>
        <button
          id="cancel-alert-rule-edit"
          type="button"
          phx-click={if(@editing_rule, do: "cancel_edit", else: "clear_rule_builder")}
          class="rounded-lg px-2 py-1 text-sm font-semibold text-base-content/60 transition hover:bg-base-200 hover:text-base-content"
        >
          Cancel
        </button>
      </div>

      <.form
        for={@form}
        id="alert-rule-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-5 space-y-4"
      >
        <.input field={@form[:name]} type="text" label="Name" required />
        <.input field={@form[:enabled]} type="checkbox" label="Enabled" />
        <.input
          field={@form[:notify_on]}
          type="select"
          label="Trigger"
          options={@notify_on_options}
          required
        />
        <.input
          field={@form[:channel]}
          type="select"
          label="Channel"
          options={@channel_options}
          required
        />
        <.input
          field={@form[:target]}
          type="text"
          label="Target"
          placeholder="alerts@example.com or https://hooks.example.com/..."
          required
        />
        <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-1">
          <.input
            field={@form[:threshold_count]}
            type="number"
            label="Threshold"
            min="1"
            max="1000000"
            required
          />
          <.input
            field={@form[:cooldown_seconds]}
            type="number"
            label="Cooldown seconds"
            min="0"
            max="86400"
            required
          />
        </div>

        <button
          id="save-alert-rule-button"
          type="submit"
          class="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
        >
          <.icon name="hero-bell-alert" class="size-4" />
          {if(@editing_rule, do: "Save rule", else: "Create rule")}
        </button>
      </.form>
    </section>
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

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp rule_kv(assigns) do
    ~H"""
    <div class="min-w-0">
      <dt class="text-base-content/50">{@label}</dt>
      <dd class="mt-0.5 break-words font-medium text-base-content">{@value}</dd>
    </div>
    """
  end

  defp trigger_label("new_issue"), do: "New issues"
  defp trigger_label("regression"), do: "Regressions"
  defp trigger_label("frequency"), do: "Frequency alerts"
  defp trigger_label(value), do: value

  defp channel_label("email"), do: "Email"
  defp channel_label("webhook"), do: "Webhook"
  defp channel_label("slack"), do: "Slack webhook"
  defp channel_label(value), do: value

  defp dsn_origin(dsn) do
    uri = URI.parse(dsn)
    port = dsn_origin_port(uri.scheme, uri.port)
    authority = if port, do: "#{uri.host}:#{port}", else: uri.host

    "#{uri.scheme}://#{authority}"
  end

  defp dsn_origin_port("http", 80), do: nil
  defp dsn_origin_port("https", 443), do: nil
  defp dsn_origin_port(_scheme, nil), do: nil
  defp dsn_origin_port(_scheme, port), do: port

  defp admin_scope?(%{user: %{role: "admin"}}), do: true
  defp admin_scope?(_scope), do: false
end
