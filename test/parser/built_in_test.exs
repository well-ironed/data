defmodule Data.Parser.BuiltInTest do
  use ExUnit.Case, async: true
  doctest Data.Parser.BuiltIn

  import Data.Parser.BuiltIn
  alias Error
  alias MapSet, as: Set

  describe "integer/0" do
    test "returns the same integer as passed" do
      assert integer().(123) == {:ok, 123}
    end

    test "returns an error if something other than an integer is passed" do
      assert {:error, error} = integer().("123")
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_an_integer
    end
  end

  describe "string/0" do
    test "returns an error if something other than a binary is passed" do
      assert {:error, error} = string().(123)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_string
    end

    test "returns the same string as passed" do
      assert string().("123") == {:ok, "123"}
    end
  end

  describe "list/1" do
    test "successfully parses empty list" do
      assert list(string()).([]) == {:ok, []}
    end

    test "successfully parses list where all elements parse" do
      assert list(integer()).([1, 2, 3]) == {:ok, [1, 2, 3]}
    end

    test "returns error when first argument is not a list" do
      assert {:error, error} = list(integer()).(:abc)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_list
    end

    test "returns first failed parse if some elements don't parse" do
      assert {:error, error} = list(integer()).([1, "2", 3])
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_an_integer
      assert Error.details(error) == %{failed_element: "2"}
    end
  end

  describe "nonempty_list/1" do
    test "returns error when list is empty" do
      assert {:error, error} = nonempty_list(string()).([])
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :empty_list
    end

    test "returns error when first argument is not a list" do
      assert {:error, error} = nonempty_list(integer()).(:bada)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_list
    end

    test "successfully parses list when all elements parse" do
      assert nonempty_list(integer()).([1, 2, 3]) == {:ok, [1, 2, 3]}
    end

    test "returns first failed parse if some elements don't parse" do
      assert {:error, error} = nonempty_list(string()).(["a", "b", :c])
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_string
      assert Error.details(error) == %{failed_element: :c}
    end
  end

  describe "set/1" do
    test "successfully parses empty set" do
      assert set(string()).(Set.new()) == {:ok, Set.new()}
    end

    test "successfully parses set where all elements parse" do
      assert set(integer()).(Set.new([1, 2, 3])) == {:ok, Set.new([1, 2, 3])}
    end

    test "returns error when first argument is not a set" do
      assert {:error, error} = set(integer()).(:abc)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_set
    end

    test "returns first failed parse if some elements don't parse" do
      assert {:error, error} = set(integer()).(Set.new([1, "2", 3]))
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_an_integer
      assert Error.details(error) == %{failed_element: "2"}
    end
  end

  describe "boolean/0" do
    test "successfully parses true" do
      assert boolean().(true) == {:ok, true}
    end

    test "successfully parses false" do
      assert boolean().(false) == {:ok, false}
    end

    test "returns error if something other than a boolean is passed" do
      assert {:error, error} = boolean().("x")
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_boolean
    end
  end

  describe "date/0" do
    test "successfully parses Date" do
      d = ~D[2019-11-20]
      assert date().(d) == {:ok, d}
    end

    test "successfully parses ISO date string" do
      assert date().("2019-11-20") == {:ok, ~D[2019-11-20]}
    end

    test "returns error if a non-ISO date string is passed" do
      assert {:error, error} = date().("2019-13-01")
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :invalid_date
    end

    test "returns error if something other is passed" do
      assert {:error, error} = date().(:x)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_date
    end
  end

  describe "datetime/0" do
    test "successfully parses DateTime" do
      dt = ~U[2019-11-20 08:00:00Z]
      assert datetime().(dt) == {:ok, dt}
    end

    test "successfully parses ISO datetime string" do
      assert datetime().("2019-11-20T08:00:00Z") == {:ok, ~U[2019-11-20 08:00:00Z]}
    end

    test "successfully parses ISO datetime string with offset" do
      assert datetime().("2019-11-20T09:00:00+01:00") == {:ok, ~U[2019-11-20 08:00:00Z]}
    end

    test "returns error if a non-ISO datetime string is passed" do
      assert {:error, error} = datetime().("2019-11-20T08:00:00")
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :missing_offset
    end

    test "returns error if something other is passed" do
      assert {:error, error} = datetime().(1)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_datetime
    end
  end

  describe "naive_datetime/1" do
    test "successfully parses NaiveDateTime" do
      ndt = ~N[2019-11-20 08:00:00]
      assert naive_datetime().(ndt) == {:ok, ndt}
    end

    test "successfully parses ISO datetime without offset" do
      assert naive_datetime().("2019-11-20T09:00:00") == {:ok, ~N[2019-11-20 09:00:00]}
    end

    test "returns error if a non-ISO datetime without offset is passed" do
      assert {:error, error} = naive_datetime().("2019-13-20T09:00:00")
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :invalid_date
    end

    test "returns error if something other is passed" do
      assert {:error, error} = naive_datetime().('123')
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_naive_datetime
    end
  end
end
