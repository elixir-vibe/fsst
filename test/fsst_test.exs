defmodule FSSTTest do
  use ExUnit.Case, async: true

  test "uses the Rust backend by default when it is available" do
    assert FSST.backend() == FSST.Rust
  end

  test "can select the Rust backend explicitly" do
    assert FSST.backend(backend: :rust) == FSST.Rust
  end

  test "trains an opaque pure table" do
    assert {:ok, %FSST.Table{} = table} =
             FSST.train(["hello", "hello world", "hello there"], backend: :pure)

    assert table.backend == FSST.Pure
    assert map_size(table.codes) > 0
  end

  test "round trips text with repeated symbols using pure Elixir" do
    table = FSST.train!(["hello world", "hello there", "hello hello"], backend: :pure)

    compressed = FSST.compress!(table, "hello world hello")

    assert byte_size(compressed) < byte_size("hello world hello")
    assert FSST.decompress(table, compressed) == {:ok, "hello world hello"}
  end

  test "round trips arbitrary binaries through escaped bytes using pure Elixir" do
    table = FSST.train!(["abcabc", "abcxyz"], backend: :pure)
    input = <<0, 255, 1, "abc", 2, 255>>

    assert input |> then(&FSST.compress!(table, &1)) |> then(&FSST.decompress!(table, &1)) ==
             input
  end

  test "round trips arbitrary binaries using Rust" do
    table = FSST.train!(["abcabc", "abcxyz"], backend: :rust)
    input = <<0, 255, 1, "abc", 2, 255>>

    assert input |> then(&FSST.compress!(table, &1)) |> then(&FSST.decompress!(table, &1)) ==
             input
  end

  test "returns errors for malformed pure compressed data" do
    table = FSST.train!(["abcabc"], backend: :pure)

    assert FSST.decompress(table, <<255>>) == {:error, :truncated_escape}
    assert FSST.decompress(table, <<254>>) == {:error, {:unknown_code, 254}}
  end

  test "validates samples" do
    assert FSST.train(["hello", 123]) == {:error, :invalid_sample}
    assert FSST.train(:not_samples) == {:error, :invalid_sample}
  end
end
