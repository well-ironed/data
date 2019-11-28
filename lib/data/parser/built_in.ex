defmodule Data.Parser.BuiltIn do
  alias Error
  alias FE.Result
  alias Data.Parser
  alias MapSet, as: Set

  @spec integer() :: Parser.t(integer, Error.t())
  def integer do
    fn
      int when is_integer(int) -> Result.ok(int)
      _other -> Error.domain(:not_an_integer) |> Result.error()
    end
  end

  @spec string() :: Parser.t(String.t(), Error.t())
  def string() do
    fn
      s when is_binary(s) -> Result.ok(s)
      _other -> Error.domain(:not_a_string) |> Result.error()
    end
  end

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

  @spec nonempty_list(Parser.t(a, Error.t())) :: Parser.t(nonempty_list(a), Error.t()) when a: var
  def nonempty_list(p) do
    fn
      [] -> Error.domain(:empty_list) |> Result.error()
      xs -> list(p).(xs)
    end
  end

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

  @spec boolean() :: Parser.t(boolean(), Error.t())
  def boolean do
    fn
      bool when is_boolean(bool) -> Result.ok(bool)
      _other -> Error.domain(:not_a_boolean) |> Result.error()
    end
  end

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
