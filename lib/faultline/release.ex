defmodule Faultline.Release do
  @moduledoc """
  Release helpers for SQLite-first single-container deployments.
  """

  @app :faultline
  @default_admin_email "admin@faultline.local"
  @default_password_file "/data/bootstrap_admin_password"
  @password_words ~w(
    amber atlas cedar comet copper harbor maple meadow nova orbit quartz river
    silver summit valley velvet willow winter
  )

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _started, _stopped} =
        Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()

    {:ok, _started, _stopped} =
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def bootstrap_admin_from_env do
    load_app()

    opts = [
      email: System.get_env("FAULTLINE_ADMIN_EMAIL"),
      password: System.get_env("FAULTLINE_ADMIN_PASSWORD"),
      password_file: System.get_env("FAULTLINE_ADMIN_PASSWORD_FILE") || @default_password_file
    ]

    for repo <- repos() do
      {:ok, _started, _stopped} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          case bootstrap_admin(opts) do
            {:ok, :users_exist} ->
              IO.puts("Bootstrap admin skipped because users already exist")

            {:ok, user} ->
              IO.puts("Bootstrap admin created")
              IO.puts("Email: #{user.email}")
              IO.puts("Password file: #{Keyword.fetch!(opts, :password_file)}")

            {:error, changeset} ->
              IO.puts(:stderr, "Bootstrap admin failed: #{inspect(changeset.errors)}")
              System.halt(1)
          end
        end)
    end

    :ok
  end

  def bootstrap_admin(opts \\ []) do
    alias Faultline.Accounts.User
    alias Faultline.Repo

    if Repo.exists?(User) do
      {:ok, :users_exist}
    else
      email = opts |> Keyword.get(:email) |> usable_value(@default_admin_email)
      password_file = Keyword.get(opts, :password_file, @default_password_file)
      password = opts |> Keyword.get(:password) |> usable_password(password_file)

      %User{}
      |> User.email_changeset(%{email: email})
      |> Ecto.Changeset.put_change(:role, "admin")
      |> User.password_changeset(%{password: password})
      |> User.confirm_changeset()
      |> Repo.insert()
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  defp usable_value(nil, default), do: default
  defp usable_value("", default), do: default
  defp usable_value(value, _default), do: value

  defp usable_password(nil, password_file), do: password_from_file(password_file)
  defp usable_password("", password_file), do: password_from_file(password_file)
  defp usable_password(password, _password_file), do: password

  defp password_from_file(password_file) do
    if File.exists?(password_file) do
      password_file
      |> File.read!()
      |> String.trim()
    else
      password = readable_password()
      File.mkdir_p!(Path.dirname(password_file))
      File.write!(password_file, password <> "\n")
      File.chmod!(password_file, 0o600)
      password
    end
  end

  defp readable_password do
    first = random_word()
    second = random_word()
    number = :crypto.strong_rand_bytes(2) |> :binary.decode_unsigned() |> rem(10_000)

    "#{first}-#{second}-#{String.pad_leading(Integer.to_string(number), 4, "0")}"
  end

  defp random_word do
    index =
      1
      |> :crypto.strong_rand_bytes()
      |> :binary.decode_unsigned()
      |> rem(length(@password_words))

    Enum.at(@password_words, index)
  end
end
