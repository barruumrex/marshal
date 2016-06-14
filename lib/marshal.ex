defmodule Marshal do
  @moduledoc """
  Functions for decoding a Ruby object stored in binary Marshal format
  """

  @doc """
  Decode a complete Marshal object. The first two bytes are always the Marshal version.
  """
  def decode(<<major::size(8), minor::size(8), rest::binary>>) do
    {"#{major}.#{minor}", decode_element(rest, {%{}, %{}}) |> elem(0)}
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
  defp decode_element(<<"{", rest::binary>>, cache), do: decode_hash(rest, cache)
  # Symbols are preceded by the characer :
  defp decode_element(<<":", rest::binary>>, cache), do: decode_symbol(rest, cache)
  # Symbol links are preceded by the character ;
  defp decode_element(<<";", rest::binary>>, cache), do: fetch_symbol(rest, cache)
  defp decode_element(<<"I", rest::binary>>, cache), do: decode_ivar(rest, cache)
  defp decode_element(<<"\"", rest::binary>>, cache), do: decode_string(rest, cache)
  defp decode_element(<<"@", rest::binary>>, cache), do: fetch_object(rest, cache)
  defp decode_element(<<"c", rest::binary>>, cache), do: decode_class(rest, cache)
  defp decode_element(<<"m", rest::binary>>, cache), do: decode_module(rest, cache)
  defp decode_element(<<"o", rest::binary>>, cache), do: decode_object_instance(rest, cache)
  defp decode_element(<<"f", rest::binary>>, cache), do: decode_float(rest, cache)

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

    # Add placeholder to cache
    cache = add_to_object_cache(bitstring, cache)

    # Decode array
    {array, rest, cache} = do_decode_array(rest, size, [], cache)

    # Replace placeholder with real object
    cache = replace_object_cache(bitstring, array, cache)

    {array, rest, cache}
  end

  # Recursively extract elements from the array until you've reached the end.
  defp do_decode_array(rest, 0, acc, cache), do: {Enum.reverse(acc), rest, cache}
  defp do_decode_array(rest, size, acc, cache) do
    {element, rest, cache} = decode_element(rest, cache)

    do_decode_array(rest, size - 1, [element | acc], cache)
  end

  defp decode_hash(bitstring, cache) do
    # Get the size of the hash
    {size, rest} = decode_fixnum(bitstring)

    # Add placeholder to cache
    cache = add_to_object_cache(bitstring, cache)

    # Decode hash
    {hash, rest, cache} = do_decode_hash(rest, size, %{}, cache)

    # Replace placeholder with real object
    cache = replace_object_cache(bitstring, hash, cache)

    {hash, rest, cache}
  end

  # Recursively extract elements from the hash until you've reached the end.
  defp do_decode_hash(rest, 0, acc, cache), do: {acc, rest, cache}
  defp do_decode_hash(rest, size, acc, cache) do
    {key, rest, cache} = decode_element(rest, cache)
    {value, rest, cache} = decode_element(rest, cache)

    do_decode_hash(rest, size - 1, Map.put(acc, key, value), cache)
  end

  defp decode_symbol(bitstring, cache) do

    # Decode string representation of symbol
    {symbol, rest, cache} = decode_string(bitstring, cache)

    # Convert to an atom and store in the cache
    atom = String.to_atom(symbol)
    cache = add_to_symbol_cache(atom, cache)

    {atom, rest, cache}
  end

  # Symbols that are reused get stored as references. Maintain a cache for future reference
  defp add_to_symbol_cache(symbol, {symbol_cache, object_cache}) do
    {add_to_cache(symbol, symbol_cache), object_cache}
  end

  # Objects that are reused get stored as references. Maintain a cache for future reference
  defp add_to_object_cache(object, {symbol_cache, object_cache}) do
    {symbol_cache, add_to_cache(object, object_cache)}
  end

  defp replace_object_cache(old, new, {symbol_cache, object_cache}) do
    ref = object_cache[old]

    object_cache =
      object_cache
      |> Map.delete(old)
      |> Map.put(new, ref)

    {symbol_cache, object_cache}
  end

  # Add to cache if ref isn't already there
  defp add_to_cache(element, cache) do
    Map.put_new_lazy(cache, element, fn -> get_next_index(cache) end)
  end

  defp get_next_index(cache), do: do_get_next_index(Map.values(cache))

  defp do_get_next_index([]), do: 0
  defp do_get_next_index(indices), do: indices |> Enum.max() |> increment()

  defp increment(value), do: value + 1

  # Retrieve a symbol from the cache
  defp fetch_symbol(bitstring, {symbol_cache, _object_cache} = cache) do
    {atom, rest} = fetch_from_cache(bitstring, symbol_cache)
    {atom, rest, cache}
  end

  # Retrieve an object from the cache
  defp fetch_object(bitstring, {_symbol_cache, object_cache} = cache) do
    decode_fixnum(bitstring)
    {atom, rest} = fetch_from_cache(bitstring, object_cache)
    {atom, rest, cache}
  end

  defp fetch_from_cache(bitstring, cache) do
    # Get reference index
    {index, rest} = decode_fixnum(bitstring)

    # Retrieve element
    {element, _} = Enum.find(cache, fn({_, i}) -> i == index end)
    {element, rest}
  end

  # Decode an object with ivars
  defp decode_ivar(bitstring, cache) do
    #Get the object
    {element, rest, cache} = decode_element(bitstring, cache)

    #Get the vars
    {vars, rest, cache} = get_vars(rest, cache)

    object = {element, vars}
    cache = add_to_object_cache(object, cache)

    {object, rest, cache}
  end

  # Recursively fetch ivars
  defp get_vars(bitstring, cache) do
    #Get the number of vars
    {size, rest} = decode_fixnum(bitstring)

    do_get_ivars(rest, size, [], cache)
  end

  defp do_get_ivars(rest, 0, acc, cache), do: {acc |> Enum.reverse(), rest, cache}
  defp do_get_ivars(bitstring, size, acc, cache) do
    # Get var symbol
    {symbol, rest, cache} = decode_element(bitstring, cache)
    # Get var value
    {value, rest, cache} = decode_element(rest, cache)

    do_get_ivars(rest, size - 1, [{symbol, value} | acc], cache)
  end

  # Decode string
  defp decode_string(bitstring, cache) do
    # Get the number of characters in the string
    {length, rest} = decode_fixnum(bitstring)

    <<string::binary-size(length), rest::binary>> = rest
    {string, rest, cache}
  end

  defp decode_class(bitstring, cache) do
    {name, rest, cache} = decode_string(bitstring, cache)
    class = {:class, name}

    cache = add_to_object_cache(class, cache)

    {class, rest, cache}
  end

  defp decode_module(bitstring, cache) do
    {name, rest, cache} = decode_string(bitstring, cache)
    module = {:module, name}

    cache = add_to_object_cache(module, cache)

    {module, rest, cache}
  end

  defp decode_object_instance(bitstring, cache) do
    # Name is stored as a symbol
    {name, rest, cache} = decode_element(bitstring, cache)
    {vars, rest, cache} = get_vars(rest, cache)
    object = {:object_instance, name, vars}

    cache = add_to_object_cache(object, cache)
    {object, rest, cache}
  end

  defp decode_float(bitstring, cache) do
    {size, rest} = decode_fixnum(bitstring)
    <<number::binary-size(size), rest::binary>> = rest
    float =
      number
      |> Float.parse()
      |> elem(0)

    cache = add_to_object_cache(float, cache)
    {float, rest, cache}
  end
end
