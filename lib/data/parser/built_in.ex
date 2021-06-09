defmodule Data.Parser.BuiltIn do
  @moduledoc """
  Parsers for built-in Elixir data types.
  """
  alias Error
  alias FE.Result
  alias Data.Parser

  @doc """

  Creates a parser that successfully parses `integer`s, and returns the
  domain error `:not_an_integer` for all other inputs.

  ## Examples
      iex> Data.Parser.BuiltIn.integer().(1)
      {:ok, 1}

      iex> {:error, e} = Data.Parser.BuiltIn.integer().(1.0)
      ...> Error.reason(e)
      :not_an_integer

      iex> {:error, e} = Data.Parser.BuiltIn.integer().(:hi)
      ...> Error.reason(e)
      :not_an_integer

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

      iex> {:error, e} = Data.Parser.BuiltIn.string().('hi')
      ...> Error.reason(e)
      :not_a_string

      iex> {:error, e} = Data.Parser.BuiltIn.string().(:hi)
      ...> Error.reason(e)
      :not_a_string

  """
  @spec string() :: Parser.t(String.t(), Error.t())
  def string() do
    fn
      s when is_binary(s) -> Result.ok(s)
      _other -> Error.domain(:not_a_string) |> Result.error()
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

      iex> {:error, e} = Data.Parser.BuiltIn.boolean().(1.0)
      ...> Error.reason(e)
      :not_a_boolean


      iex> {:error, e} = Data.Parser.BuiltIn.boolean().([:truth, :or, :dare])
      ...> Error.reason(e)
      :not_a_boolean

  """
  @spec boolean() :: Parser.t(boolean(), Error.t())
  def boolean do
    fn
      bool when is_boolean(bool) -> Result.ok(bool)
      _other -> Error.domain(:not_a_boolean) |> Result.error()
    end
  end

  @doc """

  Creates a parser that successfully parses `atom`s, and returns the
  domain error `:not_an_atom` for all other inputs.

  ## Examples
      iex> Data.Parser.BuiltIn.atom().(:atom)
      {:ok, :atom}

      iex> Data.Parser.BuiltIn.atom().(:other_atom)
      {:ok, :other_atom}

      iex> {:error, e} = Data.Parser.BuiltIn.atom().(1.0)
      ...> Error.reason(e)
      :not_an_atom


      iex> {:error, e} = Data.Parser.BuiltIn.atom().(["truth", "or", "dare"])
      ...> Error.reason(e)
      :not_an_atom

  """
  @spec atom() :: Parser.t(atom(), Error.t())
  def atom do
    fn
      atom when is_atom(atom) -> Result.ok(atom)
      _other -> Error.domain(:not_an_atom) |> Result.error()
    end
  end

  @doc """

  Creates a parser that successfully parses `Date.t`s or `String.t` that
  represent legitimate `Date.t`s.

  Returns a domain error representing the parse failure if
  the string input cannot be parsed, and the domain error `:not_a_date`
  for all other inputs.

  ## Examples
      iex> {:ok, d} = Data.Parser.BuiltIn.date().(~D[1999-12-31])
      ...> d
      ~D[1999-12-31]

      iex> {:ok, d} = Data.Parser.BuiltIn.date().("1999-12-31")
      ...> d
      ~D[1999-12-31]

      iex> {:error, e} = Data.Parser.BuiltIn.date().("19991232")
      ...> Error.reason(e)
      :invalid_format

      iex> {:error, e} = Data.Parser.BuiltIn.date().("1999-12-32")
      ...> Error.reason(e)
      :invalid_date

      iex> {:error, e} = Data.Parser.BuiltIn.date().(123456789)
      ...> Error.reason(e)
      :not_a_date

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

  @doc """

  Creates a parser that successfully parses `DateTime.t`s or `String.t` that
  represent legitimate `DateTime.t`s.

  Returns a domain error representing the parse failure if the string input
  cannot be parsed, and the domain error `:not_a_datetime` for all other inputs.

  ## Examples
      iex> Data.Parser.BuiltIn.datetime().(~U[1999-12-31 23:59:59Z])
      {:ok, ~U[1999-12-31 23:59:59Z]}

      iex> Data.Parser.BuiltIn.datetime().("1999-12-31 23:59:59Z")
      {:ok, ~U[1999-12-31 23:59:59Z]}

      iex> {:error, e} = Data.Parser.BuiltIn.datetime().("1999-12-32 23:59:59Z")
      ...> Error.reason(e)
      :invalid_date

      iex> {:error, e} = Data.Parser.BuiltIn.datetime().("1999-12-31 23:59:99Z")
      ...> Error.reason(e)
      :invalid_time

      iex> {:error, e} = Data.Parser.BuiltIn.datetime().("1999-12-31 23:59:59")
      ...> Error.reason(e)
      :missing_offset

      iex> {:error, e} = Data.Parser.BuiltIn.datetime().(123456789)
      ...> Error.reason(e)
      :not_a_datetime

  """

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

  @doc """

  Creates a parser that successfully parses `NaiveDateTime.t`s or `String.t` that
  represent legitimate `NaiveDateTime.t`s.

  Returns a domain error representing the parse failure if the string input
  cannot be parsed, and the domain error `:not_a_naive_datetime` for all other
  inputs.

  ## Examples
      iex> Data.Parser.BuiltIn.naive_datetime.(~N[1999-12-31 23:59:59])
      {:ok, ~N[1999-12-31 23:59:59]}

      iex> Data.Parser.BuiltIn.naive_datetime.("1999-12-31 23:59:59")
      {:ok, ~N[1999-12-31 23:59:59]}

      iex> {:error, e} = Data.Parser.BuiltIn.naive_datetime.("1999-12-32 23:59:59")
      ...> Error.reason(e)
      :invalid_date

      iex> {:error, e} = Data.Parser.BuiltIn.naive_datetime.("1999-12-31 23:59:99")
      ...> Error.reason(e)
      :invalid_time

      iex> {:error, e} = Data.Parser.BuiltIn.naive_datetime.(123456789)
      ...> Error.reason(e)
      :not_a_naive_datetime
  """
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

  @doc """

  Creates a parser that successfully parses strings representing either
  `Integer`s or `Float`s.

  Returns a domain error detailing the parse failure on bad inputs.

  Look out! Partial results, such as that of Integer.parse("abc123"), still
  count as errors!

  ## Examples
      iex> Data.Parser.BuiltIn.string_of(Float).("1.1")
      {:ok, 1.1}

      iex> {:error, e} = Data.Parser.BuiltIn.string_of(Float).("abc")
      ...> Error.reason(e)
      :not_parseable_as_float
      ...> Error.details(e)
      %{input: "abc", native_parser_output: :error}

      iex> Data.Parser.BuiltIn.string_of(Integer).("1234567890")
      {:ok, 1234567890}

      iex> {:error, e} = Data.Parser.BuiltIn.string_of(Integer).("123abc")
      ...> Error.reason(e)
      :not_parseable_as_integer
      ...> Error.details(e)
      %{input: "123abc", native_parser_output: {123, "abc"}}

      iex> {:error, e} = Data.Parser.BuiltIn.string_of(Integer).([])
      ...> Error.reason(e)
      :not_a_string

  """
  @spec string_of(Integer | Float) :: Parser.t(integer() | float(), Error.t())
  def string_of(mod) when mod in [Integer, Float] do
    mod_downcase = String.downcase("#{inspect(mod)}")

    fn input ->
      case is_binary(input) && mod.parse(input) do
        {n, ""} ->
          Result.ok(n)

        false ->
          Error.domain(:not_a_string, %{input: input})
          |> Result.error()

        output ->
          Error.domain(
            :"not_parseable_as_#{mod_downcase}",
            %{input: input, native_parser_output: output}
          )
          |> Result.error()
      end
    end
  end
end
