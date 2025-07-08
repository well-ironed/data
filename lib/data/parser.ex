defmodule Data.Parser do
  @moduledoc """

  Higher-order functions to create and modify parsers.

  """
  alias FE.{Maybe, Result}
  alias MapSet, as: Set
  import Result, only: [ok: 1, error: 1]
  import Maybe, only: [just: 1, nothing: 0]

  defdelegate kv(fields), to: Data.Parser.KV, as: :new

  @typedoc """

  A parser is a function that takes any value as input and produces a `Result.t`.

  More specifically, a `parser(a,b)` is a fuction that takes any input and
  returns `{:ok, a}` on a successful parse or `{:error, b}` if parsing failed.

  """
  @type t(a, b) :: (any -> Result.t(a, b))

  @doc """

  Takes a boolean function `p` (the predicate), and returns a parser
  that parses successfully those values for which `p` is `true`.

  If the predicate returns `false` the parser will return a domain `Error`
  with the input value and the predicate functions listed in the error details.


  ## Examples
      iex> {:error, e} = Data.Parser.predicate(&String.valid?/1).('charlists are not ok')
      ...> e.reason
      :predicate_not_satisfied
      ...> e.details
      %{input: 'charlists are not ok', predicate: &String.valid?/1}

      iex> Data.Parser.predicate(&String.valid?/1).("this is fine")
      {:ok, "this is fine"}

      iex> Data.Parser.predicate(&(&1<10)).(5)
      {:ok, 5}

      iex> {:error, e} = Data.Parser.predicate(&(&1<10)).(55)
      ...> e.details.input
      55


  """
  @spec predicate((a -> boolean())) :: t(a, Error.t()) when a: var, b: var
  def predicate(p) when is_function(p, 1) do
    fn x ->
      case p.(x) do
        true ->
          Result.ok(x)

        _ ->
          Error.domain(
            :predicate_not_satisfied,
            %{predicate: p, input: x}
          )
          |> Result.error()
      end
    end
  end

  @doc """

  Takes a boolean function `p` (the predicate) and a default value, and returns
  a parser that parses successfully those values for which `p` is `true`.

  If the predicate function applied to the input returns `true`, the parser
  wraps the input in an `{:ok, input}` tuple.

  If the predicate function returns `false`, and `default` is a value, the
  parser returns `{:error, default}`

  If the predicate returns `false` and `default` is a unary function, the
  parser returns `{:error, default.(the_failed_input)}`.


  ## Examples
      iex> Data.Parser.predicate(&String.valid?/1, "invalid string").('charlists are not ok')
      {:error, "invalid string"}

      iex> Data.Parser.predicate(&String.valid?/1, "invalid string").(<<"neither are invalid utf sequences", 99999>>)
      {:error, "invalid string"}

      iex> Data.Parser.predicate(&String.valid?/1, "invalid string").("this is fine")
      {:ok, "this is fine"}

      iex> Data.Parser.predicate(&String.valid?/1, fn x -> "the bad value is: #\{inspect x}" end).(12345)
      {:error, "the bad value is: 12345"}

  """
  @spec predicate((a -> boolean()), b | (a -> b)) :: t(a, b) when a: var, b: var
  def predicate(p, default) when is_function(default, 1) do
    fn x ->
      case p.(x) do
        true -> ok(x)
        false -> default.(x) |> error()
      end
    end
  end

  def predicate(p, default), do: predicate(p, fn _ -> default end)

  @doc """

  Takes a list of values, `elements`, and returns a parser that returns
  successfully if its input is present in `elements`.

  If the input is not a member of `elements` and `default` is a value, the
  parser fails with `{:error, default}`. If `default` is a unary function, the
  parser fails with `{:error, default.(input)}`.

  ## Examples
      iex> Data.Parser.one_of([:he, :ne, :ar, :kr, :xe, :rn], "not a noble gas").(:he)
      {:ok, :he}

      iex> Data.Parser.one_of([:he, :ne, :ar, :kr, :xe, :rn], "not a noble gas").(:n)
      {:error, "not a noble gas"}

      iex> Data.Parser.one_of([:he, :ne, :ar, :kr, :xe, :rn],
      ...> fn x -> "not a noble gas: #\{inspect x}" end).(:o)
      {:error, "not a noble gas: :o"}

  """
  @spec one_of([a], b | (a -> b)) :: t(a, b) when a: var, b: var
  def one_of(elements, default) when is_function(default, 1) do
    fn x ->
      case Enum.member?(elements, x) do
        true -> ok(x)
        false -> default.(x) |> error()
      end
    end
  end

  def one_of(elements, default), do: one_of(elements, fn _ -> default end)

  @doc """

  Takes a parser `p` and creates a parser that will successfully parse lists of values that all satisfy `p`.

  Specifically, the input:

  1) Must be a list

  2) `p` must parse successfully all elements in the input

  If this is the case, the output will be `{:ok, list_of_parsed_values}`.

  If not all values can be parsed with `p`, the result will be the original
  parse error, enriched with the field `:failed_element` in the error details.

  If the input is not a list, the domain error `:not_a_list` will be returned.

  ## Examples

      iex> Data.Parser.list(Data.Parser.BuiltIn.integer()).([])
      {:ok, []}

      iex> Data.Parser.list(Data.Parser.BuiltIn.integer()).([1,2,3])
      {:ok, [1, 2, 3]}

      iex> {:error, e} = Data.Parser.list(Data.Parser.BuiltIn.integer()).(%{a: :b})
      ...> Error.reason(e)
      :not_a_list

      iex> {:error, e} = Data.Parser.list(Data.Parser.BuiltIn.integer()).([1, :b, 3])
      ...> Error.reason(e)
      :not_an_integer
      ...> Error.details(e)
      %{failed_element: :b}

  """
  @spec list(t(a, Error.t())) :: t([a], Error.t()) when a: var
  def list(p) do
    fn
      xs when is_list(xs) ->
        Result.fold(Result.ok([]), xs, fn el, acc ->
          case p.(el) do
            {:ok, parsed} ->
              Result.ok([parsed | acc])

            {:error, why} ->
              why
              |> Error.map_details(&Map.put(&1, :failed_element, el))
              |> Result.error()
          end
        end)
        |> Result.map(&Enum.reverse/1)

      _other ->
        Error.domain(:not_a_list) |> Result.error()
    end
  end

  @doc """

  Creates a parser that behaves exactly the same as the `list/1` parser, except
  that it will return the domain error `:empty_list` if applied to an empty list.

  ## Examples

      iex> Data.Parser.nonempty_list(Data.Parser.BuiltIn.integer()).([1, 2, 3])
      {:ok, [1, 2, 3]}

      iex> {:error, e} = Data.Parser.nonempty_list(Data.Parser.BuiltIn.integer()).([1, :b, 3])
      ...> Error.reason(e)
      :not_an_integer
      ...> Error.details(e)
       %{failed_element: :b}


      iex> {:error, e} = Data.Parser.nonempty_list(Data.Parser.BuiltIn.integer()).([])
      ...> Error.reason(e)
      :empty_list

  """
  @spec nonempty_list(t(a, Error.t())) :: t(nonempty_list(a), Error.t()) when a: var
  def nonempty_list(p) do
    fn
      [] -> Error.domain(:empty_list) |> Result.error()
      xs -> list(p).(xs)
    end
  end

  @doc """

  Takes a parser `p` and creates a parser that will successfully parse sets of
  values that all satisfy `p`.

  Specifically, the input:

  1) must be a `MapSet`

  2) all elements of the input set must be parsed correctly by `p`

  If this is the case, the output will be `{:ok, set_of_parsed_values}`.

  If not all values can be parsed with `p`, the result will be the original parse
  error, enriched with the field `:failed_element` in the error details.

  If the input is not a `MapSet`, the domain error `:not_a_set` will be returned.

  ## Examples

      iex> {:ok, s} = Data.Parser.set(Data.Parser.BuiltIn.integer()).(MapSet.new())
      ...> s
      #MapSet<[]>

      iex> {:ok, s} = Data.Parser.set(Data.Parser.BuiltIn.integer()).(MapSet.new([1,2,3]))
      ...> s
      #MapSet<[1, 2, 3]>

      iex> {:error, e} = Data.Parser.set(Data.Parser.BuiltIn.integer()).(%{a: :b})
      ...> Error.reason(e)
      :not_a_set

      iex> {:error, e} = Data.Parser.set(Data.Parser.BuiltIn.integer()).(MapSet.new([1, :b, 3]))
      ...> Error.reason(e)
      :not_an_integer
      ...> Error.details(e)
      %{failed_element: :b}

  """
  @spec set(t(a, Error.t())) :: t(Set.t(a), Error.t()) when a: var
  def set(p) do
    fn
      %Set{} = set ->
        set
        # to work around %Set{} opaqueness violation
        |> (&apply(Set, :to_list, [&1])).()
        |> list(p).()
        |> Result.map(&Set.new/1)

      _other ->
        Error.domain(:not_a_set) |> Result.error()
    end
  end

  @doc """

  Takes a parser and transforms it so that it works 'inside' `Maybe.t` values.

  If the original parser works on `String.t()`, the new one will work on
  `Maybe.t(String.t())`.

  Successful parses on `just()` values return `{:ok, {:just, result_of_parse}}`.
  Unsuccessful parses on `just()` values reutrn `{:error, parse_error}`.

  The parser will successfully return `{:ok, :nothing}` when applied to `:nothing`.

  ## Examples

      iex(2)> Data.Parser.maybe(
      ...> Data.Parser.predicate( &String.valid?/1, :invalid)).({:just, "good"})
      {:ok, {:just, "good"}}

      iex> Data.Parser.maybe(
      ...> Data.Parser.predicate( &String.valid?/1, :invalid)).({:just, 'bad'})
      {:error, :invalid}

      iex> Data.Parser.maybe(
      ...> Data.Parser.predicate( &String.valid?/1, :invalid)).(:nothing)
      {:ok, :nothing}

  """

  @spec maybe(t(a, b)) :: t(Maybe.t(a), Maybe.t(b)) when a: var, b: var
  def maybe(parser) do
    fn
      {:just, val} ->
        case parser.(val) do
          {:ok, res} -> ok(just(res))
          {:error, e} -> error(e)
        end

      :nothing ->
        ok(nothing())
    end
  end

  @doc """

  Takes a key parser and a value parser and creates a parser that will
  successfully parse maps where all keys satisfy the key parser and all
  values satisfy the value parser.

  Specifically, the input:

  1) Must be a map

  2) All keys of the input map must be parsed correctly by the key parser

  3) All values of the input map must be parsed correctly by the value parser

  If this is the case, the output will be `{:ok, map_of_parsed_keys_and_values}`.

  If not all keys can be parsed with the key parser, the result will be the
  original parse error, enriched with the field `:failed_key` in the error details.

  If not all values can be parsed with the value parser, the result will be the
  original parse error, enriched with the field `:failed_value` in the error details.

  If the input is not a map, the domain error `:not_a_map` will be returned.

  ## Examples

      iex> Data.Parser.map(Data.Parser.BuiltIn.string(), Data.Parser.BuiltIn.integer()).(%{})
      {:ok, %{}}

      iex> Data.Parser.map(Data.Parser.BuiltIn.string(), Data.Parser.BuiltIn.integer()).(%{"a" => 1, "b" => 2})
      {:ok, %{"a" => 1, "b" => 2}}

      iex> {:error, e} = Data.Parser.map(Data.Parser.BuiltIn.string(), Data.Parser.BuiltIn.integer()).([])
      ...> Error.reason(e)
      :not_a_map

      iex> {:error, e} = Data.Parser.map(Data.Parser.BuiltIn.string(), Data.Parser.BuiltIn.integer()).(%{:a => 1})
      ...> Error.reason(e)
      :not_a_string
      ...> Error.details(e)
      %{failed_key: :a}

      iex> {:error, e} = Data.Parser.map(Data.Parser.BuiltIn.string(), Data.Parser.BuiltIn.integer()).(%{"a" => "not_int"})
      ...> Error.reason(e)
      :not_an_integer
      ...> Error.details(e)
      %{failed_value: "not_int"}

  """
  @spec map(t(a, Error.t()), t(b, Error.t())) :: t(%{a => b}, Error.t()) when a: var, b: var
  def map(key_parser, value_parser) do
    fn
      input when is_map(input) ->
        # Parse all keys first
        key_result =
          Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
            case key_parser.(key) do
              {:ok, parsed_key} ->
                {:cont, {:ok, Map.put(acc, parsed_key, value)}}

              {:error, why} ->
                enriched_error =
                  case why do
                    %Error.DomainError{} -> Error.map_details(why, &Map.put(&1, :failed_key, key))
                    %Error.InfraError{} -> Error.map_details(why, &Map.put(&1, :failed_key, key))
                    _ -> why
                  end

                {:halt, {:error, enriched_error}}
            end
          end)

        case key_result do
          {:ok, keys_parsed_map} ->
            # Parse all values
            Enum.reduce_while(keys_parsed_map, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
              case value_parser.(value) do
                {:ok, parsed_value} ->
                  {:cont, {:ok, Map.put(acc, key, parsed_value)}}

                {:error, why} ->
                  enriched_error =
                    case why do
                      %Error.DomainError{} ->
                        Error.map_details(why, &Map.put(&1, :failed_value, value))

                      %Error.InfraError{} ->
                        Error.map_details(why, &Map.put(&1, :failed_value, value))

                      _ ->
                        why
                    end

                  {:halt, {:error, enriched_error}}
              end
            end)

          {:error, _} = error ->
            error
        end

      _other ->
        Error.domain(:not_a_map) |> Result.error()
    end
  end

  @doc """

  Takes a list of parsers and creates a parser that returns the first
  successful parse result, or an error listing the parsers and the failed
  input.

  ## Examples

      iex> Data.Parser.union(
      ...> [Data.Parser.BuiltIn.integer(),
      ...>  Data.Parser.BuiltIn.boolean()]).(true)
      {:ok, true}

      iex> Data.Parser.union(
      ...> [Data.Parser.BuiltIn.integer(),
      ...>  Data.Parser.BuiltIn.boolean()]).(1)
      {:ok, 1}

      iex> {:error, e} = Data.Parser.union(
      ...>   [Data.Parser.BuiltIn.integer(),
      ...>    Data.Parser.BuiltIn.boolean()]).(:atom)
      ...> Error.reason(e)
      :no_parser_applies
      ...> Error.details(e).input
      :atom

  """
  @spec union(list(t(any(), any()))) :: t(any(), any())
  def union(parsers) when is_list(parsers) do
    fn
      input ->
        Enum.find_value(
          parsers,
          error(Error.domain(:no_parser_applies, %{input: input, parsers: parsers})),
          fn parser ->
            case parser.(input) do
              {:ok, _} = success -> success
              _ -> false
            end
          end
        )
    end
  end
end
