defmodule Marshal do

  def decode(<<major::size(8), minor::size(8), rest::binary>>) do
    {"#{major}.#{minor}", decode_element(rest) |> elem(0)}
  end

  defp decode_element(<<"0", rest::binary>>), do: {nil, rest}
  defp decode_element(<<"T", rest::binary>>), do: {true, rest}
  defp decode_element(<<"F", rest::binary>>), do: {false, rest}
  defp decode_element(<<"i", rest::binary>>), do: decode_fixnum(rest)
  defp decode_element(<<"[", rest::binary>>), do: decode_array(rest)
  defp decode_element(<<":", rest::binary>>), do: decode_symbol(rest)
  defp decode_element(rest), do: rest

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

  defp decode_array(<<0, rest::binary>>), do: {[], rest}
  defp decode_array(bitstring) do
    {size, rest} = decode_fixnum(bitstring)

    do_decode_array(rest, size, [])
  end

  defp do_decode_array(rest, 0, acc), do: {Enum.reverse(acc), rest}
  defp do_decode_array(rest, size, acc) do
    {element, rest} = decode_element(rest)

    do_decode_array(rest, size - 1, [element | acc])
  end

  defp decode_symbol(bitstring) do
    {size, rest} = decode_fixnum(bitstring) |> IO.inspect
    {symbol, rest} = get_utf8_string(rest, size, [])

    {String.to_atom(symbol), rest}
  end

  defp get_utf8_string(rest, 0, acc), do: {acc |> Enum.reverse() |> to_string(), rest}
  defp get_utf8_string(<<head::utf8, rest::binary>>, size, acc) do
    get_utf8_string(rest, size - 1, [head | acc])
  end
end
