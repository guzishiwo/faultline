defmodule Faultline.Search.Query do
  @moduledoc """
  Parses Faultline search strings into free text and key/value filters.
  """

  @type t :: %__MODULE__{
          text: String.t(),
          filters: [{String.t(), String.t()}],
          reserved_filters: [{String.t(), String.t()}],
          tag_filters: [{String.t(), String.t()}],
          text_terms: [String.t()]
        }

  @reserved_filter_keys ~w(project status issue)

  defstruct text: "", filters: [], reserved_filters: [], tag_filters: [], text_terms: []

  @spec parse(String.t() | nil) :: t()
  def parse(nil), do: %__MODULE__{}

  def parse(query) when is_binary(query) do
    query
    |> tokenize()
    |> Enum.reduce(%__MODULE__{}, fn token, parsed ->
      case key_value(token) do
        {key, value} ->
          key = String.downcase(key)
          filter = {key, value}

          parsed =
            if key in @reserved_filter_keys do
              %{parsed | reserved_filters: parsed.reserved_filters ++ [filter]}
            else
              %{parsed | tag_filters: parsed.tag_filters ++ [filter]}
            end

          %{parsed | filters: parsed.filters ++ [filter]}

        nil ->
          text = [parsed.text, token] |> Enum.reject(&(&1 == "")) |> Enum.join(" ")
          %{parsed | text: text, text_terms: parsed.text_terms ++ [token]}
      end
    end)
  end

  def parse(_query), do: %__MODULE__{}

  defp tokenize(query) do
    query
    |> String.trim()
    |> do_tokenize([], "", false)
    |> Enum.reverse()
  end

  defp do_tokenize("", tokens, current, _quoted?) do
    if current == "", do: tokens, else: [current | tokens]
  end

  defp do_tokenize(<<"\\\"", rest::binary>>, tokens, current, quoted?) do
    do_tokenize(rest, tokens, current <> "\"", quoted?)
  end

  defp do_tokenize(<<"\"", rest::binary>>, tokens, current, quoted?) do
    do_tokenize(rest, tokens, current, not quoted?)
  end

  defp do_tokenize(<<char::utf8, rest::binary>>, tokens, current, false)
       when char in [?\s, ?\t, ?\n] do
    if current == "" do
      do_tokenize(rest, tokens, "", false)
    else
      do_tokenize(rest, [current | tokens], "", false)
    end
  end

  defp do_tokenize(<<char::utf8, rest::binary>>, tokens, current, quoted?) do
    do_tokenize(rest, tokens, current <> <<char::utf8>>, quoted?)
  end

  defp key_value(token) do
    case String.split(token, ":", parts: 2) do
      [key, value] when key != "" and value != "" -> {key, value}
      _ -> nil
    end
  end
end
