defmodule Data.BuiltInTest do
  use ExUnit.Case, async: true

  import Data.BuiltIn
  alias Error

  describe "integer/1" do
    test "returns the same integer as passed" do
      assert integer(123) == {:ok, 123}
    end

    test "returns an error if something other than an integer is passed" do
      assert {:error, error} = integer("123")
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_an_integer
    end
  end

  describe "string/1" do
    test "returns an error if something other than a binary is passed" do
      assert {:error, error} = string(123)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_string
    end

    test "returns the same string as passed" do
      assert string("123") == {:ok, "123"}
    end
  end

  describe "list/2" do
    test "successfully parses empty list" do
      assert list([], &string/1) == {:ok, []}
    end

    test "successfully parses list where all elements parse" do
      assert list([1,2,3], &integer/1) == {:ok, [1,2,3]}
    end

    test "returns error when first argument is not a list" do
      assert {:error, error} = list(:abc, &integer/1)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_list
    end

    test "returns first failed parse if some elements don't parse" do
      assert {:error, error} = list([1,"2",3], &integer/1)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_an_integer
      assert Error.details(error) == %{failed_element: "2"}
    end

  end
end
