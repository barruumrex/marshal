defmodule UsrDef.Time do
  defstruct bitstream: <<>>, cache: {%{}, %{}}

end

defimpl Marshal.UsrDef, for: UsrDef.Time do
  def decode(%{bitstream: bits, cache: cache}) do

    # Fetch the bare binary data. Extracting the data in the responsibility of the type.
    {size, rest} = Marshal.decode_fixnum(bits)
    <<number::binary-size(size), rest::binary>> = rest

    usrdef = {:usrdef, :Time, number}

    {vars, rest, cache} = get_vars(rest, cache)

    {{usrdef, vars}, <<0>> <> rest, cache}
  end

  # Recursively fetch ivars
  defp get_vars(bitstring, cache) do
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
