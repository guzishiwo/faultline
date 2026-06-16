defmodule Faultline.Projects.Project do
  use Faultline.Schema

  import Ecto.Changeset

  alias Faultline.Alerts.AlertRule
  alias Faultline.Retention.ProjectDropRule

  @type t :: %__MODULE__{}

  @default_platform "other"
  @platform_categories [
    %{id: "popular", label: "Popular"},
    %{id: "browser", label: "Browser"},
    %{id: "server", label: "Server"},
    %{id: "mobile", label: "Mobile"},
    %{id: "desktop", label: "Desktop"},
    %{id: "serverless", label: "Serverless"},
    %{id: "gaming", label: "Gaming"},
    %{id: "all", label: "All"}
  ]
  @platforms [
    %{
      id: "other",
      name: "Not sure yet",
      category: "other",
      popular?: true,
      mark: "?",
      badge: nil,
      tone: "bg-base-content text-base-100"
    },
    %{
      id: "nextjs",
      name: "Next.js",
      category: "browser",
      popular?: true,
      mark: "N",
      badge: "JS",
      tone: "bg-zinc-950 text-white"
    },
    %{
      id: "react",
      name: "React",
      category: "browser",
      popular?: true,
      mark: "R",
      badge: "JS",
      tone: "bg-cyan-950 text-cyan-200"
    },
    %{
      id: "react_native",
      name: "React Native",
      category: "mobile",
      popular?: true,
      mark: "RN",
      badge: "JS",
      tone: "bg-sky-100 text-sky-700"
    },
    %{
      id: "nodejs",
      name: "Node.js",
      category: "server",
      popular?: true,
      mark: "N",
      badge: nil,
      tone: "bg-zinc-800 text-lime-400"
    },
    %{
      id: "laravel",
      name: "Laravel",
      category: "server",
      popular?: true,
      mark: "L",
      badge: "PHP",
      tone: "bg-red-600 text-white"
    },
    %{
      id: "fastapi",
      name: "FastAPI",
      category: "server",
      popular?: true,
      mark: "F",
      badge: "PY",
      tone: "bg-emerald-600 text-white"
    },
    %{
      id: "flutter",
      name: "Flutter",
      category: "mobile",
      popular?: true,
      mark: "F",
      badge: nil,
      tone: "bg-sky-100 text-sky-700"
    },
    %{
      id: "django",
      name: "Django",
      category: "server",
      popular?: true,
      mark: "dj",
      badge: "PY",
      tone: "bg-emerald-950 text-white"
    },
    %{
      id: "python",
      name: "Python",
      category: "server",
      popular?: true,
      mark: "Py",
      badge: nil,
      tone: "bg-blue-100 text-blue-700"
    },
    %{
      id: "express",
      name: "Express",
      category: "server",
      popular?: true,
      mark: "ex",
      badge: "JS",
      tone: "bg-base-100 text-base-content"
    },
    %{
      id: "browser_javascript",
      name: "Browser JavaScript",
      category: "browser",
      popular?: true,
      mark: "JS",
      badge: nil,
      tone: "bg-yellow-300 text-zinc-950"
    },
    %{
      id: "php",
      name: "PHP",
      category: "server",
      popular?: true,
      mark: "php",
      badge: nil,
      tone: "bg-indigo-500 text-white"
    },
    %{
      id: "rails",
      name: "Rails",
      category: "server",
      popular?: true,
      mark: "R",
      badge: "RB",
      tone: "bg-red-700 text-white"
    },
    %{
      id: "ios",
      name: "iOS",
      category: "mobile",
      popular?: true,
      mark: "iOS",
      badge: nil,
      tone: "bg-zinc-950 text-white"
    },
    %{
      id: "nestjs",
      name: "NestJS",
      category: "server",
      popular?: true,
      mark: "N",
      badge: "JS",
      tone: "bg-rose-600 text-white"
    },
    %{
      id: "flask",
      name: "Flask",
      category: "server",
      popular?: true,
      mark: "F",
      badge: "PY",
      tone: "bg-cyan-600 text-white"
    },
    %{
      id: "vue",
      name: "Vue",
      category: "browser",
      popular?: true,
      mark: "V",
      badge: "JS",
      tone: "bg-emerald-100 text-emerald-700"
    },
    %{
      id: "aspnet_core",
      name: "ASP.NET Core",
      category: "server",
      popular?: true,
      mark: ".NET",
      badge: ".NET",
      tone: "bg-violet-600 text-white"
    },
    %{
      id: "nuxt",
      name: "Nuxt",
      category: "browser",
      popular?: true,
      mark: "Nu",
      badge: "JS",
      tone: "bg-zinc-950 text-emerald-300"
    },
    %{
      id: "dotnet_maui",
      name: ".NET MAUI",
      category: "mobile",
      popular?: true,
      mark: ".NET",
      badge: ".NET",
      tone: "bg-violet-600 text-white"
    },
    %{
      id: "angular",
      name: "Angular",
      category: "browser",
      popular?: true,
      mark: "A",
      badge: "JS",
      tone: "bg-fuchsia-600 text-white"
    },
    %{
      id: "android",
      name: "Android",
      category: "mobile",
      popular?: true,
      mark: "A",
      badge: nil,
      tone: "bg-green-100 text-green-700"
    },
    %{
      id: "spring_boot",
      name: "Spring Boot",
      category: "server",
      popular?: true,
      mark: "S",
      badge: "JV",
      tone: "bg-green-600 text-white"
    },
    %{
      id: "symfony",
      name: "Symfony",
      category: "server",
      popular?: true,
      mark: "sf",
      badge: "PHP",
      tone: "bg-zinc-950 text-white"
    },
    %{
      id: "cloudflare_workers",
      name: "Cloudflare Workers",
      category: "serverless",
      popular?: true,
      mark: "W",
      badge: "JS",
      tone: "bg-orange-500 text-white"
    },
    %{
      id: "electron",
      name: "Electron",
      category: "desktop",
      popular?: true,
      mark: "E",
      badge: nil,
      tone: "bg-slate-800 text-cyan-200"
    },
    %{
      id: "unity",
      name: "Unity",
      category: "gaming",
      popular?: true,
      mark: "U",
      badge: nil,
      tone: "bg-zinc-950 text-white"
    },
    %{
      id: "remix",
      name: "Remix",
      category: "browser",
      popular?: true,
      mark: "R",
      badge: "JS",
      tone: "bg-zinc-900 text-white"
    }
  ]
  @platform_values Enum.map(@platforms, & &1.id)

  schema "projects" do
    field :project_number, :integer
    field :name, :string
    field :slug, :string
    field :platform, :string, default: @default_platform
    field :public_key, :string
    field :secret_key, :string
    field :dsn, :string
    field :rate_limit_max_events, :integer, default: 1000
    field :rate_limit_window_seconds, :integer, default: 60
    field :retention_days, :integer, default: 30
    field :retention_event_limit, :integer, default: 10_000

    has_many :alert_rules, AlertRule
    has_many :drop_rules, ProjectDropRule

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def create_changeset(project, attrs) do
    project
    |> cast(attrs, [
      :project_number,
      :name,
      :platform,
      :rate_limit_max_events,
      :rate_limit_window_seconds,
      :retention_days,
      :retention_event_limit
    ])
    |> validate_required([
      :project_number,
      :name,
      :platform,
      :rate_limit_max_events,
      :rate_limit_window_seconds,
      :retention_days,
      :retention_event_limit
    ])
    |> validate_number(:project_number, greater_than: 0)
    |> validate_length(:name, min: 2, max: 80)
    |> validate_inclusion(:platform, @platform_values)
    |> validate_cost_controls()
    |> put_slug()
    |> put_keys()
    |> put_placeholder_dsn()
    |> unique_constraint(:project_number)
    |> unique_constraint(:slug)
    |> unique_constraint(:public_key)
  end

  @doc false
  def update_dsn_changeset(project, dsn) do
    project
    |> change(dsn: dsn)
    |> validate_required([:dsn])
  end

  @doc false
  def settings_changeset(project, attrs) do
    project
    |> cast(attrs, [
      :rate_limit_max_events,
      :rate_limit_window_seconds,
      :retention_days,
      :retention_event_limit
    ])
    |> validate_required([
      :rate_limit_max_events,
      :rate_limit_window_seconds,
      :retention_days,
      :retention_event_limit
    ])
    |> validate_cost_controls()
  end

  defp validate_cost_controls(changeset) do
    changeset
    |> validate_number(:rate_limit_max_events, greater_than: 0, less_than_or_equal_to: 1_000_000)
    |> validate_number(:rate_limit_window_seconds, greater_than: 0, less_than_or_equal_to: 86_400)
    |> validate_number(:retention_days, greater_than: 0, less_than_or_equal_to: 3650)
    |> validate_number(:retention_event_limit, greater_than: 0, less_than_or_equal_to: 10_000_000)
  end

  defp put_slug(changeset) do
    name = get_field(changeset, :name)

    if is_binary(name) do
      put_change(changeset, :slug, slugify(name))
    else
      changeset
    end
  end

  defp put_keys(changeset) do
    changeset
    |> put_change(:public_key, random_key())
    |> put_change(:secret_key, random_key())
  end

  defp put_placeholder_dsn(changeset) do
    put_change(changeset, :dsn, "pending")
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> ensure_slug()
  end

  defp ensure_slug(""), do: "project"
  defp ensure_slug(slug), do: slug

  defp random_key do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  def default_platform, do: @default_platform
  def platform_categories, do: @platform_categories
  def platforms, do: @platforms
  def platform_values, do: @platform_values

  def platform_label(platform_id) do
    @platforms
    |> Enum.find(&(&1.id == platform_id))
    |> case do
      nil -> platform_id
      platform -> platform.name
    end
  end
end
