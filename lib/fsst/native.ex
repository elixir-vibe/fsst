defmodule FSST.Native do
  @moduledoc false

  version = Mix.Project.config()[:version]
  source_root = Path.expand("../..", __DIR__)

  local_test_build =
    Mix.env() == :test and
      File.exists?(Path.join(source_root, "test/test_helper.exs")) and
      File.dir?(Path.join(source_root, ".git"))

  use RustlerPrecompiled,
    otp_app: :fsst,
    crate: "fsst_nif",
    base_url: "https://github.com/elixir-vibe/fsst/releases/download/v#{version}",
    force_build: local_test_build or System.get_env("FSST_BUILD") in ["1", "true"],
    targets: ~w(
      aarch64-apple-darwin
      aarch64-unknown-linux-gnu
      x86_64-apple-darwin
      x86_64-unknown-linux-gnu
    ),
    version: version

  def train(_samples), do: :erlang.nif_error(:nif_not_loaded)
  def compress(_native_table, _input), do: :erlang.nif_error(:nif_not_loaded)
  def decompress(_native_table, _input), do: :erlang.nif_error(:nif_not_loaded)
end
