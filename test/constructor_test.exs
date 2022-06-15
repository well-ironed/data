defmodule Data.ConstructorTest do
  use ExUnit.Case, async: true
  doctest Data.Constructor

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

  describe "update" do
    defmodule Pet do
      defstruct [:name, :spotted, :price]

      def fields do
        [{:name, string()}, {:spotted, boolean()}, {:price, integer(), nullable: true}]
      end

      def new(params) do
        Constructor.struct(
          fields(),
          Pet,
          params
        )
      end
    end

    test "update can create an update of one field" do
      {:ok, _} = Pet.new(name: "Pooch", spotted: true, price: 1000)
      {:ok, update} = Constructor.update(Pet.fields(), Pet, spotted: false)
      assert is_function(update, 1)
    end

    test "an update can be applied to an existing struct to yield an updated one" do
      {:ok, p} = Pet.new(name: "Pooch", spotted: true, price: 1000)
      {:ok, update} = Constructor.update(Pet.fields(), Pet, spotted: false)

      assert update.(p) == {:ok, %Pet{name: "Pooch", spotted: false, price: 1000}}
    end

    test "an update can be applied using a field that is nullable" do
      {:ok, p} = Pet.new(name: "Pooch", spotted: true, price: 1000)
      {:ok, update} = Constructor.update(Pet.fields(), Pet, price: nil)

      assert update.(p) == {:ok, %Pet{name: "Pooch", spotted: true, price: nil}}
    end

    test "an update can update all fields if all are provided" do
      {:ok, p} = Pet.new(name: "Pooch", spotted: true, price: 1000)

      {:ok, update} =
        Constructor.update(Pet.fields(), Pet,
          name: "Super Pooch",
          spotted: false,
          price: 1_000_000
        )

      assert update.(p) == {:ok, %Pet{name: "Super Pooch", spotted: false, price: 1_000_000}}
    end

    test "an update will not be constructed if the field spec is wrong" do
      # TODO it would be nice to get a Review type with all the bad fields,
      # but for now we fail fast on the first one, like the struct/3 parser.
      assert {:error, e} =
               Constructor.update(
                 [{:bad, 123, :field, spec: [1, 2, 3]}],
                 SomeType,
                 spec: [1, 2, 3]
               )

      assert Error.reason(e) == :invalid_field_spec
      assert Error.details(e) == %{spec: {:bad, 123, :field, [spec: [1, 2, 3]]}}
    end

    test "an update will not be constructed if there are extra input params" <>
           " not specified in field spec" do
      assert {:error, e} =
               Constructor.update(
                 Pet.fields(),
                 Pet,
                 name: "Rocky",
                 breed: "Golden Retriever"
               )

      assert Error.reason(e) == :invalid_parameter
      assert Error.details(e) == %{key: :breed, value: "Golden Retriever"}
    end

    test "an update will not be constructed if the incoming fields are not parseable" do
      assert {:error, e} =
               Constructor.update(Pet.fields(), Pet,
                 name: :atomic_kitten,
                 spotted: [1, 2, 3],
                 price: "not for sale"
               )

      assert Error.reason(e) == :invalid_parameter
      assert Error.details(e) == %{key: :name, value: :atomic_kitten}
    end

    defmodule Fish do
      defstruct [:name, :spotted, :price]
    end

    test "an update will not get applied to a different type" do
      # TODO it would be nice to get a Review type with all the bad fields,
      # but for now we fail fast on the first one, like the struct/3 parser.

      fish = %Fish{name: "a", spotted: false, price: 0}

      {:ok, update} =
        Constructor.update(Pet.fields(), Pet,
          name: "Super Pooch",
          spotted: false,
          price: 1_000_000
        )

      assert {:error, e} = update.(fish)
      assert Error.reason(e) == :struct_type_mismatch
      assert Error.details(e) == %{expecting: Pet, got: fish}
    end
  end
end
