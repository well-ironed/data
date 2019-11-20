defmodule Data.ParserTest do
  use ExUnit.Case, async: true

  alias Data.Parser

  describe "predicate/2" do
    test "returns parser that returns the input value if predicate is true" do
      parser = Parser.predicate(fn x -> x > 2 end, Error.domain(:must_be_gt_2))
      assert parser.(3) == {:ok, 3}
    end

    test "returns parser that errors out if predicate is false" do
      error = Error.domain(:must_be_gt_2)
      parser = Parser.predicate(fn x -> x > 2 end, error)
      assert parser.(1) == {:error, error}
    end
  end

  describe "one_of/2" do
    test "returns parser than returns the input value if it's one of the provided values" do
      parser = Parser.one_of([:a, :b], Error.domain(:must_be_a_or_b))
      assert parser.(:a) == {:ok, :a}
    end

    test "returns parser than returns the default error if run on a value that's not listed" do
      error = Error.domain(:must_be_a_or_b)
      parser = Parser.one_of([:a, :b], error)
      assert parser.(:c) == {:error, error}
    end
  end
end
