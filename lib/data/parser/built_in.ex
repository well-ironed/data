defmodule Data.Parser.BuiltIn do
  @moduledoc """
  Parsers for built-in Elixir data types.
  """
  alias Error
  alias FE.Result
  alias Data.Parser
  alias MapSet, as: Set

  @doc """

  Creates a parser that successfully parses `integer`s, and returns the
  domain error `:not_an_integer` for all other inputs.


  ## Examples
      iex> Data.Parser.BuiltIn.integer().(1)
      {:ok, 1}

      iex> Data.Parser.BuiltIn.integer().(1.0)
      {:error, %Error{details: %{}, kind: :domain, reason: :not_an_integer}}

      iex> Data.Parser.BuiltIn.integer().(:hi)
      {:error, %Error{details: %{}, kind: :domain, reason: :not_an_integer}}

  """
  @spec integer() :: Parser.t(integer, Error.t())
  def integer do
    fn
      int when is_integer(int) -> Result.ok(int)
      _other -> Error.domain(:not_an_integer) |> Result.error()
    end
  end

  @doc """

  Creates a parser that succesfully parses `String.t`s (a.k.a binaries), and
  returns the domain error `:not_a_string` for all other inputs.

  ## Examples

      iex> Data.Parser.BuiltIn.string().("hi")
      {:ok, "hi"}

      iex> Data.Parser.BuiltIn.string().('hi')
      {:error, %Error{details: %{}, kind: :domain, reason: :not_a_string}}

      iex> Data.Parser.BuiltIn.string().(:hi)
      {:error, %Error{details: %{}, kind: :domain, reason: :not_a_string}}

  """
  @spec string() :: Parser.t(String.t(), Error.t())
  def string() do
    fn
      s when is_binary(s) -> Result.ok(s)
      _other -> Error.domain(:not_a_string) |> Result.error()
    end
  end

  @doc """

  Takes a parser `p` and creates a parser that will successfully parse inputs such that

  1) the input is a list
  2) `p` parses successfully all elements on the input list

  If this is the case, the output will be `{:ok, list_of_parsed_values}`.

  If not all values can be parsed with `p`, the result will be the orignal parse
  error, enriched with the field `:failed_element` in the error details.

  If the input is not a list, the domain error `:not_a_list` will be returned.

  ## Examples

      iex> Data.Parser.BuiltIn.list(Data.Parser.BuiltIn.integer()).([])
      {:ok, []}

      iex> Data.Parser.BuiltIn.list(Data.Parser.BuiltIn.integer()).([1,2,3])
      {:ok, [1, 2, 3]}

      iex> Data.Parser.BuiltIn.list(Data.Parser.BuiltIn.integer()).(%{a: :b})
      {:error, %Error{details: %{}, kind: :domain, reason: :not_a_list}}

      iex(11)> Data.Parser.BuiltIn.list(Data.Parser.BuiltIn.integer()).([1, :b, 3])
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

      iex> Data.Parser.BuiltIn.nonempty_list(Data.Parser.BuiltIn.integer()).([1, 2, 3])
      {:ok, [1, 2, 3]}

      iex> Data.Parser.BuiltIn.nonempty_list(Data.Parser.BuiltIn.integer()).([1, :b, 3])
      {:error, %Error{details: %{failed_element: :b}, kind: :domain, reason: :not_an_integer}}

      iex> Data.Parser.BuiltIn.nonempty_list(Data.Parser.BuiltIn.integer()).([])
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

      iex> {:ok, s} = Data.Parser.BuiltIn.set(Data.Parser.BuiltIn.integer()).(MapSet.new())
      ...> s
      #MapSet<[]>

      iex> {:ok, s} = Data.Parser.BuiltIn.set(Data.Parser.BuiltIn.integer()).(MapSet.new([1,2,3]))
      ...> s
      #MapSet<[1, 2, 3]>

      iex> Data.Parser.BuiltIn.set(Data.Parser.BuiltIn.integer()).(%{a: :b})
      {:error, %Error{details: %{}, kind: :domain, reason: :not_a_set}}

      iex(11)> Data.Parser.BuiltIn.set(Data.Parser.BuiltIn.integer()).(MapSet.new([1, :b, 3]))
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

  Creates a parser that successfully parses `boolean`s, and returns the
  domain error `:not_a_boolean` for all other inputs.


  ## Examples
      iex> Data.Parser.BuiltIn.boolean().(true)
      {:ok, true}

      iex> Data.Parser.BuiltIn.boolean().(false)
      {:ok, false}

      iex> Data.Parser.BuiltIn.boolean().(1.0)
      {:error, %Error{details: %{}, kind: :domain, reason: :not_a_boolean}}


      iex> Data.Parser.BuiltIn.boolean().([:truth, :or, :dare])
      {:error, %Error{details: %{}, kind: :domain, reason: :not_a_boolean}}

  """
  @spec boolean() :: Parser.t(boolean(), Error.t())
  def boolean do
    fn
      bool when is_boolean(bool) -> Result.ok(bool)
      _other -> Error.domain(:not_a_boolean) |> Result.error()
    end
  end

  @doc """

  Creates a parser that successfully parses `Date.t`s or `String.t` that
  represent legitimate `Date.t`s
  and returns the domain error `:not_a_date` for all other inputs.


  ## Examples
      iex> {:ok, d} = Data.Parser.BuiltIn.date().(~D[1999-12-31])
      ...> d
      ~D[1999-12-31]

      iex> {:ok, d} = Data.Parser.BuiltIn.date().("1999-12-31")
      ...> d
      ~D[1999-12-31]

      iex> Data.Parser.BuiltIn.date().("1999-12-32")
      {:error, %Error{details: %{}, kind: :domain, reason: :invalid_date}}

      iex> Data.Parser.BuiltIn.date().(123456789)
      {:error, %Error{details: %{}, kind: :domain, reason: :not_a_date}}

  """
  @spec date() :: Parser.t(Date.t(), Error.t())
  def date do
    fn
      %Date{} = date ->
        Result.ok(date)

      string when is_binary(string) ->
        case Date.from_iso8601(string) do
          {:ok, d} -> Result.ok(d)
          {:error, reason} -> Error.domain(reason) |> Result.error()
        end

      _other ->
        Error.domain(:not_a_date) |> Result.error()
    end
  end

  @spec datetime() :: Parser.t(DateTime.t(), Error.t())
  def datetime do
    fn
      %DateTime{} = datetime ->
        Result.ok(datetime)

      string when is_binary(string) ->
        case DateTime.from_iso8601(string) do
          {:ok, dt, _offset} -> Result.ok(dt)
          {:error, reason} -> Error.domain(reason) |> Result.error()
        end

      _other ->
        Error.domain(:not_a_datetime) |> Result.error()
    end
  end

  @spec naive_datetime() :: Parser.t(NaiveDateTime.t(), Error.t())
  def naive_datetime do
    fn
      %NaiveDateTime{} = naive_datetime ->
        Result.ok(naive_datetime)

      string when is_binary(string) ->
        case NaiveDateTime.from_iso8601(string) do
          {:ok, ndt} -> Result.ok(ndt)
          {:error, reason} -> Error.domain(reason) |> Result.error()
        end

      _other ->
        Error.domain(:not_a_naive_datetime) |> Result.error()
    end
  end
end
