if Code.ensure_loaded?(Rustler) do
  defmodule FSST.Native do
    @moduledoc false

    use Rustler,
      otp_app: :fsst,
      crate: :fsst_nif,
      mode: :release

    def train(_samples), do: :erlang.nif_error(:nif_not_loaded)
    def compress(_native_table, _input), do: :erlang.nif_error(:nif_not_loaded)
    def decompress(_native_table, _input), do: :erlang.nif_error(:nif_not_loaded)
  end
else
  defmodule FSST.Native do
    @moduledoc false

    def train(_samples), do: :erlang.nif_error(:nif_not_loaded)
    def compress(_native_table, _input), do: :erlang.nif_error(:nif_not_loaded)
    def decompress(_native_table, _input), do: :erlang.nif_error(:nif_not_loaded)
  end
end
