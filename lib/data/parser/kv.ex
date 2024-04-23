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


  ### `{:country, MyApp.country_parser(), nullable: true}`


  This spec says that the input *must* contain a `:country` field, and if so,
  the value of that field must parse successfully with `MyApp.country_parser/0`
  OR be equal to `nil`.

  If the field exists and parses successfully, the output map will contain a
  key-value pair such as: `country: "Indonesia"`.

  If the field cannot be parsed successfully, the entire Constructor will return
  `{:error, domain_error_with_details_on_parse_failure}`. However, if the value
  of the field is `nil`, this is treated as a successful parse.

  If the field does *not* exist, the parser will fail.

  Note that a field spec specified as `nullable: true` cannot also contain
  either the `optional: true` or `default: x` options.
  This is an illegal spec and will not be constructed, resulting in
  an `{:error, domain_error}` tuple, with `:invalid_field_spec` as the
  error reason.


  ### `{:country, MyApp.country_parser(), from: :countryName}`


  This spec says that the parser will use the data from `:countryName` in the
  input map. If the value under this key satisfies the
  `MyApp.country_parser()`, then the resulting value will be placed under the
  `:country` field.

  Note that the `from` keyname MUST always be specified as an atom, but it will
  be applied automatically to string keys. If the input contains *both* a
  string key and an atom key, the atom key will take priority.


  ### `{:point, MyApp.point_parser(), recurse: true}`

  Sometimes you want to run several different parsers on the same input
  map. For example, let's say your input looks like this:

  ```
  %{x: 12,
    y: -10,
    value: 34,
    name: "exploding_barrel"}
  ```

  But the data structure you want after parsing looks like this:

  ```
  %{point: %{x: 12, y: -10},
    value: 34,
    name: "exploding_barrel"}
  ```

  And you have MyApp.point_parser() which accepts a map with `:x` and `:y`
  integer keys and constructs `%{x: integer(), y: integer()}`.

  You can define a field_spec with `recurse: true` and have that particular
  parser get run on its *parent input map*, not on the value of a field.



  """
  alias Data.Parser
  alias FE.{Maybe, Result}

  defmodule Field do
    @moduledoc false
    defstruct [:name, :from, :parser, :optional, :default, :recurse, :nullable]
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
  `{:from, field_name()}`
  """
  @type field_opts(a) :: [{:optional, bool()} | {:default, a} | {:from, field_name()}]

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
            from: field_name(),
            parser: Parser.t(a, b),
            optional: boolean(),
            default: Maybe.t(b),
            nullable: boolean(),
            recurse: boolean()
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
      ...> e.reason
      :invalid_field_spec
      ...> e.details
      %{spec: "not a spec"}

      iex> {:ok, p} = Data.Parser.KV.new([{:a, Data.Parser.BuiltIn.integer(), optional: true}])
      ...> p.(a: 1)
      {:ok, %{a: {:just, 1}}}

      iex> {:ok, p} = Data.Parser.KV.new([{:a, Data.Parser.BuiltIn.integer(), optional: true}])
      ...> p.([])
      {:ok, %{a: :nothing}}

      iex> {:ok, p} = Data.Parser.KV.new([{:a, Data.Parser.BuiltIn.integer(), nullable: true}])
      ...> {:error, e} = p.([])
      ...> Error.reason(e)
      :field_not_found_in_input

      iex> {:ok, p} = Data.Parser.KV.new([{:a, Data.Parser.BuiltIn.integer(), nullable: true}])
      ...> p.([a: nil])
      {:ok, %{a: nil}}

      iex> {:ok, p} = Data.Parser.KV.new([{:a, Data.Parser.BuiltIn.integer(), nullable: true}])
      ...> p.([a: 1])
      {:ok, %{a: 1}}

      iex> {:error, e} = Data.Parser.KV.new([{:a, Data.Parser.BuiltIn.integer(), nullable: true, default: nil}])
      ...> Error.reason(e)
      :invalid_field_spec

      iex> {:error, e} = Data.Parser.KV.new([{:a, Data.Parser.BuiltIn.integer(), nullable: true, optional: true}])
      ...> Error.reason(e)
      :invalid_field_spec

      iex> {:ok, p} = Data.Parser.KV.new([{:b, Data.Parser.BuiltIn.integer(), default: 0}])
      ...> p.([])
      {:ok, %{b: 0}}

      iex> {:ok, p} = Data.Parser.KV.new([{:b, Data.Parser.BuiltIn.integer(), default: 0}])
      ...> p.(b: 10)
      {:ok, %{b: 10}}

      iex> {:ok, p} = Data.Parser.KV.new([{:b, Data.Parser.BuiltIn.integer(), default: 0}])
      ...> {:error, e} = p.(b: "i am of the wrong type")
      ...> Error.reason(e)
      :failed_to_parse_field
      ...> {:just, inner_error} = Error.caused_by(e)
      ...> Error.reason(inner_error)
      :not_an_integer

      iex> {:ok, p} = Data.Parser.KV.new([{:a, Data.Parser.BuiltIn.integer(), from: :theAValue}])
      ...> p.(%{theAValue: 123})
      {:ok, %{a: 123}}

      iex> {:ok, p} = Data.Parser.KV.new([{:a, Data.Parser.BuiltIn.integer(), from: :aStringKey}])
      ...> p.(%{"aStringKey" => 1234})
      {:ok, %{a: 1234}}

      iex> {:ok, point} = Data.Parser.KV.new([{:x, Data.Parser.BuiltIn.integer()}, {:y, Data.Parser.BuiltIn.integer()}])
      ...> {:ok, item} = Data.Parser.KV.new([{:point, point, recurse: true}, {:value, Data.Parser.BuiltIn.integer()}])
      ...> item.(%{x: 1, y: -1, value: 34})
      {:ok, %{value: 34, point: %{x: 1, y: -1}}}

      iex> {:ok, point} = Data.Parser.KV.new([{:x, Data.Parser.BuiltIn.integer()}, {:y, Data.Parser.BuiltIn.integer()}])
      ...> {:ok, item} = Data.Parser.KV.new([{:point, point, recurse: true}, {:value, Data.Parser.BuiltIn.integer()}])
      ...> {:error, e} = item.(%{x: "wrong", y: -1, value: 34})
      ...> {:just, e2} = e.caused_by
      ...> e2.reason
      :failed_to_parse_field


      iex> {:ok, point} = Data.Parser.KV.new([{:x, Data.Parser.BuiltIn.integer()}, {:y, Data.Parser.BuiltIn.integer()}])
      ...> {:ok, item} = Data.Parser.KV.new([{:point, point, recurse: true}, {:value, Data.Parser.BuiltIn.integer()}])
      ...> {:error, e} = item.(%{y: -1, value: 34})
      ...> {:just, e2} = e.caused_by
      ...> e2.reason
      :field_not_found_in_input

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

  @doc """

  Given one `field_spec`, verify that it is well-formed and
  return `{:ok, parser}`, where `parser` will accept a `map` or `Keyword` input
  and attempt to parse that single field out of the map.

  Any `field_spec` with default semantics will be 'lifted' to also accept the
  default value if present under the key.

  Any `field_spec` with optional semantics will be stripped of these, so that
  it can 'select' only fields which exist.

  If the `field_spec` is not well-formed, return `{:error, Error.t}` with details
  about the invalid `field_spec`.

  ## Examples
      iex> {:ok, p} = Data.Parser.KV.one({:username, Data.Parser.BuiltIn.string()})
      ...> p.(username: "johndoe")
      {:ok, %{username: "johndoe"}}

      iex> {:ok, p} = Data.Parser.KV.one({:username, Data.Parser.BuiltIn.string()})
      ...> p.(%{"username" => "johndoe"})
      {:ok, %{username: "johndoe"}}

      iex> {:ok, p} = Data.Parser.KV.one({:username, Data.Parser.BuiltIn.string(), default: nil})
      ...> p.(username: nil)
      {:ok, %{username: nil}}

      iex> {:ok, p} = Data.Parser.KV.one({:username, Data.Parser.BuiltIn.string(), default: nil})
      ...> {:error, e} = p.(%{username: [1,2,3]})
      ...> Error.reason(e)
      :failed_to_parse_field

      iex> {:ok, p} = Data.Parser.KV.one({:username, Data.Parser.BuiltIn.string(), default: nil})
      ...> {:error, e} = p.(%{"a" => "b"})
      ...> Error.reason(e)
      :field_not_found_in_input

      iex> {:ok, p} = Data.Parser.KV.one({:username, Data.Parser.BuiltIn.string(), optiona: true})
      ...> {:error, e} = p.(%{"a" => "b"})
      ...> Error.reason(e)
      :field_not_found_in_input

  """
  @spec one(field_spec(a, b)) :: Result.t(Parser.t(a, b), Error.t()) when a: var, b: var
  def one(spec) when is_tuple(spec) do
    import Data.Parser, only: [union: 1, predicate: 1]
    import FE.Result, only: [ok: 1, and_then: 2]

    # We merge the declared k/v parser with any "default" semantics, if present, to get a kv which accepts
    # either the main type or the default value.
    parse_field_spec(spec, [])
    |> and_then(fn [%Field{} = f] ->
      new_parser =
        case {f.default, f.nullable} do
          {{:just, default_val}, false} ->
            union([f.parser, predicate(&(&1 == default_val))])

          {:nothing, _} ->
            f.parser
        end

      nf = %Field{
        f
        | parser: new_parser,
          optional: false,
          default: Maybe.nothing(),
          recurse: false
      }

      ok(fn input -> run([nf], input) end)
    end)
  end

  @spec run([field(any, any)], input) :: Result.t(map, Error.t())
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
    field = %Field{
      name: field_name,
      from: field_name,
      parser: parser,
      optional: false,
      default: Maybe.nothing(),
      recurse: false,
      nullable: false
    }

    Result.ok([field | acc])
  end

  defp parse_field_spec({field_name, parser, opts} = spec, acc) do
    import Data.Parser.BuiltIn, only: [null: 0]
    import Data.Parser, only: [union: 1]

    optional = Keyword.get(opts, :optional, false)
    nullable = Keyword.get(opts, :nullable, false)
    recurse = Keyword.get(opts, :recurse, false)
    from = Keyword.get(opts, :from, field_name)

    default =
      case Keyword.fetch(opts, :default) do
        {:ok, default} -> Maybe.just(default)
        :error -> Maybe.nothing()
      end

    case {optional, default, nullable} do
      {true, _, true} ->
        Error.domain(:invalid_field_spec, %{spec: spec}) |> Result.error()

      {_, {:just, _}, true} ->
        Error.domain(:invalid_field_spec, %{spec: spec}) |> Result.error()

      {true, {:just, _}, _} ->
        Error.domain(:invalid_field_spec, %{spec: spec}) |> Result.error()

      {false, :nothing, true} ->
        field = %Field{
          name: field_name,
          from: from,
          parser: union([parser, null()]),
          optional: optional,
          default: default,
          recurse: recurse,
          nullable: nullable
        }

        Result.ok([field | acc])

      {_, _, false} ->
        field = %Field{
          name: field_name,
          from: from,
          parser: parser,
          optional: optional,
          default: default,
          recurse: recurse,
          nullable: nullable
        }

        Result.ok([field | acc])
    end
  end

  defp parse_field_spec(other, _) do
    Error.domain(:invalid_field_spec, %{spec: other}) |> Result.error()
  end

  defp run_for_field(%Field{from: from, recurse: false} = field, acc, input) do
    case fetch_key(input, from) do
      {:ok, value} ->
        existing_field(field, acc, value, input)

      :error ->
        missing_field(field, acc, input)
    end
  end

  defp run_for_field(%Field{recurse: true} = field, acc, input) do
    existing_field(field, acc, input, input)
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
      error
      |> Error.wrap(
        Error.domain(
          :failed_to_parse_field,
          %{field: name, input: input}
        )
      )
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
