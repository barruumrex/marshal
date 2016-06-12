defmodule Marshal do

  def decode(<<major::size(8), minor::size(8), rest::binary>>), do: {"#{major}.#{minor}", decode_element(rest)}

  defp decode_element(<<"0">>), do: nil
  defp decode_element(<<"T">>), do: true
  defp decode_element(<<"F">>), do: false
  defp decode_element(<<"i", rest::binary>>), do: decode_fixnum(rest)
  defp decode_element(rest), do: rest

  defp decode_fixnum(<<0>>), do: 0
  defp decode_fixnum(<<num::signed-little-integer, rest::binary>>) when abs(num) < 5, do: decode_multibyte_fixnum(abs(num), rest)
  defp decode_fixnum(<<num::signed-little-integer>>) when num > 0, do: num - 5
  defp decode_fixnum(<<num::signed-little-integer>>) when num < 0, do: num + 5

  defp decode_multibyte_fixnum(4, <<num::signed-little-integer-size(32)>>), do: num
  defp decode_multibyte_fixnum(3, <<num::signed-little-integer-size(24)>>), do: num
  defp decode_multibyte_fixnum(2, <<num::signed-little-integer-size(16)>>), do: num
  defp decode_multibyte_fixnum(1, <<num::signed-little-integer-size(8)>>), do: num
end
