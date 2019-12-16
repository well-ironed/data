defmodule Data.Parser.KV do
  @moduledoc """
  The functions in this module can be used to create `Constructor` parsers.

  `Constructor` parsers are specialized parsers which accept `map`s or
  `Keyword.t`s as input, and apply sub-parsers to particular fields in the input.

  The sub-parsers are defined using `field_spec`s such as the following:

  1. {:username, Data.Parser.BuiltIn.string()}
  2. {:birthday, Data.Parser.BuiltIn.date(), optional: true}
  3. {:country, MyApp.country_parser(), default: "Canada"}

  Parser 1 above says that the input must contain a `:username` field, and the
  value of that field must parse successfully with `Data.Parser.BuiltIn.string/0`.
  The output map will contain the key-value pair `username: "some string"`.

  If the field cannot be parsed successfully, the entire Constructor will return
  `{:error, parse_failure_details}`.



  Parser 2 says that the input *may* contain a `:birthday` field. If the field
  does exists, it must parse successfully with `Data.Parser.BuiltIn.date/0`.

  If the field exists and parses, the output map will contain the key-value pair
  `birthday: {:just, ~D[1983-07-18]}`.

  If the field does not exist, the output map will contain the key-value pair
  `birthday: :nothing`.

  If the field cannot be parsed successfully, the entire Constructor will return
  `{:error, parse_failure_details}`.


  Parser 3 says that the input *may* contain a `:country` field, and if so, the
  value of that field must parse successfully with `MyApp.country_parser/0`.

  If the field exists and parses successfully, the output map will contain a
  key-value pair such as: `country: "Indonesia"`.

  If the field does *not* exist, the `default` value will be used. In the case
  of Parser 3, the output will contain the key-value pair: `country: "Canada"`

  If the field cannot be parsed successfully, the entire Constructor will return
  `{:error, parse_failure_details}`.

  """
  alias Data.Parser
  alias FE.{Maybe, Result}

  defmodule Field do
    @moduledoc false
    defstruct [:name, :parser, :optional, :default]
  end

  @type input :: map | Keyword.t()
  @type field_name :: atom()
  @type field_opts(a) :: [{:optional, bool()} | {:default, a}]
  @type field_spec(a, b) ::
          {field_name(), Parser.t(a, b)} | {field_name(), Parser.t(a, b), field_opts(b)}

  @opaque field(a, b) :: %Field{
            name: field_name(),
            parser: Parser.t(a, b),
            optional: boolean(),
            default: Maybe.t(b)
          }

  @doc """

  Given a list of `field_spec`s, verify that all specs are well-formed and
  return `{:ok, parser}`, where `parser` will accept a `map` or `Keyword` input
  and apply the appropriate parsers to their corresponding fields.  If the
  `field_spec`s are not well-formed, return `{:error, Error.t}` with details
  about the invalid `field_spec`s.

  """
  @spec new([field_spec(a, b)]) :: Result.t(Parser.t(a, b), Error.t()) when a: var, b: var
  def new(field_specs) when is_list(field_specs) do
    Result.ok([])
    |> Result.fold(field_specs, &parse_field_spec/2)
    |> Result.map(fn fields -> fn input -> run(fields, input) end end)
  end

  def new(_other) do
    Error.domain(:not_a_list) |> Result.error()
  end

  @spec run([Field.t()], input) :: Result.t(map, Error.t())
  defp run(fields, input) when is_list(input) do
    case Keyword.keyword?(input) do
      true -> run(fields, Enum.into(input, %{}))
      false -> Error.domain(:invalid_input, %{input: input}) |> Result.error()
    end
  end

  defp run(fields, input) when is_map(input) do
    Result.ok([])
    |> Result.fold(fields, &run_for_field(&1, &2, input))
    |> Result.map(&Enum.into(&1, %{}))
  end

  defp run(_constructor, other) do
    Error.domain(:invalid_input, %{input: other}) |> Result.error()
  end

  defp parse_field_spec({field_name, parser}, acc) do
    field = %Field{name: field_name, parser: parser, optional: false, default: Maybe.nothing()}
    Result.ok([field | acc])
  end

  defp parse_field_spec({field_name, parser, opts} = spec, acc) do
    optional = Keyword.get(opts, :optional, false)

    default =
      case Keyword.fetch(opts, :default) do
        {:ok, default} -> Maybe.just(default)
        :error -> Maybe.nothing()
      end

    case {optional, default} do
      {true, {:just, _}} ->
        Error.domain(:invalid_field_spec, %{spec: spec}) |> Result.error()

      {_, _} ->
        field = %Field{name: field_name, parser: parser, optional: optional, default: default}
        Result.ok([field | acc])
    end
  end

  defp parse_field_spec(other, _) do
    Error.domain(:invalid_field_spec, %{spec: other}) |> Result.error()
  end

  defp run_for_field(%Field{name: name} = field, acc, input) do
    case Map.fetch(input, name) do
      {:ok, value} ->
        existing_field(field, acc, value, input)

      :error ->
        missing_field(field, acc, input)
    end
  end

  defp existing_field(%Field{name: name, parser: parser, optional: optional}, acc, value, input) do
    parser.(value)
    |> Result.map(fn parsed_value ->
      case optional do
        true -> [{name, Maybe.just(parsed_value)} | acc]
        false -> [{name, parsed_value} | acc]
      end
    end)
    |> Result.map_error(fn error ->
      Error.map_details(error, &Map.merge(&1, %{field: name, input: input}))
    end)
  end

  defp missing_field(%Field{name: name, optional: optional, default: default}, acc, input) do
    case {optional, default} do
      {true, :nothing} ->
        Result.ok([{name, Maybe.nothing()} | acc])

      {false, {:just, default_value}} ->
        Result.ok([{name, default_value} | acc])

      {false, :nothing} ->
        Error.domain(:field_not_found_in_input, %{field: name, input: input}) |> Result.error()
    end
  end
end
