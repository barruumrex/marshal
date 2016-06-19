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
  Retrieve key-value pairs of variables from Marshal binary.

  # Examples

      iex> Marshal.Decode.Helper.get_vars("\a:\x06ET:\a@zi\x06", {%{}, %{}})
      {[E: true, "@z": 1], "", {%{0 => :E, 1 => :"@z"}, %{}}}
  """
  def get_vars(bitstring, cache) do
    #Get the number of vars
    {size, rest} = Marshal.Decode.Helper.decode_fixnum(bitstring)

    do_get_ivars(rest, size, [], cache)
  end

  defp do_get_ivars(rest, 0, acc, cache), do: {acc |> Enum.reverse(), rest, cache}
  defp do_get_ivars(bitstring, size, acc, cache) do
    # Get var symbol
    {symbol, rest, cache} = Marshal.decode_element(bitstring, cache)
    # Get var value
    {value, rest, cache} = Marshal.decode_element(rest, cache)

    do_get_ivars(rest, size - 1, [{symbol, value} | acc], cache)
  end
end
