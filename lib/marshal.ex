defmodule Marshal do
  @moduledoc """
  Functions for decoding a Ruby object stored in binary Marshal format
  """

  @doc """
  Decode a complete Marshal object. The first two bytes are always the Marshal version.
  """
  def decode(<<major::size(8), minor::size(8), rest::binary>>) do
    {"#{major}.#{minor}", rest |> decode_element({%{}, %{}}) |> elem(0)}
  end

  # define TYPE_NIL         '0'
  defp decode_element(<<"0", rest::binary>>, cache), do: {nil, rest, cache}
  # define TYPE_TRUE        'T'
  defp decode_element(<<"T", rest::binary>>, cache), do: {true, rest, cache}
  # define TYPE_FALSE       'F'
  defp decode_element(<<"F", rest::binary>>, cache), do: {false, rest, cache}
  # define TYPE_FIXNUM      'i'
  defp decode_element(<<"i", rest::binary>>, cache) do
    {num, rest} = decode_fixnum(rest)
    {num, rest, cache}
  end

  # define TYPE_EXTENDED    'e'
  defp decode_element(<<"e", rest::binary>>, cache), do: decode_extended(rest, cache)
  # define TYPE_UCLASS      'C'
  defp decode_element(<<"C", rest::binary>>, cache), do: decode_usrclass(rest, cache)
  # define TYPE_OBJECT      'o'
  defp decode_element(<<"o", rest::binary>>, cache), do: decode_object_instance(rest, cache)
  # define TYPE_DATA        'd'
  defp decode_element(<<"d", _rest::binary>>, _cache), do: missing("DATA")
  # define TYPE_USERDEF     'u'
  defp decode_element(<<"u", rest::binary>>, cache), do: decode_usrdef(rest, cache)
  # define TYPE_USRMARSHAL  'U'
  defp decode_element(<<"U", rest::binary>>, cache), do: decode_usrmarshal(rest, cache)
  # define TYPE_FLOAT       'f'
  defp decode_element(<<"f", rest::binary>>, cache), do: decode_float(rest, cache)
  # define TYPE_BIGNUM      'l'
  defp decode_element(<<"l", rest::binary>>, cache), do: decode_bignum(rest, cache)
  # define TYPE_STRING      '"'
  defp decode_element(<<"\"", rest::binary>>, cache), do: decode_string(rest, cache)
  # define TYPE_REGEXP      '/'
  defp decode_element(<<"/", _rest::binary>>, _cache), do: missing("REGEXP")
  # define TYPE_ARRAY       '['
  defp decode_element(<<"[", rest::binary>>, cache), do: decode_array(rest, cache)
  # define TYPE_HASH        '{'
  defp decode_element(<<"{", rest::binary>>, cache), do: decode_hash(rest, cache)
  # define TYPE_HASH_DEF    '}'
  defp decode_element(<<"}", rest::binary>>, cache), do: decode_hashdef(rest, cache)
  # define TYPE_STRUCT      'S'
  defp decode_element(<<"S", rest::binary>>, cache), do: decode_struct(rest, cache)
  # define TYPE_MODULE_OLD  'M'
  defp decode_element(<<"M", _rest::binary>>, _cache), do: missing("MODULE_OLD")
  # define TYPE_CLASS       'c'
  defp decode_element(<<"c", rest::binary>>, cache), do: decode_class(rest, cache)
  # define TYPE_MODULE      'm'
  defp decode_element(<<"m", rest::binary>>, cache), do: decode_module(rest, cache)

  # define TYPE_SYMBOL      ':'
  defp decode_element(<<":", rest::binary>>, cache), do: decode_symbol(rest, cache)
  # define TYPE_SYMLINK     ';'
  defp decode_element(<<";", rest::binary>>, cache), do: fetch_symbol(rest, cache)

  # define TYPE_IVAR        'I'
  defp decode_element(<<"I", rest::binary>>, cache), do: decode_ivar(rest, cache)
  # define TYPE_LINK        '@'
  defp decode_element(<<"@", rest::binary>>, cache), do: fetch_object(rest, cache)

  defp decode_element(<<unknown::binary-size(1), _rest::binary>>, _cache), do: {:error, "Unknown Type: #{unknown}"}

  defp missing(type) do
    {{:error, "Type:#{type} is not currently supported"}}
  end

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

  defp decode_extended(bitstring, cache) do
    # Reserve cache
    cache = Cache.add_to_object_cache(bitstring, cache)

    # Object being extended
    {name, rest, cache} = decode_element(bitstring, cache)
    # Object data
    {object, rest, cache} = decode_element(rest, cache)

    extended = {:extended, name, object}

    cache = Cache.replace_object_cache(bitstring, extended, cache)
    {extended, rest, cache}
  end

  defp decode_usrclass(bitstring, cache) do
    # Reserve cache
    cache = Cache.add_to_object_cache(bitstring, cache)

    # Name is stored as a symbol
    {name, rest, cache} = decode_element(bitstring, cache)
    # Rest is stored as an element
    {data, rest, cache} = decode_element(rest, cache)

    usrclass = {:usrclass, name, data}

    cache = Cache.replace_object_cache(bitstring, usrclass, cache)
    {usrclass, rest, cache}
  end

  defp decode_object_instance(bitstring, cache) do
    # Reserve cache
    cache = Cache.add_to_object_cache(bitstring, cache)

    # Name is stored as a symbol.
    {name, rest, cache} = decode_element(bitstring, cache)
    {vars, rest, cache} = get_vars(rest, cache)
    object = {:object_instance, name, vars}

    cache = Cache.replace_object_cache(bitstring, object, cache)
    {object, rest, cache}
  end

  defp decode_usrdef(bitstring, cache) do
    # Name of the user defined type is stored as a symbol.
    {symbol, rest, cache} = decode_element(bitstring, cache)

    # Fetch the bare binary data. Extracting the data in the responsibility of the type.
    {size, rest} = decode_fixnum(rest)
    <<number::binary-size(size), rest::binary>> = rest

    usrdef = {:usrdef, symbol, number}

    cache = Cache.add_to_object_cache(usrdef, cache)
    {usrdef, rest, cache}
  end

  defp decode_usrmarshal(bitstring, cache) do
    # Name of the user defined marshal is stored as a symbol.
    {symbol, rest, cache} = decode_element(bitstring, cache)
    # Values are stored in an array.
    {values, rest, cache} = decode_element(rest, cache)

    {{:usrmarshal, symbol, values}, rest, cache}
  end

  defp decode_float(bitstring, cache) do
    # Floats are string representations of floats.
    {number, rest, cache} = decode_string(bitstring, cache)

    float =
      number
      |> Float.parse()
      |> elem(0)

    cache = Cache.add_to_object_cache(float, cache)
    {float, rest, cache}
  end

  defp decode_bignum(<<"+", rest::binary>>, cache), do: do_decode_bignum(rest, cache, 1)
  defp decode_bignum(<<"-", rest::binary>>, cache), do: do_decode_bignum(rest, cache, -1)
  defp do_decode_bignum(bitstring, cache, sign) do
    # Length of bignum is divided by 2 and stored in a fixnum
    {half_size, rest} = decode_fixnum(bitstring)
    bits = half_size * 2 * 8

    <<bignum::native-integer-size(bits), rest::binary>> = rest

    signed_bignum = sign * bignum

    cache = Cache.add_to_object_cache(signed_bignum, cache)
    {signed_bignum, rest, cache}
  end

  # Decode string
  defp decode_string(bitstring, cache) do
    # Get the number of characters in the string
    {size, rest} = decode_fixnum(bitstring)

    <<string::binary-size(size), rest::binary>> = rest
    {string, rest, cache}
  end

  defp decode_array(bitstring, cache) do
    # Get the size of the array
    {size, rest} = decode_fixnum(bitstring)

    # Add placeholder to cache
    cache = Cache.add_to_object_cache(bitstring, cache)

    # Decode array
    {array, rest, cache} = do_decode_array(rest, size, [], cache)

    # Replace placeholder with real object
    cache = Cache.replace_object_cache(bitstring, array, cache)

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
    cache = Cache.add_to_object_cache(bitstring, cache)

    # Decode hash
    {hash, rest, cache} = do_decode_hash(rest, size, %{}, cache)

    # Replace placeholder with real object
    cache = Cache.replace_object_cache(bitstring, hash, cache)

    {hash, rest, cache}
  end

  # Recursively extract elements from the hash until you've reached the end.
  defp do_decode_hash(rest, 0, acc, cache), do: {acc, rest, cache}
  defp do_decode_hash(rest, size, acc, cache) do
    {key, rest, cache} = decode_element(rest, cache)
    {value, rest, cache} = decode_element(rest, cache)

    do_decode_hash(rest, size - 1, Map.put(acc, key, value), cache)
  end

  defp decode_hashdef(bitstring, cache) do
    # Reserve cache
    cache = Cache.add_to_object_cache(bitstring, cache)

    # Get size of hash
    {size, rest} = decode_fixnum(bitstring)

    # Get hash values
    {hash, rest, cache} = do_decode_hash(rest, size, %{}, cache)

    # Get default value
    {default, rest, cache} = decode_element(rest, cache)

    default_hash = {:default_hash, hash, default}

    cache = Cache.replace_object_cache(bitstring, default_hash, cache)
    {default_hash, rest, cache}
  end
  defp decode_struct(bitstring, cache) do
    # Reserve cache
    cache = Cache.add_to_object_cache(bitstring, cache)

    {name, rest, cache} = decode_element(bitstring, cache)
    {size, rest} = decode_fixnum(rest)

    # Decode array
    {values, rest, cache} = do_decode_hash(rest, size, %{}, cache)

    struct = {:struct, name, values}
    # Replace placeholder with real object
    cache = Cache.replace_object_cache(bitstring, struct, cache)
    {struct, rest, cache}
  end

  defp decode_class(bitstring, cache) do
    # Class name is stored as a string
    {name, rest, cache} = decode_string(bitstring, cache)
    class = {:class, name}

    cache = Cache.add_to_object_cache(class, cache)

    {class, rest, cache}
  end

  defp decode_module(bitstring, cache) do
    # Module name is stored as a string
    {name, rest, cache} = decode_string(bitstring, cache)
    module = {:module, name}

    cache = Cache.add_to_object_cache(module, cache)

    {module, rest, cache}
  end

  defp decode_symbol(bitstring, cache) do
    # Decode string representation of symbol
    {symbol, rest, cache} = decode_string(bitstring, cache)

    # Convert to an atom and store in the cache
    atom =
      try do
        String.to_atom(symbol)
      rescue
        ArgumentError -> {:symbol, symbol}
      end
    cache = Cache.add_to_symbol_cache(atom, cache)

    {atom, rest, cache}
  end

  defp fetch_symbol(bitstring, cache) do
    # Get index of the symbol
    {index, rest} = decode_fixnum(bitstring)

    symbol = Cache.fetch_symbol(index, cache)
    {symbol, rest, cache}
  end


  # Decode an object with ivars
  defp decode_ivar(bitstring, cache) do
    # Reserve cache
    cache = Cache.add_to_object_cache(bitstring, cache)

    # Get the object
    {element, rest, cache} = decode_element(bitstring, cache)

    # Get the vars
    {vars, rest, cache} = get_vars(rest, cache)

    object = {element, vars}
    cache = Cache.replace_object_cache(bitstring, object, cache)

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

  defp fetch_object(bitstring, cache) do
    # Get index of the object
    {index, rest} = decode_fixnum(bitstring)

    object = Cache.fetch_object(index, cache)
    {object, rest, cache}
  end
end
