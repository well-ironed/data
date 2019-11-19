defmodule Data.ParserTest do
  use ExUnit.Case, async: true

  alias Data.Parser
  alias FE.Maybe
  import Data.BuiltIn

  test "an empty parser can be created without any fields" do
    assert Parser.new([]) == {:ok, %Parser{fields: []}}
  end

  test "an empty parser ran on an empty map returns empty map" do
    {:ok, parser} = Parser.new([])
    assert Parser.run(parser, %{}) == {:ok, %{}}
  end

  test "an empty parser ran on a map returns empty map" do
    {:ok, parser} = Parser.new([])
    assert Parser.run(parser, %{a: :b, c: :d}) == {:ok, %{}}
  end

  test "a parser with one required field can be created" do
    assert Parser.new([{:field, &integer/1}]) ==
             {:ok,
              %Parser{
                fields: [
                  %Parser.Field{
                    name: :field,
                    parser: &integer/1,
                    optional: false,
                    default: Maybe.nothing()
                  }
                ]
              }}
  end

  test "a parser with required field fails if field doesn't exist" do
    {:ok, parser} = Parser.new([{:count, &integer/1}])
    assert {:error, error} = Parser.run(parser, %{})
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :not_found
    assert Error.details(error) == %{field: :count}
  end

  test "a parser with required field fails if the field's parser fails" do
    {:ok, parser} = Parser.new([{:count, &integer/1}])
    assert {:error, error} = Parser.run(parser, %{count: "123"})
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :not_an_integer
    assert Error.details(error) == %{field: :count}
  end

  test "a parser with required field passes if field's parser passes" do
    {:ok, parser} = Parser.new([{:count, &integer/1}])
    assert Parser.run(parser, %{count: 123}) == {:ok, %{count: 123}}
  end

  test "a parser with optional field can be created" do
    assert Parser.new([{:height, &integer/1, optional: true}]) ==
             {:ok,
              %Parser{
                fields: [
                  %Parser.Field{
                    name: :height,
                    parser: &integer/1,
                    optional: true,
                    default: Maybe.nothing()
                  }
                ]
              }}
  end

  test "a parser with optional field passes with nothing if field doesn't exist" do
    {:ok, parser} = Parser.new([{:height, &integer/1, optional: true}])
    assert Parser.run(parser, %{}) == {:ok, %{height: Maybe.nothing()}}
  end

  test "a parser with optional field passes with just if field's parser passes" do
    {:ok, parser} = Parser.new([{:height, &integer/1, optional: true}])
    assert Parser.run(parser, %{height: 123}) == {:ok, %{height: Maybe.just(123)}}
  end

  test "a parser with optional field fails if the field's parser fails" do
    {:ok, parser} = Parser.new([{:height, &integer/1, optional: true}])
    assert {:error, error} = Parser.run(parser, %{height: "123"})
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :not_an_integer
    assert Error.details(error) == %{field: :height}
  end

  test "a parser with field with default value can be created" do
    assert Parser.new([{:age, &integer/1, default: 21}]) ==
             {:ok,
              %Parser{
                fields: [
                  %Parser.Field{
                    name: :age,
                    parser: &integer/1,
                    optional: false,
                    default: Maybe.just(21)
                  }
                ]
              }}
  end

  test "a parser with field with default value passes with that value " <>
         "if field doesn't exist" do
    {:ok, parser} = Parser.new([{:age, &integer/1, default: 21}])
    assert Parser.run(parser, %{}) == {:ok, %{age: 21}}
  end

  test "a parser with field with default value passes if field's parser passes" do
    {:ok, parser} = Parser.new([{:age, &integer/1, default: 21}])
    assert Parser.run(parser, %{age: 100}) == {:ok, %{age: 100}}
  end

  test "a parser with field with default value fails if field's parser fails" do
    {:ok, parser} = Parser.new([{:age, &integer/1, default: 21}])
    assert {:error, error} = Parser.run(parser, %{age: "123"})
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :not_an_integer
    assert Error.details(error) == %{field: :age}
  end

  test "a parser cannot be created with an invalid field spec" do
    assert {:error, error} = Parser.new([:bad_spec])
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :invalid_field_spec
    assert Error.details(error) == %{spec: :bad_spec}
  end

  test "a parser with anything else than a list of specs" do
    assert {:error, error} = Parser.new(:not_a_list_of_specs)
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :not_a_list
  end

  test "a parser with a optional and default value field cannot be created" do
    assert {:error, error} = Parser.new([{:weight, &integer/1, default: 10, optional: true}])
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :invalid_field_spec
    assert Error.details(error) == %{spec: {:weight, &integer/1, default: 10, optional: true}}
  end
end
