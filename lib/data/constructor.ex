defmodule Data.Constructor do
  alias Data.Parser.KV
  alias FE.Result

  @doc """
  Define and run a smart constructor on a Key-Value input, returning either
  well-defined `structs` or descriptive errors. The motto: parse, don't validate!

  Given a list of `field_spec`s, a `module`, and an input `map` or `Keyword`,
  create and run a parser which will either parse successfully and return an
  `{:ok, %__MODULE__{}}` or fail and return an `{:error, Error.t}` with details
  about the parsing failure.

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
      ...> {:ok, reading} = SensorReading.new(sensor_id: "1234-1234-1234", microfrobs: 23, datetime: ~U[2018-12-20 12:00:00Z])
      ...>
      ...> reading.datetime
      ~U[2018-12-20 12:00:00Z]
      ...>
      ...> reading.microfrobs
      23
      ...> reading.sensor_id
      "1234-1234-1234"
      ...> {:error, e} = SensorReading.new(%{"sensor_id" => nil, "microfrobs" => 23, "datetime" => "2018-12-20 12:00:00Z"})
      ...> Error.to_map(e)
      %{details: %{field: :sensor_id, input: %{"datetime" => "2018-12-20 12:00:00Z", "microfrobs" => 23, "sensor_id" => nil}, parse_error: %Error.DomainError{details: %{}, reason: :not_a_string}}, kind: :domain, reason: :failed_to_parse_field}


  """
  @spec struct([KV.field_spec(any, any)], module(), KV.input) :: Result.t(struct, Error.t())
  def struct(field_specs, struct_module, input) do
    field_specs
    |> KV.new()
    |> Result.and_then(fn parser -> parser.(input) end)
    |> Result.map(&struct(struct_module, &1))
  end


end

defmodule SensorReading do
  defstruct [:sensor_id, :microfrobs, :datetime]
  def new(input) do
    Data.Constructor.struct([
     {:sensor_id, Data.Parser.BuiltIn.string()},
     {:microfrobs, Data.Parser.BuiltIn.integer()},
     {:datetime, Data.Parser.BuiltIn.datetime()}],
    __MODULE__,
    input)
  end
end
