defmodule Data.Enum.Test do
  use ExUnit.Case, async: true

  describe "atomize_keys!/1" do
    test "returns keyword list with known atom keys for string-keyed map" do
      map = %{"apply" => :foo, "normal" => :bar}

      assert Data.Enum.atomize_keys!(map) == Keyword.new(apply: :foo, normal: :bar)
    end

    test "raises exception for a map with unknown atom keys" do
      map = %{"this_atom_doesn't_exist" => "one", "normal" => "two"}
      assert_raise ArgumentError, fn -> Data.Enum.atomize_keys!(map) end
    end

    test "returns keyword list with unknown atom keys for " <>
           "string-keyed map in unsafe mode" do
      map = %{"non_existent_atom" => "one", "normal" => "two"}

      assert Data.Enum.atomize_keys!(map, safe: false) ==
               Keyword.new(non_existent_atom: "one", normal: "two")
    end
  end
end
