defmodule FSST.Table do
  @moduledoc """
  Opaque FSST symbol table.

  Build tables with `FSST.train/2` and pass them to `FSST.compress/3` and
  `FSST.decompress/3`.
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
end
