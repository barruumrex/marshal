defmodule UsrDef.Time do
  defstruct bitstream: <<>>, cache: {%{}, %{}}

end

defimpl Marshal.UsrDef, for: UsrDef.Time do
  def decode(%{bitstream: bits, cache: cache}) do

    # Fetch the bare binary data. Extracting the data in the responsibility of the type.
    {size, rest} = Marshal.decode_fixnum(bits)
    <<number::binary-size(size), rest::binary>> = rest

    {{:usrdef, :Time, number}, rest, cache}
  end
end
