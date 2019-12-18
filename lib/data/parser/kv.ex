defmodule Data.Parser.KV do
  @moduledoc """
  Creates parsers that accept KeyValue-style `Enum`s as input.

  In particular, KV parsers work with:

  - maps (e.g. `%{"hello" => "world"}`)
  - `Keyword.t`s (e.g. `[hello: "world"]`)
  - Lists of pairs (e.g. `[{"hello", "world"}]`)

  KV parsers are higher-order parsers, and operate in roughly the same way as
  `Data.Parser.list/1` or `Data.Parser.set/1`, but their definition is slightly
  more involved. A KV parser is created with a list of `field_spec`s, where
  each `field_spec` defines what fields of the input to look at, and what
  parsers to run on them.

  Here are some examples of `field_spec`s and their parsing behavior:

  ###  `{:username, \Data.Parser.BuiltIn.string()}`

  This spec says that the input must contain a `:username` field, and the value
  of that field must satisfy `Data.Parser.BuiltIn.string/0`.  The output map
  will contain the key-value pair `username: "some string"`.

  If the field cannot be parsed successfully, the entire KV parser will return
  `{:error, domain_error_with_details_on_parse_failure}`.

  If the field is not present, the entire KV parser will return
  `{:error, domain_error_with_details_about_field_not_found}`


  ###  `{:birthday, Data.Parser.BuiltIn.date(), optional: true}`

  This spec says that the input *may* contain a `:birthday` field. If the field
  does exist, it must satisfy `Data.Parser.BuiltIn.date/0`.

  If the field exists and parses successfully, the output map will contain the
  key-value pair `birthday: {:just, ~D[1983-07-18]}`.

  If the field does not exist, the output map will contain the key-value pair
  `birthday: :nothing`.

  If the field cannot be parsed successfully, the entire KV parser will return
  `{:error, domain_error_with_parse_failure_details}`.


  ### `{:country, MyApp.country_parser(), default: "Canada"}`


  This spec says that the input *may* contain a `:country` field, and if so, the
  value of that field must parse successfully with `MyApp.country_parser/0`.

  If the field exists and parses successfully, the output map will contain a
  key-value pair such as: `country: "Indonesia"`.

  If the field cannot be parsed successfully, the entire Constructor will return
  `{:error, domain_error_with_details_on_parse_failure}`.

  If the field does *not* exist, the `default` value will be used. In this
  case, the output will contain the key-value pair: `country: "Canada"`


  """
  alias Data.Parser
  alias FE.{Maybe, Result}

  defmodule Field do
    @moduledoc false
    defstruct [:name, :parser, :optional, :default]
  end

  @typedoc """
  KV parsers accept either a map or a `Keyword.t` as input.
  """
  @type input :: map | Keyword.t()

  @typedoc """
  KV parsers accept `atom()`s as key names, but will work on inputs where
  the keys are `String.t()`s as well.
  """
  @type field_name :: atom()

  @typedoc """
  Options to relax requirements on the fields.

  This is a list that consists of zero or one of the below options:
  `{:optional, bool()}`
  `{:default, any}`
  """
  @type field_opts(a) :: [{:optional, bool()} | {:default, a}]


  @typedoc """
  A 2-tuple or 3-tuple describing the field to parse and parsing semantics.

  `{field_name, parser}`
  `{field_name, parser, opts}`

  """
  @type field_spec(a, b) ::
          {field_name(), Parser.t(a, b)} | {field_name(), Parser.t(a, b), field_opts(b)}

  @typedoc """
  A structure representing a `Data.Parser.t(a,b)` lifted to operate on a KV.
  """
  @opaque field(a, b) :: %Field{
            name: field_name(),
            parser: Parser.t(a, b),
            optional: boolean(),
            default: Maybe.t(b)
          }

  @doc """

  Given a list of `field_spec`s, verify that all specs are well-formed and
  return `{:ok, parser}`, where `parser` will accept a `map` or `Keyword` input
  and apply the appropriate parsers to their corresponding fields.

  If the `field_spec`s are not well-formed, return `{:error, Error.t}` with details
  about the invalid `field_spec`s.

  ## Examples
      iex> {:ok, p} = Data.Parser.KV.new([{:username, Data.Parser.BuiltIn.string()}])
      ...> p.(username: "johndoe")
      {:ok, %{username: "johndoe"}}

      iex> {:ok, p} = Data.Parser.KV.new([{:username, Data.Parser.BuiltIn.string()}])
      ...> p.(%{"username" => "johndoe"})
      {:ok, %{username: "johndoe"}}

      iex> {:error, e} = Data.Parser.KV.new(["not a spec"])
      ...> e
      %Error.DomainError{details: %{spec: "not a spec"}, reason: :invalid_field_spec}

      iex> {:ok, p} = Data.Parser.KV.new([{:a, Data.Parser.BuiltIn.integer(), optional: true}])
      ...> p.(a: 1)
      {:ok, %{a: {:just, 1}}}

      iex> {:ok, p} = Data.Parser.KV.new([{:a, Data.Parser.BuiltIn.integer(), optional: true}])
      ...> p.([])
      {:ok, %{a: :nothing}}

      iex> {:ok, p} = Data.Parser.KV.new([{:b, Data.Parser.BuiltIn.integer(), default: 0}])
      ...> p.([])
      {:ok, %{b: 0}}

      iex> {:ok, p} = Data.Parser.KV.new([{:b, Data.Parser.BuiltIn.integer(), default: 0}])
      ...> p.(b: 10)
      {:ok, %{b: 10}}

      iex> {:ok, p} = Data.Parser.KV.new([{:b, Data.Parser.BuiltIn.integer(), default: 0}])
      ...> p.(b: "i am of the wrong type")
      {:error, %Error.DomainError{details: %{field: :b, input: %{b: "i am of the wrong type"}, parse_error: %Error.DomainError{details: %{}, reason: :not_an_integer}}, reason: :failed_to_parse_field}}


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
    case fetch_key(input, name) do
      {:ok, value} ->
        existing_field(field, acc, value, input)

      :error ->
        missing_field(field, acc, input)
    end
  end

  defp fetch_key(%{} = input, key) when is_atom(key) do
    case Map.fetch(input, key) do
      :error ->
        Map.fetch(input, Atom.to_string(key))
      found ->
        found
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
      Error.domain(:failed_to_parse_field,
        %{field: name, input: input, parse_error: error})
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
