defmodule Marshal.Decode.Helper do
  @moduledoc """
  Helper functions for pulling apart Marshal binary
  """

  @doc """
  Retrieve fixnum from Marshal binary.

  # Examples

      iex> Marshal.Decode.Helper.decode_fixnum(<<0>>)
      {0, <<>>}

      iex> Marshal.Decode.Helper.decode_fixnum(<<3, 64, 226, 1>>)
      {123456, <<>>}

      iex> Marshal.Decode.Helper.decode_fixnum(<<253, 192, 29, 254>>)
      {-123456, <<>>}
  """
  # If the first byte is zero, the number is zero.
  def decode_fixnum(<<0, rest::binary>>), do: {0, rest}
  # If the first byte is larger than five, it's a whole positive integer
  def decode_fixnum(<<num::signed-little-integer, rest::binary>>) when num > 5, do: {num - 5, rest}
  # If the first byte is less than negative five, it's a whole negative integer
  def decode_fixnum(<<num::signed-little-integer, rest::binary>>) when num < -5, do: {num + 5, rest}
  # Otherwise, the first byte indicates how large the integer is in bytes
  def decode_fixnum(<<size::signed-little-integer, rest::binary>>) when abs(size) < 5 do
    decode_multibyte_fixnum(abs(size), rest)
  end

  # Exctract the rest of the integer depending on the byte size
  defp decode_multibyte_fixnum(4, <<num::signed-little-integer-size(32), rest::binary>>), do: {num, rest}
  defp decode_multibyte_fixnum(3, <<num::signed-little-integer-size(24), rest::binary>>), do: {num, rest}
  defp decode_multibyte_fixnum(2, <<num::signed-little-integer-size(16), rest::binary>>), do: {num, rest}
  defp decode_multibyte_fixnum(1, <<num::signed-little-integer-size(8), rest::binary>>), do: {num, rest}

  @doc """
  Retrieve string binary representation from Marshal binary.

  # Examples

      iex> Marshal.Decode.Helper.decode_string("\ttest")
      {"test", ""}
  """
  def decode_string(bitstring) do
    # Get the number of characters in the string
    {size, rest} = decode_fixnum(bitstring)

    <<string::binary-size(size), rest::binary>> = rest
    {string, rest}
  end

  @doc """
  Retrieve key-value pairs of variables from Marshal binary.

  # Examples

      iex> Marshal.Decode.Helper.get_tuples("\a:\x06ET:\a@zi\x06", {%{}, %{}})
      {[E: true, "@z": 1], "", {%{0 => :E, 1 => :"@z"}, %{}}}
  """
  def get_tuples(bitstring, cache) do
    decode_list(bitstring, cache, &get_keyval/1)
  end

  @doc """
  Retrieve variable list from Marshal binary.

  # Examples

      iex> Marshal.Decode.Helper.get_vars("\t:\x06ET:\a@zi\x06", {%{}, %{}})
      {[:E, true, :"@z", 1], "", {%{0 => :E, 1 => :"@z"}, %{}}}
  """
  def get_vars(bitstring, cache) do
    decode_list(bitstring, cache, &get_val/1)
  end

  defp decode_list(bitstring, cache, decoder) do
    #Get the number of vars
    {size, rest} = decode_fixnum(bitstring)

    {list, rest, cache} =
      {rest, cache}
      |> Stream.unfold(decoder)
      |> Stream.take(size)
      |> collect_list(rest, cache)

    {Enum.reverse(list), rest, cache}
  end

  defp collect_list(bitstream, init_bits, cache) do
    bitstream
    |> Enum.reduce({[], init_bits, cache}, &combine_elements/2)
  end
  defp combine_elements({element, bits, cache}, {acc, _, _}), do: {[element | acc], bits, cache}

  defp get_keyval({"", _cache}), do: nil
  defp get_keyval({bitstring, cache}) do
    # Get var symbol
    {symbol, rest, cache} = Marshal.decode_element(bitstring, cache)
    # Get var value
    {value, rest, cache} = Marshal.decode_element(rest, cache)
    {{{symbol, value}, rest, cache}, {rest, cache}}
  end

  defp get_val({"", _cache}), do: nil
  defp get_val({bitstring, cache}) do
    # Get value
    {value, rest, cache} = Marshal.decode_element(bitstring, cache)
    {{value, rest, cache}, {rest, cache}}
  end
end
