defmodule FaultlineWeb.ThemeTest do
  use ExUnit.Case, async: true

  @css_path Path.expand("../../assets/css/app.css", __DIR__)

  test "uses amber primary accents in light and dark themes" do
    css = File.read!(@css_path)

    assert css =~ "--color-primary: oklch(68% 0.18 52);"
    assert css =~ "--color-accent: oklch(68% 0.18 52);"
    assert count(css, "--color-primary: oklch(68% 0.18 52);") == 2
    assert count(css, "--color-accent: oklch(68% 0.18 52);") == 2

    refute css =~ "277.117"
    refute css =~ "292.717"
  end

  defp count(text, pattern) do
    text
    |> String.split(pattern)
    |> length()
    |> Kernel.-(1)
  end
end
