defmodule Data.Parser do
  @moduledoc """

  `Data.Parser` holds higher-order functions used to create or modify parsers.

  """
  alias FE.{Maybe, Result}
  import Result, only: [ok: 1, error: 1]
  import Maybe, only: [just: 1, nothing: 0]

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
