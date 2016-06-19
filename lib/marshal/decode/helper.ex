defmodule Marshal.Decode.Helper do
  @moduledoc """
  Helper functions for pulling apart Marshal binary
  """

  @doc """
  Retrieve key-value pairs of variables.

  # Examples

      iex> Marshal.Decode.Helper.get_vars("\a:\x06ET:\a@zi\x06", {%{}, %{}})
      {[E: true, "@z": 1], "", {%{0 => :E, 1 => :"@z"}, %{}}}
  """
  def get_vars(bitstring, cache) do
    #Get the number of vars
    {size, rest} = Marshal.decode_fixnum(bitstring)

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
