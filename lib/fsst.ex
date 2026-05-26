defmodule FSST do
  @moduledoc """
  Fast Static Symbol Tables compression for Elixir.

  `FSST` is a pure Elixir port with an optional Rustler backend planned around
  [`fsst-rs`](https://docs.rs/fsst-rs/latest/fsst/). The API follows typical
  Elixir conventions: `train/2` returns `{:ok, table}` or `{:error, reason}`,
  while `train!/2`, `compress!/3`, and `decompress!/3` raise on failure.
  """

  alias FSST.Table

  @type table :: Table.t()
  @type reason ::
          :backend_unavailable | :invalid_input | :invalid_sample | :truncated_escape | term()

  @doc """
  Trains an FSST table from representative binary samples.
  """
  @spec train([binary()], keyword()) :: {:ok, table()} | {:error, reason()}
  def train(samples, opts \\ []) do
    opts
    |> backend()
    |> then(& &1.train(samples, opts))
  end

  @doc """
  Trains an FSST table or raises when training fails.
  """
  @spec train!([binary()], keyword()) :: table()
  def train!(samples, opts \\ []) do
    case train(samples, opts) do
      {:ok, table} -> table
      {:error, reason} -> raise ArgumentError, "could not train FSST table: #{inspect(reason)}"
    end
  end

  @doc """
  Compresses a binary with a table returned by `train/2`.
  """
  @spec compress(table(), binary(), keyword()) :: {:ok, binary()} | {:error, reason()}
  def compress(table, input, opts \\ [])

  def compress(%Table{} = table, input, opts) do
    table
    |> table_backend(opts)
    |> then(& &1.compress(table, input))
  end

  def compress(_table, _input, _opts), do: {:error, :invalid_input}

  @doc """
  Compresses a binary or raises on failure.
  """
  @spec compress!(table(), binary(), keyword()) :: binary()
  def compress!(table, input, opts \\ []) do
    case compress(table, input, opts) do
      {:ok, compressed} -> compressed
      {:error, reason} -> raise ArgumentError, "could not compress input: #{inspect(reason)}"
    end
  end

  @doc """
  Decompresses a binary with the same table used for compression.
  """
  @spec decompress(table(), binary(), keyword()) :: {:ok, binary()} | {:error, reason()}
  def decompress(table, input, opts \\ [])

  def decompress(%Table{} = table, input, opts) do
    table
    |> table_backend(opts)
    |> then(& &1.decompress(table, input))
  end

  def decompress(_table, _input, _opts), do: {:error, :invalid_input}

  @doc """
  Decompresses a binary or raises on failure.
  """
  @spec decompress!(table(), binary(), keyword()) :: binary()
  def decompress!(table, input, opts \\ []) do
    case decompress(table, input, opts) do
      {:ok, decompressed} -> decompressed
      {:error, reason} -> raise ArgumentError, "could not decompress input: #{inspect(reason)}"
    end
  end

  @doc """
  Returns the backend module selected for the current options and runtime.
  """
  @spec backend(keyword()) :: module()
  def backend(opts \\ []) do
    case Keyword.get(opts, :backend, :auto) do
      :auto -> auto_backend()
      :pure -> FSST.Pure
      :rust -> FSST.Rust
      module when is_atom(module) -> module
    end
  end

  @doc false
  @spec compress_sample([binary()], keyword()) :: {:ok, table()} | {:error, reason()}
  def compress_sample(samples, opts \\ []), do: train(samples, opts)

  defp auto_backend do
    if FSST.Rust.available?(), do: FSST.Rust, else: FSST.Pure
  end

  defp table_backend(_table, opts) when opts != [], do: backend(opts)
  defp table_backend(%Table{backend: backend}, _opts), do: backend
end
