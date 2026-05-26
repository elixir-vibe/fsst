defmodule FSST.Rust do
  @moduledoc """
  Optional Rustler backend for `fsst-rs`.
  """

  @behaviour FSST.Backend

  alias FSST.Table

  @impl true
  def available? do
    Code.ensure_loaded?(FSST.Native) and function_exported?(FSST.Native, :train, 1) and loaded?()
  end

  @impl true
  def train(samples, opts \\ [])

  def train(samples, _opts) when is_list(samples) do
    if Enum.all?(samples, &is_binary/1) do
      {:ok,
       %Table{
         symbols: nil,
         codes: nil,
         pattern: nil,
         lengths: nil,
         native: FSST.Native.train(samples),
         backend: __MODULE__
       }}
    else
      {:error, :invalid_sample}
    end
  rescue
    UndefinedFunctionError -> {:error, :backend_unavailable}
    ErlangError -> {:error, :backend_unavailable}
  end

  def train(_samples, _opts), do: {:error, :invalid_sample}

  @impl true
  def compress(%Table{native: native}, input) when is_binary(input) and not is_nil(native) do
    {:ok, FSST.Native.compress(native, input)}
  rescue
    ErlangError -> {:error, :backend_unavailable}
  end

  def compress(_table, _input), do: {:error, :invalid_input}

  @impl true
  def decompress(%Table{native: native}, input) when is_binary(input) and not is_nil(native) do
    {:ok, FSST.Native.decompress(native, input)}
  rescue
    ErlangError -> {:error, :backend_unavailable}
  end

  def decompress(_table, _input), do: {:error, :invalid_input}

  defp loaded? do
    FSST.Native.train(["probe"])
    true
  rescue
    ErlangError -> false
  end
end
