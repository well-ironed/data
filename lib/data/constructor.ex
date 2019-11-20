defmodule Data.Constructor do
  defstruct [:fields]

  defmodule Field do
    defstruct [:name, :parser, :optional, :default]
  end

  alias Data.Parser
  alias Error
  alias FE.{Maybe, Result}

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
  @opaque t(a, b) :: %__MODULE__{fields: [field(a, b)]}

  @spec new([field_spec(a, b)]) :: Result.t(t(a, b), Error.t()) when a: var, b: var
  def new(field_specs) when is_list(field_specs) do
    Result.ok([])
    |> Result.fold(field_specs, &parse_field_spec/2)
    |> Result.map(&%__MODULE__{fields: &1})
  end

  def new(_other) do
    Error.domain(:not_a_list) |> Result.error()
  end

  @spec run(t(any, any), map) :: Result.t(map, Error.t())
  def run(%__MODULE__{fields: fields}, input) do
    Result.ok([])
    |> Result.fold(fields, &run_for_field(&1, &2, input))
    |> Result.map(&Enum.into(&1, %{}))
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
        existing_field(field, acc, value)

      :error ->
        missing_field(field, acc)
    end
  end

  defp existing_field(%Field{name: name, parser: parser, optional: optional}, acc, value) do
    parser.(value)
    |> Result.map(fn parsed_value ->
      case optional do
        true -> [{name, Maybe.just(parsed_value)} | acc]
        false -> [{name, parsed_value} | acc]
      end
    end)
    |> Result.map_error(fn error -> Error.map_details(error, &Map.put(&1, :field, name)) end)
  end

  defp missing_field(%Field{name: name, optional: optional, default: default}, acc) do
    case {optional, default} do
      {true, :nothing} ->
        Result.ok([{name, Maybe.nothing()} | acc])

      {false, {:just, default_value}} ->
        Result.ok([{name, default_value} | acc])

      {false, :nothing} ->
        Error.domain(:not_found, %{field: name}) |> Result.error()
    end
  end
end
