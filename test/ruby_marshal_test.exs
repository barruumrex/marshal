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

  test "test_marshal.rb:42" do
    marshal = "\x04\bf\x163.956015276338614"
    float = 3.956015276338614
    assert Marshal.decode(marshal) == {"4.8", float}

    marshal = "\x04\bf\x193.751767503646127e17"
    float = 375176750364612700.0
    assert Marshal.decode(marshal) == {"4.8", float}
  end

  test "test_marshal.rb:53" do
    marshal = "\x04\bIC:\rStrClone\"\babc\x06:\x06ET"
    usrclass = {{:usrclass, :StrClone, "abc"}, [E: true]}
    assert Marshal.decode(marshal) == {"4.8", usrclass}
  end

  test "test_marshal.rb:97" do
    marshal = "\x04\bIu:\x06C\a\xA4\xA4\x06:\rencoding\"\vEUC-JP"
    usrdef = {{:usrdef, :C, <<164, 164>>}, [encoding: "EUC-JP"]}
    assert Marshal.decode(marshal) == {"4.8", usrdef}
  end

  test "test_marshal.rb:125" do
    assert Marshal.decode("\x04\b[\x06[\x06[\x00") == {"4.8", [[[]]]}
  end

  test "test_marshal.rb:127" do
    marshal = "\x04\bI\"\b\xE3\x81\x82\x06:\x06ET"
    string = {"あ", [E: true]}
    assert Marshal.decode(marshal) == {"4.8", string}
  end

  test "test_marshal.rb:169" do
    marshal = "\x04\bS:\aC3\a:\bfooI\"\bFOO\x06:\x06ET:\bbarI\"\bBAR\x06;\aT"
    struct = {:struct, :C3, %{bar: {"BAR", [E: true]}, foo: {"FOO", [E: true]}}}
    assert Marshal.decode(marshal) == {"4.8", struct}
  end
end
