defmodule FSST.Backend do
  @moduledoc false

  @callback available?() :: boolean()
  @callback train([binary()], keyword()) :: {:ok, FSST.Table.t()} | {:error, term()}
  @callback compress(FSST.Table.t(), binary()) :: {:ok, binary()} | {:error, term()}
  @callback decompress(FSST.Table.t(), binary()) :: {:ok, binary()} | {:error, term()}
end
