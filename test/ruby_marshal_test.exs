defmodule RubyMarshalTest do
  @moduledoc """
  Transcribed tests from https://github.com/ruby/ruby/blob/de2f7416d2deb4166d78638a41037cb550d64484/test/ruby/test_marshal.rb
  """
  use ExUnit.Case

  test "test_marshal.rb:38" do
    a = "\x04\b[\fi\x06i\ai\b[\bi\ti\nI\"\bfoo\x06:\x06ET{\x06i\x06I\"\bbar\x06;\x00Tf\b2.5l+\f\x00\x00\x00T\xDD\xF5]\x86\x96\x0F7\xF6\x13\r"
    result = [1, 2, 3, [4, 5, {"foo", [E: true]}], %{1 => {"bar", [E: true]}}, 2.5, 265252859812191058636308480000000]
    assert Marshal.decode(a) == {"4.8", result}
  end
end
