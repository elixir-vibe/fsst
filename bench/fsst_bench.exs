samples = [
  String.duplicate("hello world ", 64),
  String.duplicate("/api/v1/users/123/events ", 64),
  String.duplicate("ERROR request_id=abc123 status=500 duration=42ms ", 64)
]

small = "hello world hello world"
medium = Enum.join(samples)
large = String.duplicate(medium, 32)

inputs = %{
  "small" => small,
  "medium" => medium,
  "large" => large
}

pure_table = FSST.train!(samples, backend: :pure)
rust_table = FSST.train!(samples, backend: :rust)

pure_compressed = Map.new(inputs, fn {_name, input} -> {input, FSST.compress!(pure_table, input)} end)
rust_compressed = Map.new(inputs, fn {_name, input} -> {input, FSST.compress!(rust_table, input)} end)

Benchee.run(
  %{
    "pure train" => fn input -> FSST.train!([input], backend: :pure) end,
    "rust train" => fn input -> FSST.train!([input], backend: :rust) end,
    "pure compress" => fn input -> FSST.compress!(pure_table, input) end,
    "rust compress" => fn input -> FSST.compress!(rust_table, input) end,
    "pure decompress" => fn input -> FSST.decompress!(pure_table, Map.fetch!(pure_compressed, input)) end,
    "rust decompress" => fn input -> FSST.decompress!(rust_table, Map.fetch!(rust_compressed, input)) end,
    "pure roundtrip" => fn input -> input |> then(&FSST.compress!(pure_table, &1)) |> then(&FSST.decompress!(pure_table, &1)) end,
    "rust roundtrip" => fn input -> input |> then(&FSST.compress!(rust_table, &1)) |> then(&FSST.decompress!(rust_table, &1)) end
  },
  inputs: inputs,
  time: 2,
  warmup: 1,
  memory_time: 1,
  formatters: [Benchee.Formatters.Console]
)
