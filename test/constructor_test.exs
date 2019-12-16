defmodule Data.ConstructorTest do
  use ExUnit.Case, async: true

  alias Data.Constructor
  alias FE.Maybe
  import Data.Parser.BuiltIn

  test "an empty constructor run on an empty input returns empty map" do
    {:ok, constructor} = Constructor.new([])
    assert constructor.(%{}) == {:ok, %{}}
    assert constructor.([]) == {:ok, %{}}
  end

  test "an empty constructor run on input returns empty map" do
    {:ok, constructor} = Constructor.new([])
    assert constructor.(%{a: :b, c: :d}) == {:ok, %{}}
    assert constructor.(a: :b, c: :d) == {:ok, %{}}
  end

  test "a constructor with required field fails if field doesn't exist" do
    {:ok, constructor} = Constructor.new([{:count, integer()}])
    assert {:error, error} = constructor.(%{})
    assert {:error, ^error} = constructor.([])

    assert Error.kind(error) == :domain
    assert Error.reason(error) == :field_not_found_in_input
    assert Error.details(error) == %{field: :count, input: %{}}
  end

  test "a constructor with required field fails if the field's parser fails" do
    {:ok, constructor} = Constructor.new([{:count, integer()}])
    assert {:error, error} = constructor.(%{count: "123"})
    assert {:error, ^error} = constructor.(count: "123")
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :not_an_integer
    assert Error.details(error) == %{field: :count, input: %{count: "123"}}
  end

  test "a constructor with required field passes if field's parser passes" do
    {:ok, constructor} = Constructor.new([{:count, integer()}])
    assert constructor.(%{count: 123}) == {:ok, %{count: 123}}
    assert constructor.(count: 123) == {:ok, %{count: 123}}
  end

  test "a constructor with optional field passes with nothing if field doesn't exist" do
    {:ok, constructor} = Constructor.new([{:height, integer(), optional: true}])
    assert constructor.(%{}) == {:ok, %{height: Maybe.nothing()}}
    assert constructor.([]) == {:ok, %{height: Maybe.nothing()}}
  end

  test "a constructor with optional field passes with just if field's parser passes" do
    {:ok, constructor} = Constructor.new([{:height, integer(), optional: true}])
    assert constructor.(%{height: 123}) == {:ok, %{height: Maybe.just(123)}}
    assert constructor.(height: 123) == {:ok, %{height: Maybe.just(123)}}
  end

  test "a constructor with optional field fails if the field's parser fails" do
    {:ok, constructor} = Constructor.new([{:height, integer(), optional: true}])
    assert {:error, error} = constructor.(%{height: "123"})
    assert {:error, ^error} = constructor.(height: "123")
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :not_an_integer
    assert Error.details(error) == %{field: :height, input: %{height: "123"}}
  end

  test "a constructor with field with default value passes with that value " <>
         "if field doesn't exist" do
    {:ok, constructor} = Constructor.new([{:age, integer(), default: 21}])
    assert constructor.(%{}) == {:ok, %{age: 21}}
    assert constructor.([]) == {:ok, %{age: 21}}
  end

  test "a constructor with field with default value passes if field's parser passes" do
    {:ok, constructor} = Constructor.new([{:age, integer(), default: 21}])
    assert constructor.(%{age: 100}) == {:ok, %{age: 100}}
    assert constructor.(age: 100) == {:ok, %{age: 100}}
  end

  test "a constructor with field with default value fails if field's parser fails" do
    {:ok, constructor} = Constructor.new([{:age, integer(), default: 21}])
    assert {:error, error} = constructor.(%{age: "123"})
    assert {:error, ^error} = constructor.(age: "123")
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
    assert {:error, error} = Constructor.new([{:weight, integer(), default: 10, optional: true}])
    assert Error.kind(error) == :domain
    assert Error.reason(error) == :invalid_field_spec
    assert Error.details(error) == %{spec: {:weight, integer(), default: 10, optional: true}}
  end

  describe "struct" do
    defmodule Plant do
      defstruct [:name, :potted]
    end

    test "struct creates a new struct" do
      assert Constructor.struct(
               [{:name, string()}, {:potted, boolean()}],
               Plant,
               name: "Fir",
               potted: false
             ) ==
               {:ok, %Plant{name: "Fir", potted: false}}
    end

    test "struct doesn't create a new struct if invalid field spec is passed" do
      assert {:error, error} = Constructor.struct([:name], Plant, name: "Cactus", potted: true)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :invalid_field_spec
      assert Error.details(error) == %{spec: :name}
    end

    test "struct doesn't create a new struct if invalid input is passed" do
      assert {:error, error} = Constructor.struct([{:name, string()}], Plant, potted: true)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :field_not_found_in_input
      assert Error.details(error) == %{field: :name, input: %{potted: true}}
    end
  end

  describe "bad input" do
    test "a constructor run on an atom returns invalid input error" do
      {:ok, constructor} = Constructor.new([{:age, integer()}])
      assert {:error, error} = constructor.(:xyz)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :invalid_input
      assert Error.details(error) == %{input: :xyz}
    end

    test "a constructor run on a non-keyword list returns invalid input error" do
      {:ok, constructor} = Constructor.new([{:age, integer()}])
      assert {:error, error} = constructor.([:x, :y])
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :invalid_input
      assert Error.details(error) == %{input: [:x, :y]}
    end
  end
end
