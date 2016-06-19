defprotocol Marshal.UsrDef do
  @moduledoc """
  Protocol for decoding user defined classes from binary marshal format.
  """

  @doc "Return representation of class"
  def decode(usrdef)
end

# Default implementation for decoding usrdefs.
defimpl Marshal.UsrDef, for: Map do
  def decode(%{bitstream: bits, cache: cache, name: name}) do

    # Fetch the bare binary data.
    {size, rest} = Marshal.decode_fixnum(bits)
    <<number::binary-size(size), rest::binary>> = rest

    usrdef = {:usrdef, name, number}
    {usrdef, rest, cache}
  end
end
