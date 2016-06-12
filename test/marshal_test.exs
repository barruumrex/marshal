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

  test "Decode symbol" do
    assert Marshal.decode("\x04\b:\napple") == {"4.8", :apple}
  end

  test "Decode symbol array" do
    assert Marshal.decode("\x04\b[\a:\napple:\vbanana") == {"4.8", [:apple, :banana]}
  end
end
