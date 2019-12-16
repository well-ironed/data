defmodule Data.ConstructorTest do
  use ExUnit.Case, async: true

  alias Data.Constructor
  import Data.Parser.BuiltIn

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
end
