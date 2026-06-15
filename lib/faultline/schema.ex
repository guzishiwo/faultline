defmodule Faultline.Schema do
  @moduledoc """
  Shared Ecto schema defaults.
  """

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      @primary_key {:id, Ecto.UUID, autogenerate: [version: 7, precision: :monotonic]}
      @foreign_key_type Ecto.UUID
    end
  end
end
