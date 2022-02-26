defmodule Data.Constructor do
  alias Data.Parser.KV
  alias FE.Result

  @doc """
  Define and run a smart constructor on a Key-Value input, returning either
  well-defined `structs` or descriptive errors. The motto: parse, don't validate!

  Given a list of `Data.Parser.KV.field_spec/2`s, a `module`, and an input
  `map` or `Keyword`, create and run a parser which will either parse
  successfully and return an `{:ok, %__MODULE__{}}` struct, or fail and return
  an `{:error, Error.t}` with details about the parsing failure.

  ## Examples
      iex> defmodule SensorReading do
      ...>   defstruct [:sensor_id, :microfrobs, :datetime]
      ...>   def new(input) do
      ...>     Data.Constructor.struct([
      ...>      {:sensor_id, Data.Parser.BuiltIn.string()},
      ...>      {:microfrobs, Data.Parser.BuiltIn.integer()},
      ...>      {:datetime, Data.Parser.BuiltIn.datetime()}],
      ...>     __MODULE__,
      ...>     input)
      ...>   end
      ...> end
      ...>
      ...> {:ok, reading} = SensorReading.new(sensor_id: "1234-1234-1234",
      ...>                                    microfrobs: 23,
      ...>                                    datetime: ~U[2018-12-20 12:00:00Z])
      ...>
      ...> ~U[2018-12-20 12:00:00Z] = reading.datetime
      ...> 23 = reading.microfrobs
      ...> "1234-1234-1234" = reading.sensor_id
      ...> {:error, e} = SensorReading.new(%{"sensor_id" => nil,
      ...>                                   "microfrobs" => 23,
      ...>                                   "datetime" => "2018-12-20 12:00:00Z"})
      ...> :failed_to_parse_field = Error.reason(e)
      ...>  %{field: :sensor_id, input: %{"datetime" => "2018-12-20 12:00:00Z",
      ...>                                "microfrobs" => 23,
      ...>                                "sensor_id" => nil}} = Error.details(e)
      ...> {:just, inner_error} = Error.caused_by(e)
      ...> Error.reason(inner_error)
      :not_a_string

  """
  @spec struct([KV.field_spec(any, any)], module(), KV.input()) :: Result.t(struct, Error.t())
  def struct(field_specs, struct_module, input) do
    field_specs
    |> KV.new()
    |> Result.and_then(fn parser -> parser.(input) end)
    |> Result.map(&struct(struct_module, &1))
  end

  @doc """
  Define a smart update function based on a list of field specifications,
  the struct type to be updated, and a `Keyword` or `map` of input params.


  Given a list of `Data.Parser.KV.field_spec/2`s, a `module` (which defines a
  struct), and an input `map` or `Keyword`, create an `{:ok, &fun/1}` tuple,
  or fail and return an `{:error, Error.t}` with details about the parsing
  failure.

  The `&fun/1` in the ok-tuple can be applied to any struct as defined by
  `module`, and will update it with the fields provided in the constructor
  input.

  The crucial advantage here is that the input parameters are validated
  according to the provided `Data.Parser.KV.field_spec/2`s, so that using the
  same list of field_specs for `new/3` and `update/3` will result in
  correct-by-construction data both from construction and after updates.

  Additionally, if any of the field_specs define a `default:` value, that value
  will be explicitly allowed in updates for that field, along with the
  specified type.


  ## Examples
      iex> defmodule ReadingWComment do
      ...>   defstruct [:sensor_id, :microfrobs, :datetime, :comments]
      ...>
      ...>   defp fields, do: [
      ...>      {:sensor_id, Data.Parser.BuiltIn.string()},
      ...>      {:microfrobs, Data.Parser.BuiltIn.integer()},
      ...>      {:datetime, Data.Parser.BuiltIn.datetime()},
      ...>      {:comments, Data.Parser.BuiltIn.string(), default: nil}]
      ...>
      ...>   def new(input) do
      ...>     Data.Constructor.struct(fields(), __MODULE__, input)
      ...>   end
      ...>
      ...>   def update(sensor_reading, input) do
      ...>     case Data.Constructor.update(fields(), __MODULE__, input) do
      ...>      {:ok, update_fun} -> update_fun.(sensor_reading)
      ...>      {:error, e} -> {:error, e}
      ...>     end
      ...>   end
      ...> end
      ...>
      ...> {:ok, reading} = ReadingWComment.new(sensor_id: "1234-1234-1234",
      ...>                                      microfrobs: 23,
      ...>                                      datetime: ~U[2018-12-20 12:00:00Z],
      ...>                                      comments: "delete me later")
      ...> "delete me later" = reading.comments
      ...>
      ...>
      ...> {:ok, reading2} = ReadingWComment.update(reading,
      ...>                                          microfrobs: 25,
      ...>                                          datetime: ~U[2018-12-20 13:00:00Z])
      ...> ~U[2018-12-20 13:00:00Z] = reading2.datetime
      ...> 25 = reading2.microfrobs
      ...>
      ...>
      ...> {:ok, reading3} = ReadingWComment.update(reading2,
      ...>                                          comments: nil)
      ...> nil = reading3.comments
      ...>
      ...>
      ...> {:error, e} = ReadingWComment.update(reading3,
      ...>                                      microfrobs: [1,2,3])
      ...> :invalid_parameter = Error.reason(e)
      ...> %{key: :microfrobs, value: [1,2,3]} = Error.details(e)
      ...>
      ...>
      ...> {:error, e} = ReadingWComment.update(%{"my" => "special", "map" => "type"},
      ...>                                      microfrobs: 25,
      ...>                                      datetime: ~U[2018-12-20 13:00:00Z])
      ...> :struct_type_mismatch = Error.reason(e)
      ...> Error.details(e)
      %{expecting: Data.ConstructorTest.ReadingWComment, got: %{"map" => "type", "my" => "special"}}

  """

  @spec update([KV.field_spec(any, any)], module(), KV.input()) ::
          Result.t(Data.Parser.t(struct, Error.t()), Error.t())
  def update(field_specs, struct_type, params) do
    import Result, only: [ok: 1, oks: 1, error: 1, and_then: 2, all_ok: 1]

    Enum.map(field_specs, &KV.one/1)
    |> all_ok()
    |> and_then(fn parsers ->
      Enum.map(params, fn {k, v} ->
        case Enum.map(parsers, & &1.(%{k => v})) |> oks() do
          [one_parser_applies] -> ok(one_parser_applies)
          [] -> error(Error.domain(:invalid_parameter, %{key: k, value: v}))
        end
      end)
      |> all_ok()
    end)
    |> and_then(fn good_params ->
      good_param_map = Enum.reduce(good_params, %{}, &Map.merge(&2, &1))

      ok(fn
        s = %^struct_type{} ->
          ok(Map.merge(s, good_param_map))

        other_type ->
          error(
            Error.domain(
              :struct_type_mismatch,
              %{expecting: struct_type, got: other_type}
            )
          )
      end)
    end)
  end
end
