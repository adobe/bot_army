defmodule TermParser do
  @moduledoc """
  Taken verbatim from https://gist.github.com/mmmries/b657c77845b07ee8cd34.
  """
  def parse(str) when is_binary(str) do
    case str |> Code.string_to_quoted() do
      {:ok, terms} -> hydrate_terms(terms)
      {:error, err} -> {:error, err}
    end
  end

  defp hydrate_terms(terms) do
    try do
      {:ok, _parse(terms)}
    rescue
      e in ArgumentError -> {:error, e}
    end
  end

  # atomic terms
  defp _parse(term) when is_atom(term), do: term
  defp _parse(term) when is_integer(term), do: term
  defp _parse(term) when is_float(term), do: term
  defp _parse(term) when is_binary(term), do: term

  defp _parse([]), do: []
  defp _parse([h | t]), do: [_parse(h) | _parse(t)]

  defp _parse({a, b}), do: {_parse(a), _parse(b)}

  defp _parse({:{}, _place, terms}) do
    terms
    |> Enum.map(&_parse/1)
    |> List.to_tuple()
  end

  defp _parse({:%{}, _place, terms}) do
    for {k, v} <- terms, into: %{}, do: {_parse(k), _parse(v)}
  end

  defp _parse(_) do
    raise ArgumentError, message: "string contains non-literal term(s)"
  end
end
