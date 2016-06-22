defmodule UsrDef.Time do
  defstruct bitstream: <<>>, cache: {%{}, %{}}

end

defimpl Marshal.UsrDef, for: UsrDef.Time do
  def decode(%{bitstream: bits, cache: cache}) do

    # Fetch the bare binary data. Extracting the data in the responsibility of the type.
    {size, rest} = Marshal.Decode.Helper.decode_fixnum(bits)
    <<number::binary-size(size), rest::binary>> = rest

    usrdef = {:usrdef, :Time, decode_time(number)}

    # Manually get_tuples
    {vars, rest, cache} = Marshal.Decode.Helper.get_tuples(rest, cache)

    # Add 0 to the front of the remainder to prevent ivars from breaking
    rest = <<0>> <> rest

    {{usrdef, vars}, rest, cache}
  end

  defp decode_time(bits) do
    bits
    |> fix_order()
    |> unpack()
  end

  defp fix_order(<<p4, p3, p2, p1, s4, s3, s2, s1>>), do: <<p1, p2, p3, p4, s1, s2, s3, s4>>

  defp unpack(<<1::1, utc_p::1, year::16, month::4, day::5, hour::5, min::6, sec::6, usec::20>>) do
    year = year + 1900
    month = month + 1

    {:ok, date} = Date.new(year, month, day)
    {:ok, time} = Time.new(hour, min, sec, usec)
    {date, time}
  end

end
