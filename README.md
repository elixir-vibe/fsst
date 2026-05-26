# FSST

Fast Static Symbol Tables compression for Elixir.

FSST is a string compression algorithm designed for database-style workloads:
many short strings compressed with a shared static symbol table. This package
provides a pure Elixir implementation and an optional Rustler backend powered by
[`fsst-rs`](https://docs.rs/fsst-rs/latest/fsst/).

## Installation

```elixir
def deps do
  [
    {:fsst, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
table = FSST.train!(["hello", "hello world", "hello there"])
compressed = FSST.compress!(table, "hello world")
"hello world" = FSST.decompress!(table, compressed)
```

Prefer the non-bang functions when handling user input:

```elixir
with {:ok, table} <- FSST.train(samples),
     {:ok, compressed} <- FSST.compress(table, input),
     {:ok, decompressed} <- FSST.decompress(table, compressed) do
  {:ok, decompressed, compressed}
end
```

## Existing symbol tables

Some formats store a pre-trained FSST dictionary separately from compressed
payloads. Build a table directly from symbols in code order:

```elixir
table = FSST.Table.from_symbols!(["hello", " world"])
"hello world!" = FSST.decompress!(table, <<0, 1, 255, ?!>>)
```

## Backends

- `FSST.Pure` is always available and contains the Elixir implementation.
- `FSST.Rust` wraps `fsst-rs` through Rustler when the NIF is available.
- `FSST.backend/1` uses `:auto` by default, preferring Rust when available and
  otherwise falling back to pure Elixir.

Select a backend explicitly:

```elixir
table = FSST.train!(samples, backend: :pure)
table = FSST.train!(samples, backend: :rust)
```

## Training options

Pure training accepts tuning options:

```elixir
FSST.train!(samples, max_symbol_size: 8, sample_bytes: 65_536)
```

- `:max_symbol_size` controls candidate symbol length.
- `:sample_bytes` limits training input for large corpora. Use `:infinity` to
  train on all provided bytes.

## Benchmarks

```sh
mix run bench/fsst_bench.exs
```

## License

MIT © 2026 Danila Poyarkov
