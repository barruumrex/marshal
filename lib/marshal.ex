defmodule Marshal do

  def decode(<<major::size(8), minor::size(8), rest::binary>>) do
    {"#{major}.#{minor}", decode_element(rest, %{}) |> elem(0)}
  end

  defp decode_element(<<"0", rest::binary>>, cache), do: {nil, rest, cache}
  defp decode_element(<<"T", rest::binary>>, cache), do: {true, rest, cache}
  defp decode_element(<<"F", rest::binary>>, cache), do: {false, rest, cache}
  defp decode_element(<<"i", rest::binary>>, cache) do
    {num, rest} = decode_fixnum(rest)
    {num, rest, cache}
  end
  defp decode_element(<<"[", rest::binary>>, cache), do: decode_array(rest, cache)
  defp decode_element(<<":", rest::binary>>, cache), do: decode_symbol(rest, cache)
  defp decode_element(<<";", rest::binary>>, cache), do: fetch_symbol(rest, cache)

  defp decode_fixnum(<<0, rest::binary>>), do: {0, rest}
  defp decode_fixnum(<<num::signed-little-integer, rest::binary>>) when num > 5, do: {num - 5, rest}
  defp decode_fixnum(<<num::signed-little-integer, rest::binary>>) when num < -5, do: {num + 5, rest}
  defp decode_fixnum(<<size::signed-little-integer, rest::binary>>) when abs(size) < 5 do
    decode_multibyte_fixnum(abs(size), rest)
  end

  defp decode_multibyte_fixnum(4, <<num::signed-little-integer-size(32), rest::binary>>), do: {num, rest}
  defp decode_multibyte_fixnum(3, <<num::signed-little-integer-size(24), rest::binary>>), do: {num, rest}
  defp decode_multibyte_fixnum(2, <<num::signed-little-integer-size(16), rest::binary>>), do: {num, rest}
  defp decode_multibyte_fixnum(1, <<num::signed-little-integer-size(8), rest::binary>>), do: {num, rest}

  defp decode_array(<<0, rest::binary>>, cache), do: {[], rest, cache}
  defp decode_array(bitstring, cache) do
    {size, rest} = decode_fixnum(bitstring)

    do_decode_array(rest, size, [], cache)
  end

  defp do_decode_array(rest, 0, acc, cache), do: {Enum.reverse(acc), rest, cache}
  defp do_decode_array(rest, size, acc, cache) do
    {element, rest, cache} = decode_element(rest, cache)

    do_decode_array(rest, size - 1, [element | acc], cache)
  end

  defp decode_symbol(bitstring, cache) do
    {size, rest} = decode_fixnum(bitstring)
    {symbol, rest} = get_utf8_string(rest, size, [])

    atom = String.to_atom(symbol)
    cache = add_to_cache(atom, cache)

    {atom, rest, cache}
  end

  defp get_utf8_string(rest, 0, acc), do: {acc |> Enum.reverse() |> to_string(), rest}
  defp get_utf8_string(<<head::utf8, rest::binary>>, size, acc) do
    get_utf8_string(rest, size - 1, [head | acc])
  end

  defp add_to_cache(symbol, cache) do
    Map.put_new_lazy(cache, symbol, fn -> get_next_index(cache) end)
  end

  defp get_next_index(cache), do: do_get_next_index(Map.values(cache))

  defp do_get_next_index([]), do: 0
  defp do_get_next_index(indices), do: indices |> Enum.max() |> increment()

  defp increment(value), do: value + 1

  defp fetch_symbol(bitstring, cache) do
    {index, rest} = decode_fixnum(bitstring)

    {atom, _} = Enum.find(cache, fn({_, i}) -> i == index end)
    {atom, rest, cache}
  end
end
