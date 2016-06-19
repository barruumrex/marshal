defprotocol Marshal.UsrDef do
  @moduledoc """
  Protocol for decoding user defined classes from binary marshal format.
  """

  @doc "Return representation of class"
  def decode(usrdef)
end
