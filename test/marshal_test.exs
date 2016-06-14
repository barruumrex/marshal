defmodule MarshalTest do
  use ExUnit.Case
  doctest Marshal

  test "Decode nil" do
    assert Marshal.decode("\x04\b0") == {"4.8", nil}
  end

  test "Decode True" do
    assert Marshal.decode("\x04\bT") == {"4.8", true}
  end

  test "Decode False" do
    assert Marshal.decode("\x04\bF") == {"4.8", false}
  end

  test "Decode 0" do
    assert Marshal.decode("\x04\bi\x00") == {"4.8", 0}
  end

  test "Decode 1" do
    assert Marshal.decode("\x04\bi\x06") == {"4.8", 1}
  end

  test "Decode -1" do
    assert Marshal.decode("\x04\bi\xFA") == {"4.8", -1}
  end

  test "Decode 500" do
    assert Marshal.decode("\x04\bi\x02\xF4\x01") == {"4.8", 500}
  end

  test "Decode -500" do
    assert Marshal.decode("\x04\bi\xFE\f\xFE") == {"4.8", -500}
  end

  test "Decode max fixnum" do
    assert Marshal.decode("\x04\bi\x04\xFF\xFF\xFF?") == {"4.8", 1073741823}
  end

  test "Decode min fixnum" do
    assert Marshal.decode("\x04\bi\xFC\x00\x00\x00\xC0") == {"4.8", -1073741824}
  end

  test "Decode empty array" do
    assert Marshal.decode("\x04\b[\x00") == {"4.8", []}
  end

  test "Array of ints" do
    assert Marshal.decode("\x04\b[\bi\x06i\ai\b") == {"4.8", [1, 2, 3]}
  end

  test "Mixed array" do
    assert Marshal.decode("\x04\b[\f0TFi\x06i\ai\bi\x04\xFF\xFF\xFF?") == {"4.8", [nil, true, false, 1, 2, 3, 1073741823]}
  end

  test "Nested array" do
    assert Marshal.decode("\x04\b[\b0[\aTF[\bi\x06i\ai\b") == {"4.8", [nil, [true, false], [1, 2, 3,]]}
  end

  test "Hash" do
    assert Marshal.decode("\x04\b{\x06i\x06i\a") == {"4.8", %{1 => 2}}
  end

  test "Decode symbol" do
    assert Marshal.decode("\x04\b:\napple") == {"4.8", :apple}
  end

  test "Decode symbol array" do
    assert Marshal.decode("\x04\b[\a:\napple:\vbanana") == {"4.8", [:apple, :banana]}
  end

  test "Decode repeated symbol array" do
    assert Marshal.decode("\x04\b[\b:\napple:\vbanana;\x00") == {"4.8", [:apple, :banana, :apple]}
  end

  test "Decode repeated symbol array with nesting" do
    assert Marshal.decode("\x04\b[\n:\napple:\vbanana;\x00[\a:\bcar;\x06;\a") == {"4.8", [:apple, :banana, :apple, [:car, :banana], :car]}
  end

  test "Decode string with UTF-8 set" do
    assert Marshal.decode("\x04\bI\"\napple\x06:\x06ET") == {"4.8", {"apple", [E: true]}}
  end

  test "Decode string with US-ASCII set" do
    assert Marshal.decode("\x04\bI\"\nhello\x06:\x06EF") == {"4.8", {"hello", [E: false]}}
  end

  test "Decode string with Shift_JIS set" do
    assert Marshal.decode("\x04\bI\"\nhello\x06:\rencoding\"\x0EShift_JIS") == {"4.8", {"hello", [encoding: "Shift_JIS"]}}
  end

  test "Repeated string" do
    hello = {"hello", [E: true]}
    assert Marshal.decode("\x04\b[\aI\"\nhello\x06:\x06ET@\x06") == {"4.8", [hello, hello]}
  end

  test "Arrays cache before internals" do
    a = {"a", [E: true]}
    assert Marshal.decode("\x04\b[\b[\x06I\"\x06a\x06:\x06ET[\x06@\a[\a@\a@\a") == {"4.8", [[a], [a], [a, a]]}
  end

  test "Hashes cache like arrays" do
    a = %{1 => 2}
    assert Marshal.decode("\x04\b[\b[\x06{\x06i\x06i\a[\x06@\a[\a@\a@\a") == {"4.8", [[a], [a], [a, a]]}
  end

  test "Translated string" do
    assert Marshal.decode("\x04\bI\"\x06\xC5\x06:\rencoding\"\x0EShift_JIS") == {"4.8", {<<0xC5>>, [encoding: "Shift_JIS"]}}
  end

  test "Decode string class" do
    assert Marshal.decode("\x04\bc\vString") == {"4.8", {:class, "String"}}
  end

  test "Decode Math::DomainError class" do
    assert Marshal.decode("\x04\bc\x16Math::DomainError") == {"4.8", {:class, "Math::DomainError"}}
  end

  test "Cached class" do
    class = {:class, "String"}
    object = %{1 => 2}
    assert Marshal.decode("\x04\b[\tc\vString{\x06i\x06i\a@\a@\x06") == {"4.8", [class, object, object, class]}
  end
end
