defmodule FSST.Pure do
  @moduledoc """
  Pure Elixir FSST backend.

  This is a compact, idiomatic implementation of the FSST wire shape: compressed
  data is a stream of one-byte symbol codes, with code `255` escaping raw bytes.
  The current trainer chooses frequent substrings up to eight bytes long and the
  encoder emits the longest matching symbol greedily.
  """

  @behaviour FSST.Backend

  import Bitwise, only: [|||: 2, <<<: 2, >>>: 2, &&&: 2]

  alias FSST.Table

  @escape 255
  @max_symbol_size 8
  @max_symbols 255
  @min_count 2

  @impl true
  def available?, do: true

  @impl true
  def train(samples, opts \\ [])

  def train(samples, opts) when is_list(samples) do
    if Enum.all?(samples, &is_binary/1) do
      symbols =
        samples
        |> sample_training_input(opts)
        |> candidates(opts)
        |> Enum.take(@max_symbols)
        |> Enum.map(&:binary.copy/1)

      codes = symbols |> Enum.with_index() |> Map.new()
      pattern = compile_pattern(symbols)
      lengths = symbols |> Enum.map(&byte_size/1) |> Enum.uniq() |> Enum.sort(:desc)

      {:ok,
       %Table{
         symbols: List.to_tuple(symbols),
         codes: codes,
         pattern: pattern,
         lengths: lengths,
         backend: __MODULE__
       }}
    else
      {:error, :invalid_sample}
    end
  end

  def train(_samples, _opts), do: {:error, :invalid_sample}

  @impl true
  def compress(%Table{codes: codes, pattern: pattern, lengths: lengths}, input)
      when is_binary(input) do
    {:ok, encode(input, codes, pattern, lengths, 0, byte_size(input), [])}
  end

  def compress(_table, _input), do: {:error, :invalid_input}

  @impl true
  def decompress(%Table{symbols: symbols}, input) when is_binary(input) do
    decode(input, symbols, [])
  end

  def decompress(_table, _input), do: {:error, :invalid_input}

  defp sample_training_input(samples, opts) do
    case Keyword.get(opts, :sample_bytes, 65_536) do
      :infinity ->
        samples

      limit when is_integer(limit) and limit > 0 ->
        take_sample_bytes(samples, limit, [])
    end
  end

  defp take_sample_bytes(_samples, remaining, acc) when remaining <= 0, do: Enum.reverse(acc)
  defp take_sample_bytes([], _remaining, acc), do: Enum.reverse(acc)

  defp take_sample_bytes([sample | rest], remaining, acc) do
    size = byte_size(sample)

    if size <= remaining do
      take_sample_bytes(rest, remaining - size, [sample | acc])
    else
      Enum.reverse([binary_part(sample, 0, remaining) | acc])
    end
  end

  defp candidates(samples, opts) do
    max_symbol_size = Keyword.get(opts, :max_symbol_size, @max_symbol_size)

    if total_byte_size(samples) >= Keyword.get(opts, :counter_min_bytes, 16_384) do
      counter_candidates(samples, max_symbol_size)
    else
      map_candidates(samples, max_symbol_size)
    end
  end

  defp total_byte_size(samples),
    do: Enum.reduce(samples, 0, fn sample, total -> total + byte_size(sample) end)

  defp counter_candidates(samples, max_symbol_size) do
    pair_counts = :counters.new(65_536, [:write_concurrency])

    longer_counts =
      Enum.reduce(samples, %{}, fn sample, counts ->
        count_sample(sample, counts, pair_counts, max_symbol_size)
      end)

    top_candidates(longer_counts, pair_counts)
  end

  defp map_candidates(samples, max_symbol_size) do
    samples
    |> Enum.reduce(%{}, &count_sample(&1, &2, max_symbol_size))
    |> top_candidates()
  end

  defp count_sample(sample, counts, max_symbol_size) do
    size = byte_size(sample)

    Enum.reduce(0..max(size - 1, 0)//1, counts, fn offset, acc ->
      max_len = min(max_symbol_size, size - offset)
      count_symbols(sample, offset, 1, max_len, :binary.at(sample, offset), acc)
    end)
  end

  defp count_sample(sample, counts, pair_counts, max_symbol_size) do
    size = byte_size(sample)

    Enum.reduce(0..max(size - 1, 0)//1, counts, fn offset, acc ->
      max_len = min(max_symbol_size, size - offset)
      first = :binary.at(sample, offset)

      if max_len >= 2 do
        second = :binary.at(sample, offset + 1)
        pair_key = first ||| second <<< 8
        :counters.add(pair_counts, pair_key + 1, 1)
        count_symbols(sample, offset, 2, max_len, pair_key, acc)
      else
        acc
      end
    end)
  end

  defp count_symbols(_sample, _offset, len, max_len, _key, counts) when len >= max_len, do: counts

  defp count_symbols(sample, offset, len, max_len, key, counts) do
    next_len = len + 1
    next_key = key ||| :binary.at(sample, offset + len) <<< (len * 8)
    counts = Map.update(counts, pack_key(next_len, next_key), 1, &(&1 + 1))
    count_symbols(sample, offset, next_len, max_len, next_key, counts)
  end

  defp top_candidates(counts) do
    counts
    |> Enum.flat_map(fn
      {_packed, count} when count < @min_count ->
        []

      {packed, count} ->
        {length, key} = unpack_key(packed)
        [{(length - 1) * count, count, length, key}]
    end)
    |> Enum.sort(:desc)
    |> Enum.take(@max_symbols)
    |> Enum.map(fn {_gain, _count, length, key} -> key_to_binary(key, length) end)
  end

  defp top_candidates(longer_counts, pair_counts) do
    longer_candidates =
      Enum.flat_map(longer_counts, fn
        {_packed, count} when count < @min_count ->
          []

        {packed, count} ->
          {length, key} = unpack_key(packed)
          [{(length - 1) * count, count, length, key}]
      end)

    pair_candidates =
      for key <- 0..65_535,
          count = :counters.get(pair_counts, key + 1),
          count >= @min_count do
        {count, count, 2, key}
      end

    (pair_candidates ++ longer_candidates)
    |> Enum.sort(:desc)
    |> Enum.take(@max_symbols)
    |> Enum.map(fn {_gain, _count, length, key} -> key_to_binary(key, length) end)
  end

  defp pack_key(length, key), do: length <<< 64 ||| key
  defp unpack_key(packed), do: {packed >>> 64, packed &&& 0xFFFF_FFFF_FFFF_FFFF}

  defp key_to_binary(key, length) do
    for offset <- 0..(length - 1), into: <<>> do
      <<key >>> (offset * 8) &&& 255>>
    end
  end

  defp compile_pattern([]), do: nil
  defp compile_pattern(symbols), do: :binary.compile_pattern(symbols)

  defp encode(_input, _codes, _pattern, _lengths, offset, size, acc) when offset >= size do
    acc |> Enum.reverse() |> IO.iodata_to_binary()
  end

  defp encode(input, codes, nil, lengths, offset, size, acc) do
    byte = :binary.at(input, offset)
    encode(input, codes, nil, lengths, offset + 1, size, [byte, @escape | acc])
  end

  defp encode(input, codes, pattern, lengths, offset, size, acc) do
    case direct_match(input, codes, lengths, offset, size) do
      {code, length} ->
        encode(input, codes, pattern, lengths, offset + length, size, [code | acc])

      :error ->
        byte = :binary.at(input, offset)
        encode(input, codes, pattern, lengths, offset + 1, size, [byte, @escape | acc])
    end
  end

  defp direct_match(_input, _codes, [], _offset, _size), do: :error

  defp direct_match(input, codes, [length | rest], offset, size) do
    if offset + length <= size do
      symbol = binary_part(input, offset, length)

      case codes do
        %{^symbol => code} -> {code, length}
        _ -> direct_match(input, codes, rest, offset, size)
      end
    else
      direct_match(input, codes, rest, offset, size)
    end
  end

  defp decode(<<>>, _symbols, acc), do: {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary()}
  defp decode(<<@escape>>, _symbols, _acc), do: {:error, :truncated_escape}

  defp decode(<<@escape, byte, rest::binary>>, symbols, acc),
    do: decode(rest, symbols, [byte | acc])

  defp decode(<<code, rest::binary>>, symbols, acc) when code < tuple_size(symbols) do
    decode(rest, symbols, [:erlang.element(code + 1, symbols) | acc])
  end

  defp decode(<<code, _rest::binary>>, _symbols, _acc), do: {:error, {:unknown_code, code}}
end
