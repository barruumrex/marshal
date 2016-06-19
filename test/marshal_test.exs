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

  test "Decode module Enumerable" do
    assert Marshal.decode("\x04\bm\x0FEnumerable") == {"4.8", {:module, "Enumerable"}}
  end

  test "Cached module" do
    module = {:module, "Enumerable"}
    object = %{1 => 2}
    assert Marshal.decode("\x04\b[\tm\x0FEnumerable{\x06i\x06i\a@\a@\x06") == {"4.8", [module, object, object, module]}
  end

  test "Decode user object instance" do
    object_instance = {:object_instance, :DumpTest, ["@a": nil]}
    assert Marshal.decode("\x04\bo:\rDumpTest\x06:\a@a0") == {"4.8", object_instance}
  end

  test "Cache user object instance" do
    object_instance = {:object_instance, :DumpTest, ["@a": nil]}
    assert Marshal.decode("\x04\b[\ao:\rDumpTest\x06:\a@a0@\x06") == {"4.8", [object_instance, object_instance]}
  end

  test "Decode float" do
    assert Marshal.decode("\x04\bf\x0E12.256611") == {"4.8", 12.256611}
  end

  test "Cache float" do
    assert Marshal.decode("\x04\b[\af\n12.11@\x06") == {"4.8", [12.11, 12.11]}
  end

  test "Decode U type" do
    date_marshal = "\x04\bU:\rDateTime[\vi\x00i\x03\xD2\x7F%i\x02\x9A\xEFi\x04H\xFA\xAF!i\xFE\xC0\xC7f\f2299161"
    date = {:usrmarshal, :DateTime, [0, 2457554, -4198, 565181000, -14400, 2299161.0]}
    assert Marshal.decode(date_marshal) == {"4.8", date}
  end

  test "Decode u type" do
    time_marshal = "\x04\bIu:\tTime\r\xD4\x15\x1D\x80\xCB\xA4\xA8\x9D\a:\voffseti\xFE\xC0\xC7:\tzoneI\"\bEDT\x06:\x06EF"
    time = {{:usrdef, :Time, <<212, 21, 29, 128, 203, 164, 168, 157>>}, [offset: -14400, zone: {"EDT", [E: false]}]}
    assert Marshal.decode(time_marshal) == {"4.8", time}
  end

  test "Bignum" do
    bignum = 265252859812191058636308480000000
    marshal = "\x04\bl+\f\x00\x00\x00T\xDD\xF5]\x86\x96\x0F7\xF6\x13\r"
    assert Marshal.decode(marshal) == {"4.8", bignum}
  end

  test "Negative Bignum" do
    bignum = -265252859812191058636308480000000
    marshal = "\x04\bl-\f\x00\x00\x00T\xDD\xF5]\x86\x96\x0F7\xF6\x13\r"
    assert Marshal.decode(marshal) == {"4.8", bignum}
  end

  test "User Class" do
    user_class = {{:usrclass, :StrClone, "test"}, [E: true]}
    marshal = "\x04\bIC:\rStrClone\"\ttest\x06:\x06ET"
    assert Marshal.decode(marshal) == {"4.8", user_class}
  end

  test "User class cache" do
    usr_class = {{:usrclass, :StrClone, "test"}, [E: true]}
    marshal = "\x04\b[\aIC:\rStrClone\"\ttest\x06:\x06ET@\x06"
    assert Marshal.decode(marshal) == {"4.8", [usr_class, usr_class]}
  end

  test "User def cache" do
    usr_def = {:usrdef, :C, "a"}
    marshal = "\x04\b[\au:\x06C\x06a@\x06"
    assert Marshal.decode(marshal) == {"4.8", [usr_def, usr_def]}
  end

  test "Struct with cache" do
    foo = {"FOO", [E: true]}
    bar = {"BAR", [E: true]}
    struct = {:struct, :C3, %{foo: foo, bar: bar}}
    marshal = "\x04\b[\tS:\aC3\a:\bfooI\"\bFOO\x06:\x06ET:\bbarI\"\bBAR\x06;\aT@\a@\b@\x06"

    assert Marshal.decode(marshal) == {"4.8", [struct, foo, bar, struct]}
  end

  test "Extended object" do
    extended = {:extended, :Mod1, {:object_instance, :Object, []}}
    marshal = "\x04\be:\tMod1o:\vObject\x00"

    assert Marshal.decode(marshal) == {"4.8", extended}
  end

  test "Nested extensions" do
    overextended = {:extended, :Mod2, {:extended, :Mod1, {:object_instance, :Object, []}}}
    marshal = "\x04\be:\tMod2e:\tMod1o:\vObject\x00"

    assert Marshal.decode(marshal) == {"4.8", overextended}
  end

  test "Hash with default" do
    hash_def = {:default_hash, %{}, 6}
    marshal = "\x04\b}\x00i\v"

    assert Marshal.decode(marshal) == {"4.8", hash_def}
  end

  test "Hash def" do
    hash_default = {:default_hash, %{4 => 5}, 8}
    defined_class = {{:usrclass, :MyHash, hash_default}, ["@v": 7]}
    marshal = "\x04\bIC:\vMyHash}\x06i\ti\ni\r\x06:\a@vi\f"

    assert Marshal.decode(marshal) == {"4.8", defined_class}
  end

  test "Float infinity" do
    infinity = {:float, :infinity}
    marshal = "\x04\bf\binf"

    assert Marshal.decode(marshal) == {"4.8", infinity}
  end

  test "Float negative infinity" do
    neg_infinity = {:float, :neg_infinity}
    marshal = "\x04\bf\t-inf"

    assert Marshal.decode(marshal) == {"4.8", neg_infinity}
  end

  test "Float not a number" do
    nan = {:float, :nan}
    marshal = "\x04\bf\bnan"

    assert Marshal.decode(marshal) == {"4.8", nan}
  end

  test "Recursive cache" do
    recursive_string = {{:usrclass, :MyString, "b"}, [E: true, "@v": :self]}
    marshal = "\x04\bIC:\rMyString\"\x06b\a:\x06ET:\a@v@\x00"

    assert Marshal.decode(marshal) == {"4.8", recursive_string}
  end

  test "Standard ivar order" do
    string = {"apple", [E: true]}
    string_with_ivar = {"test", [E: true, "@z": 1, "@y": string]}
    marshal = "\x04\b[\bI\"\ttest\b:\x06ET:\a@zi\x06:\a@yI\"\napple\x06;\x00T@\x06@\a"

    assert Marshal.decode(marshal) == {"4.8", [string_with_ivar, string_with_ivar, string]}
  end

  test "ivar order is different for user defined object" do
    apple = {"apple", [E: true]}
    tz = {"EDT", [E: false]}
    time_with_ivar = {{:usrdef, :Time, <<85, 22, 29, 128, 106, 43, 175, 139>>},
                      ["@remove": apple, offset: -14400, zone: tz]}

    marshal = "\x04\b[\tIu:\tTime\rU\x16\x1D\x80j+\xAF\x8B\b:\f@removeI\"\napple\x06:\x06ET:\voffseti\xFE\xC0\xC7:\tzoneI\"\bEDT\x06;\aF@\x06@\a@\b"

    assert Marshal.decode(marshal) == {"4.8", [time_with_ivar, apple, tz, time_with_ivar]}
  end

  test "extended object cache" do
    banana = {"banana", [E: true]}
    object = {:extended, :Mod2, {:extended, :Mod1, {:object_instance, :Object, ["@z": banana]}}}
    marshal = "\x04\b[\be:\tMod2e:\tMod1o:\vObject\x06:\a@zI\"\vbanana\x06:\x06ET@\a@\x06"

    assert Marshal.decode(marshal) == {"4.8", [object, banana, object]}
  end

  test "usr class nested cache" do
    banana = {"banana", [E: true]}
    cherry = {"cherry", [E: true]}
    usrclass = {{:usrclass, :StrClone, "banana"}, [E: true, "@z": cherry]}
    marshal = "\x04\b[\tIC:\rStrClone\"\vbanana\a:\x06ET:\a@zI\"\vcherry\x06;\x06TI\"\vbanana\x06;\x06T@\a@\x06"

    assert Marshal.decode(marshal) == {"4.8", [usrclass, banana, cherry, usrclass]}
  end

  test "hashdef nested cache" do
    banana = {"banana", [E: true]}
    cherry = {"cherry", [E: true]}
    hashdef = {{:default_hash, %{{"test", [E: true]} => cherry}, banana}, ["@z": cherry]}
    marshal = "\x04\b[\tI}\x06I\"\ttest\x06:\x06ETI\"\vcherry\x06;\x00TI\"\vbanana\x06;\x00T\x06:\a@z@\b@\t@\b@\x06"

    assert Marshal.decode(marshal) == {"4.8", [hashdef, banana, cherry, hashdef]}
  end

  test "struct nested cache" do
    banana = {"banana", [E: true]}
    cherry = {"cherry", [E: true]}
    struct = {:struct, :"Struct::MyStruct", %{a: banana, b: cherry}}
    marshal = "\x04\b[\tS:\x15Struct::MyStruct\a:\x06aI\"\vbanana\x06:\x06ET:\x06bI\"\vcherry\x06;\aT@\a@\b@\x06"

    assert Marshal.decode(marshal) == {"4.8", [struct, banana, cherry, struct]}
  end

  test "defined struct nest cache" do
    banana = {"banana", [E: true]}
    cherry = {"cherry", [E: true]}
    grape = {"grape", [E: true]}
    def_struct = {{:struct, :MySubStruct, %{a: banana, b: cherry}}, ["@v": grape]}
    marshal = "\x04\b[\nIS:\x10MySubStruct\a:\x06aI\"\vbanana\x06:\x06ET:\x06bI\"\vcherry\x06;\aT\x06:\a@vI\"\ngrape\x06;\aT@\a@\b@\t@\x06"

    assert Marshal.decode(marshal) == {"4.8", [def_struct, banana, cherry, grape, def_struct]}
  end
end
