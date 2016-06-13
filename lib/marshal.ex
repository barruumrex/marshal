defmodule Marshal do
  @moduledoc """
  Functions for decoding a Ruby object stored in binary Marshal format
  """

  @doc """
  Decode a complete Marshal object. The first two bytes are always the Marshal version.
  """
  def decode(<<major::size(8), minor::size(8), rest::binary>>) do
    {"#{major}.#{minor}", decode_element(rest, %{}) |> elem(0)}
  end

  # nil is stored as 0
  defp decode_element(<<"0", rest::binary>>, cache), do: {nil, rest, cache}
  # True is stored as T
  defp decode_element(<<"T", rest::binary>>, cache), do: {true, rest, cache}
  # False is stored as F
  defp decode_element(<<"F", rest::binary>>, cache), do: {false, rest, cache}
  # Small integers are preceded by the letter i
  defp decode_element(<<"i", rest::binary>>, cache) do
    {num, rest} = decode_fixnum(rest)
    {num, rest, cache}
  end
  # Arrays are preceded by the character [
  defp decode_element(<<"[", rest::binary>>, cache), do: decode_array(rest, cache)
  # Symbols are preceded by the characer :
  defp decode_element(<<":", rest::binary>>, cache), do: decode_symbol(rest, cache)
  # Symbol links are preceded by the character ;
  defp decode_element(<<";", rest::binary>>, cache), do: fetch_symbol(rest, cache)
  defp decode_element(<<"I", rest::binary>>, cache), do: decode_ivar(rest, cache)
  defp decode_element(<<"\"", rest::binary>>, cache), do: decode_string(rest, cache)

  # Small integers are called fixnums
  # If the first byte is zero, the number is zero.
  defp decode_fixnum(<<0, rest::binary>>), do: {0, rest}
  # If the first byte is larger than five, it's a whole positive integer
  defp decode_fixnum(<<num::signed-little-integer, rest::binary>>) when num > 5, do: {num - 5, rest}
  # If the first byte is less than negative five, it's a whole negative integer
  defp decode_fixnum(<<num::signed-little-integer, rest::binary>>) when num < -5, do: {num + 5, rest}
  # Otherwise, the first byte indicates how large the integer is in bytes
  defp decode_fixnum(<<size::signed-little-integer, rest::binary>>) when abs(size) < 5 do
    decode_multibyte_fixnum(abs(size), rest)
  end

  # Exctract the rest of the integer depending on the byte size
  defp decode_multibyte_fixnum(4, <<num::signed-little-integer-size(32), rest::binary>>), do: {num, rest}
  defp decode_multibyte_fixnum(3, <<num::signed-little-integer-size(24), rest::binary>>), do: {num, rest}
  defp decode_multibyte_fixnum(2, <<num::signed-little-integer-size(16), rest::binary>>), do: {num, rest}
  defp decode_multibyte_fixnum(1, <<num::signed-little-integer-size(8), rest::binary>>), do: {num, rest}

  defp decode_array(bitstring, cache) do
    # Get the size of the array
    {size, rest} = decode_fixnum(bitstring)

    do_decode_array(rest, size, [], cache)
  end

  # Recursively extract elements from the array until you've reached the end.
  defp do_decode_array(rest, 0, acc, cache), do: {Enum.reverse(acc), rest, cache}
  defp do_decode_array(rest, size, acc, cache) do
    {element, rest, cache} = decode_element(rest, cache)

    do_decode_array(rest, size - 1, [element | acc], cache)
  end

  defp decode_symbol(bitstring, cache) do

    # Decode string representation of symbol
    {symbol, rest, cache} = decode_string(bitstring, cache)

    # Convert to an atom and store in the cache
    atom = String.to_atom(symbol)
    cache = add_to_cache(atom, cache)

    {atom, rest, cache}
  end

  # Retrieve the specified number of characters from the bitstring
  defp get_utf8_string(string, length), do: do_get_utf8_string(string, length, [])

  defp do_get_utf8_string(rest, 0, acc), do: {acc |> Enum.reverse() |> to_string(), rest}
  defp do_get_utf8_string(<<head::utf8, rest::binary>>, size, acc) do
    do_get_utf8_string(rest, size - 1, [head | acc])
  end

  # Symbols that are reused get stored as references. Maintain a cache for future references
  defp add_to_cache(symbol, cache) do
    Map.put_new_lazy(cache, symbol, fn -> get_next_index(cache) end)
  end

  defp get_next_index(cache), do: do_get_next_index(Map.values(cache))

  defp do_get_next_index([]), do: 0
  defp do_get_next_index(indices), do: indices |> Enum.max() |> increment()

  defp increment(value), do: value + 1

  # Retrieve a symbole from the cache
  defp fetch_symbol(bitstring, cache) do
    {index, rest} = decode_fixnum(bitstring)

    {atom, _} = Enum.find(cache, fn({_, i}) -> i == index end)
    {atom, rest, cache}
  end

  # Decode an object with ivars
  defp decode_ivar(bitstring, cache) do
    #Get the object
    {element, rest, cache} = decode_element(bitstring, cache)
    #Get the number of vars
    {size, rest} = decode_fixnum(rest)
    #Get the vars
    {vars, rest, cache} = get_ivars(rest, size, cache)

    {{element, vars}, rest, cache}
  end

  # Recursively fetch ivars
  defp get_ivars(bitstring, size, cache), do: do_get_ivars(bitstring, size, [], cache)

  defp do_get_ivars(rest, 0, acc, cache), do: {acc |> Enum.reverse(), rest, cache}
  defp do_get_ivars(bitstring, size, acc, cache) do
    # Get var symbol
    {symbol, rest, cache} = decode_element(bitstring, cache)
    # Get var value
    {value, rest, cache} = decode_element(rest, cache)

    do_get_ivars(rest, size - 1, [{symbol, value} | acc], cache)
  end

  # Decode UTF-8 encoded string
  def  decode_string(bitstring, cache) do
    # Get the number of characters in the string
    {length, rest} = decode_fixnum(bitstring)
    # Strings are stored as utf8
    {string, rest} = get_utf8_string(rest, length)
    {string, rest, cache}
  end
end
