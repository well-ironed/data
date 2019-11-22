defmodule Data.ConstructorTest do
  use ExUnit.Case, async: true

  alias Data.Constructor
  alias FE.Maybe
  import Data.Parser.BuiltIn

  test "an empty constructor can be created without any fields" do
    assert Constructor.new([]) == {:ok, %Constructor{fields: []}}
  end

  test "an empty constructor ran on an empty input returns empty map" do
    {:ok, constructor} = Constructor.new([])
    assert Constructor.run(constructor, %{}) == {:ok, %{}}
    assert Constructor.run(constructor, []) == {:ok, %{}}
  end

  test "an empty constructor ran on input returns empty map" do
    {:ok, constructor} = Constructor.new([])
    assert Constructor.run(constructor, %{a: :b, c: :d}) == {:ok, %{}}
    assert Constructor.run(constructor, a: :b, c: :d) == {:ok, %{}}
  end

  test "a constructor with one required field can be created" do
    assert Constructor.new([{:field, &integer/1}]) ==
             {:ok,
              %Constructor{
                fields: [
                  %Constructor.Field{
                    name: :field,
                    parser: &integer/1,
                    optional: false,
                    default: Maybe.nothing()
                  }
                ]
              }}
  end

  test "a constructor with required field fails if field doesn't exist" do
    {:ok, constructor} = Constructor.new([{:count, &integer/1}])
    assert {:error, error} = Constructor.run(constructor, %{})
    assert {:error, ^error} = Constructor.run(constructor, [])

    assert Error.kind(error) == :domain
    assert Error.reason(error) == :field_not_found_in_input
    assert Error.details(error) == %{field: :count, input: %{}}
  end

  test "a constructor with required field fails if the field's parser fails" do
    {:ok, constructor} = Constructor.new([{:count, &integer/1}])
    assert {:error, error} = Constructor.run(constructor, %{count: "123"})
    assert {:error, ^error} = Constructor.run(constructor, count: "123")
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :not_an_integer
    assert Error.details(error) == %{field: :count, input: %{count: "123"}}
  end

  test "a constructor with required field passes if field's parser passes" do
    {:ok, constructor} = Constructor.new([{:count, &integer/1}])
    assert Constructor.run(constructor, %{count: 123}) == {:ok, %{count: 123}}
    assert Constructor.run(constructor, count: 123) == {:ok, %{count: 123}}
  end

  test "a constructor with optional field can be created" do
    assert Constructor.new([{:height, &integer/1, optional: true}]) ==
             {:ok,
              %Constructor{
                fields: [
                  %Constructor.Field{
                    name: :height,
                    parser: &integer/1,
                    optional: true,
                    default: Maybe.nothing()
                  }
                ]
              }}
  end

  test "a constructor with optional field passes with nothing if field doesn't exist" do
    {:ok, constructor} = Constructor.new([{:height, &integer/1, optional: true}])
    assert Constructor.run(constructor, %{}) == {:ok, %{height: Maybe.nothing()}}
    assert Constructor.run(constructor, []) == {:ok, %{height: Maybe.nothing()}}
  end

  test "a constructor with optional field passes with just if field's parser passes" do
    {:ok, constructor} = Constructor.new([{:height, &integer/1, optional: true}])
    assert Constructor.run(constructor, %{height: 123}) == {:ok, %{height: Maybe.just(123)}}
    assert Constructor.run(constructor, height: 123) == {:ok, %{height: Maybe.just(123)}}
  end

  test "a constructor with optional field fails if the field's parser fails" do
    {:ok, constructor} = Constructor.new([{:height, &integer/1, optional: true}])
    assert {:error, error} = Constructor.run(constructor, %{height: "123"})
    assert {:error, ^error} = Constructor.run(constructor, height: "123")
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :not_an_integer
    assert Error.details(error) == %{field: :height, input: %{height: "123"}}
  end

  test "a constructor with field with default value can be created" do
    assert Constructor.new([{:age, &integer/1, default: 21}]) ==
             {:ok,
              %Constructor{
                fields: [
                  %Constructor.Field{
                    name: :age,
                    parser: &integer/1,
                    optional: false,
                    default: Maybe.just(21)
                  }
                ]
              }}
  end

  test "a constructor with field with default value passes with that value " <>
         "if field doesn't exist" do
    {:ok, constructor} = Constructor.new([{:age, &integer/1, default: 21}])
    assert Constructor.run(constructor, %{}) == {:ok, %{age: 21}}
    assert Constructor.run(constructor, []) == {:ok, %{age: 21}}
  end

  test "a constructor with field with default value passes if field's parser passes" do
    {:ok, constructor} = Constructor.new([{:age, &integer/1, default: 21}])
    assert Constructor.run(constructor, %{age: 100}) == {:ok, %{age: 100}}
    assert Constructor.run(constructor, age: 100) == {:ok, %{age: 100}}
  end

  test "a constructor with field with default value fails if field's parser fails" do
    {:ok, constructor} = Constructor.new([{:age, &integer/1, default: 21}])
    assert {:error, error} = Constructor.run(constructor, %{age: "123"})
    assert {:error, ^error} = Constructor.run(constructor, age: "123")
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :not_an_integer
    assert Error.details(error) == %{field: :age, input: %{age: "123"}}
  end

  test "a constructor cannot be created with an invalid field spec" do
    assert {:error, error} = Constructor.new([:bad_spec])
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :invalid_field_spec
    assert Error.details(error) == %{spec: :bad_spec}
  end

  test "a constructor with anything else than a list of specs" do
    assert {:error, error} = Constructor.new(:not_a_list_of_specs)
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :not_a_list
  end

  test "a constructor with a optional and default value field cannot be created" do
    assert {:error, error} = Constructor.new([{:weight, &integer/1, default: 10, optional: true}])
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :invalid_field_spec
    assert Error.details(error) == %{spec: {:weight, &integer/1, default: 10, optional: true}}
  end

  describe "bad input" do
    test "a constructor run on an atom returns invalid input error" do
      {:ok, constructor} = Constructor.new([{:age, &integer/1}])
      assert {:error, error} = Constructor.run(constructor, :xyz)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :invalid_input
      assert Error.details(error) == %{input: :xyz}
    end

    test "a constructor run on a non-keyword list returns invalid input error" do
      {:ok, constructor} = Constructor.new([{:age, &integer/1}])
      assert {:error, error} = Constructor.run(constructor, [:x, :y])
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :invalid_input
      assert Error.details(error) == %{input: [:x, :y]}
    end
  end
end
