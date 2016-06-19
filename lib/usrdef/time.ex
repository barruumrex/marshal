defmodule UsrDef.Time do
  defstruct bitstream: <<>>, cache: {%{}, %{}}

end

defimpl Marshal.UsrDef, for: UsrDef.Time do
  def decode(%{bitstream: bits, cache: cache}) do

    # Fetch the bare binary data. Extracting the data in the responsibility of the type.
    {size, rest} = Marshal.decode_fixnum(bits)
    <<number::binary-size(size), rest::binary>> = rest

    usrdef = {:usrdef, :Time, number}

    # Manually get_vars
    {vars, rest, cache} = Marshal.Helpers.get_vars(rest, cache)

    # Add 0 to the front of the remainder to prevent ivars from breaking
    rest = <<0>> <> rest

    {{usrdef, vars}, rest, cache}
  end

end
