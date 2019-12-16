defmodule Data.Parser do
  @moduledoc """

  `Data.Parser` holds higher-order functions used to create or modify parsers.

  """
  alias FE.{Maybe, Result}
  alias MapSet, as: Set
  import Result, only: [ok: 1, error: 1]
  import Maybe, only: [just: 1, nothing: 0]

  defdelegate kv(fields), to: Data.Parser.KV, as: :new

  @typedoc """

  A parser is a function which takes any value as input and produces a `Result.t`.

  More specifically, a `parser(a,b)` is a fuction that takes any input and
  returns `{:ok, a}` on a successful parse or `{:error, b}` if parsing failed.

  """
  @type t(a, b) :: (any -> Result.t(a, b))

  @doc """

  Takes a boolean function p (the predicate) and a default value and returns a
  parser. The parser's behavior when applied to input is as follows:

  If the predicate function applied to the input returns `true`, the parser
  wraps the input in an `{:ok, input}` tuple.

  If the predicate function returns `false`, the parser either returns
  `{:error, default}` when `default` was a value, or `default` applied to the
  input if `default` was a unary function.

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
  successfully if its input in `elements`.

  If the input is not a member of `elements` and `default` is a value, the
  parser fails with `{:error, default}`. If `default` is a unary function, the
  parser fails with `{:error, default(input)}`.

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

  Takes a parser `p` and creates a parser that will successfully parse inputs such that

  1) the input is a list
  2) `p` parses successfully all elements on the input list

  If this is the case, the output will be `{:ok, list_of_parsed_values}`.

  If not all values can be parsed with `p`, the result will be the orignal parse
  error, enriched with the field `:failed_element` in the error details.

  If the input is not a list, the domain error `:not_a_list` will be returned.

  ## Examples

      iex> Data.Parser.list(Data.Parser.BuiltIn.integer()).([])
      {:ok, []}

      iex> Data.Parser.list(Data.Parser.BuiltIn.integer()).([1,2,3])
      {:ok, [1, 2, 3]}

      iex> Data.Parser.list(Data.Parser.BuiltIn.integer()).(%{a: :b})
      {:error, %Error{details: %{}, kind: :domain, reason: :not_a_list}}

      iex(11)> Data.Parser.list(Data.Parser.BuiltIn.integer()).([1, :b, 3])
      {:error, %Error{details: %{failed_element: :b}, kind: :domain, reason: :not_an_integer}}

  """
  @spec list(Parser.t(a, Error.t())) :: Parser.t([a], Error.t()) when a: var
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

      iex> Data.Parser.nonempty_list(Data.Parser.BuiltIn.integer()).([1, :b, 3])
      {:error, %Error{details: %{failed_element: :b}, kind: :domain, reason: :not_an_integer}}

      iex> Data.Parser.nonempty_list(Data.Parser.BuiltIn.integer()).([])
      {:error, %Error{details: %{}, kind: :domain, reason: :empty_list}}

  """
  @spec nonempty_list(Parser.t(a, Error.t())) :: Parser.t(nonempty_list(a), Error.t()) when a: var
  def nonempty_list(p) do
    fn
      [] -> Error.domain(:empty_list) |> Result.error()
      xs -> list(p).(xs)
    end
  end

  @doc """
  Takes a parser `p` and creates a parser that will successfully parse inputs such that

  1) the input is a `MapSet`
  2) `p` parses successfully all elements in the input set

  If this is the case, the output will be `{:ok, set_of_parsed_values}`.

  If not all values can be parsed with `p`, the result will be the orignal parse
  error, enriched with the field `:failed_element` in the error details.

  If the input is not a `MapSet`, the domain error `:not_a_set` will be returned.

  ## Examples

      iex> {:ok, s} = Data.Parser.set(Data.Parser.BuiltIn.integer()).(MapSet.new())
      ...> s
      #MapSet<[]>

      iex> {:ok, s} = Data.Parser.set(Data.Parser.BuiltIn.integer()).(MapSet.new([1,2,3]))
      ...> s
      #MapSet<[1, 2, 3]>

      iex> Data.Parser.set(Data.Parser.BuiltIn.integer()).(%{a: :b})
      {:error, %Error{details: %{}, kind: :domain, reason: :not_a_set}}

      iex(11)> Data.Parser.set(Data.Parser.BuiltIn.integer()).(MapSet.new([1, :b, 3]))
      {:error, %Error{details: %{failed_element: :b}, kind: :domain, reason: :not_an_integer}}


  """
  @spec set(Parser.t(a, Error.t())) :: Parser.t(Set.t(a), Error.t()) when a: var
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

  Takes a parser and transforms it so that it works 'inside' Maybe.t values.

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
end
