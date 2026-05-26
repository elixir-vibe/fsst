defmodule FSST.TableTest do
  use ExUnit.Case, async: true

  test "builds a table from serialized symbols" do
    table = FSST.Table.from_symbols!(["hello", " world"])

    compressed = <<0, 1, 255, ?!>>

    assert FSST.decompress(table, compressed) == {:ok, "hello world!"}
  end

  test "exposes top-level table_from_symbols helpers" do
    assert {:ok, table} = FSST.table_from_symbols(["abc"])
    assert FSST.decompress!(table, <<0, 255, ?d>>) == "abcd"
  end

  test "validates serialized symbols" do
    assert FSST.Table.from_symbols(:bad) == {:error, :invalid_symbols}
    assert FSST.Table.from_symbols([""]) == {:error, :invalid_symbol}
    assert FSST.Table.from_symbols([String.duplicate("a", 9)]) == {:error, :invalid_symbol}
    assert FSST.Table.from_symbols(List.duplicate("a", 256)) == {:error, :too_many_symbols}
  end
end
