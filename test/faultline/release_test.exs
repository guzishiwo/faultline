defmodule Faultline.ReleaseTest do
  use Faultline.DataCase, async: true

  alias Faultline.Accounts
  alias Faultline.Accounts.User
  alias Faultline.Release
  alias Faultline.Repo

  describe "bootstrap_admin/1" do
    test "creates a confirmed admin with a configured password when no users exist" do
      password_file = tmp_password_file()

      assert {:ok, user} =
               Release.bootstrap_admin(
                 email: "admin@example.com",
                 password: "change-me-now",
                 password_file: password_file
               )

      assert user.email == "admin@example.com"
      assert user.role == "admin"
      assert user.confirmed_at
      refute File.exists?(password_file)
      assert Accounts.get_user_by_email_and_password("admin@example.com", "change-me-now")
    end

    test "generates a readable password file when no password is configured" do
      password_file = tmp_password_file()

      assert {:ok, user} = Release.bootstrap_admin(password_file: password_file)

      password = password_file |> File.read!() |> String.trim()

      assert user.email == "admin@faultline.local"
      assert user.role == "admin"
      assert password =~ ~r/^[a-z]+-[a-z]+-\d{4}$/
      assert String.length(password) >= 12
      assert Accounts.get_user_by_email_and_password(user.email, password)
    end

    test "does not create or overwrite users after the first account exists" do
      {:ok, existing_user} = Accounts.register_user(%{email: "existing@example.com"})
      password_file = tmp_password_file()

      assert {:ok, :users_exist} =
               Release.bootstrap_admin(
                 email: "admin@example.com",
                 password: "change-me-now",
                 password_file: password_file
               )

      assert Repo.aggregate(User, :count) == 1
      assert Repo.get!(User, existing_user.id).email == "existing@example.com"
      refute Accounts.get_user_by_email("admin@example.com")
      refute File.exists?(password_file)
    end

    test "rejects a configured password that does not meet password rules" do
      assert {:error, changeset} =
               Release.bootstrap_admin(
                 email: "admin@example.com",
                 password: "short",
                 password_file: tmp_password_file()
               )

      assert "should be at least 12 character(s)" in errors_on(changeset).password
      assert Repo.aggregate(User, :count) == 0
    end
  end

  defp tmp_password_file do
    Path.join(
      System.tmp_dir!(),
      "faultline-bootstrap-admin-#{System.unique_integer([:positive])}"
    )
  end
end
