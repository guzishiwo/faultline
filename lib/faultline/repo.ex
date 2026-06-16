defmodule Faultline.Repo do
  use Ecto.Repo,
    otp_app: :faultline,
    adapter: Ecto.Adapters.SQLite3
end
