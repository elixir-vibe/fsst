defmodule FSST.Table do
  @moduledoc """
  Opaque FSST symbol table.

  Build tables with `FSST.train/2` or `FSST.Table.from_symbols/1` and pass them
  to `FSST.compress/3` and `FSST.decompress/3`.
  """

  @enforce_keys [:symbols, :codes]
  defstruct [:symbols, :codes, :pattern, :lengths, :native, backend: FSST.Pure]

  @type t :: %__MODULE__{
          symbols: tuple() | nil,
          codes: %{binary() => byte()} | nil,
          pattern: tuple() | nil,
          lengths: [pos_integer()] | nil,
          native: term(),
          backend: module()
        }

  @doc """
  Builds a pure Elixir table from an existing serialized FSST symbol table.

  Symbols must be provided in code order. Each symbol must be a binary from one
  to eight bytes. Code `255` is reserved for escaped raw bytes, so at most 255
  symbols are allowed.
  """
  @spec from_symbols([binary()]) :: {:ok, t()} | {:error, term()}
  def from_symbols(symbols) when is_list(symbols) do
    cond do
      Enum.count_until(symbols, 256) > 255 ->
        {:error, :too_many_symbols}

      Enum.all?(symbols, &valid_symbol?/1) ->
        copied_symbols = Enum.map(symbols, &:binary.copy/1)
        codes = copied_symbols |> Enum.with_index() |> Map.new()
        pattern = compile_pattern(copied_symbols)
        lengths = copied_symbols |> Enum.map(&byte_size/1) |> Enum.uniq() |> Enum.sort(:desc)

        {:ok,
         %__MODULE__{
           symbols: List.to_tuple(copied_symbols),
           codes: codes,
           pattern: pattern,
           lengths: lengths,
           backend: FSST.Pure
         }}

      true ->
        {:error, :invalid_symbol}
    end
  end

  def from_symbols(_symbols), do: {:error, :invalid_symbols}

  @doc """
  Builds a pure Elixir table from existing serialized symbols or raises.
  """
  @spec from_symbols!([binary()]) :: t()
  def from_symbols!(symbols) do
    case from_symbols(symbols) do
      {:ok, table} -> table
      {:error, reason} -> raise ArgumentError, "could not build FSST table: #{inspect(reason)}"
    end
  end

  defp valid_symbol?(symbol), do: is_binary(symbol) and byte_size(symbol) in 1..8

  defp compile_pattern([]), do: nil
  defp compile_pattern(symbols), do: :binary.compile_pattern(symbols)
end
