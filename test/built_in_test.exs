defmodule Data.BuiltInTest do
  use ExUnit.Case, async: true

  import Data.BuiltIn
  alias Error

  describe "integer/1" do
    test "returns the same integer as passed" do
      assert integer(123) == {:ok, 123}
    end

    test "returns an error if something else than integer is passed" do
      assert {:error, error} = integer("123")
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_an_integer
    end
  end
end
