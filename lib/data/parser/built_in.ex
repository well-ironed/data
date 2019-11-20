defmodule Data.Parser.BuiltIn do
  alias Error
  alias FE.Result

  @spec integer(any()) :: Result.t(integer(), any())
  def integer(int) when is_integer(int) do
    Result.ok(int)
  end

  def integer(_other) do
    Error.domain(:not_an_integer) |> Result.error()
  end

  @spec string(any()) :: Result.t(String.t(), any())
  def string(s) when is_binary(s) do
    Result.ok(s)
  end

  def string(_other) do
    Error.domain(:not_a_string) |> Result.error()
  end

  @spec list([a], Data.Parser.t(a, b)) :: Result.t(b, Error.t()) when a: var, b: var
  def list(xs, p) when is_list(xs) do
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
    |> Result.map(&Enum.reverse(&1))
  end

  def list(_, _), do: Error.domain(:not_a_list) |> Result.error()

  @spec nonempty_list([a], Data.Parser.t(a, b)) :: Result.t(b, Error.t())
        when a: var, b: var
  def nonempty_list([], _), do: Error.domain(:empty_list) |> Result.error()
  def nonempty_list(xs, p), do: list(xs, p)

  @spec boolean(boolean()) :: Result.t(boolean(), Error.t())
  def boolean(bool) when is_boolean(bool) do
    Result.ok(bool)
  end

  def boolean(_) do
    Error.domain(:not_a_boolean) |> Result.error()
  end

  @spec date(Date.t() | String.t()) :: Result.t(Date.t(), Error.t())
  def date(date) do
    case date do
      %Date{} ->
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

  @spec datetime(DateTime.t() | String.t()) :: Result.t(DateTime.t(), Error.t())
  def datetime(datetime) do
    case datetime do
      %DateTime{} ->
        Result.ok(datetime)

      string when is_binary(string) ->
        case DateTime.from_iso8601(datetime) do
          {:ok, dt, _offset} -> Result.ok(dt)
          {:error, reason} -> Error.domain(reason) |> Result.error()
        end

      _other ->
        Error.domain(:not_a_datetime) |> Result.error()
    end
  end

  @spec naive_datetime(NaiveDateTime.t() | String.t()) :: Result.t(NaiveDateTime.t(), Error.t())
  def naive_datetime(naive_datetime) do
    case naive_datetime do
      %NaiveDateTime{} ->
        Result.ok(naive_datetime)

      string when is_binary(string) ->
        case NaiveDateTime.from_iso8601(naive_datetime) do
          {:ok, ndt} -> Result.ok(ndt)
          {:error, reason} -> Error.domain(reason) |> Result.error()
        end

      _other ->
        Error.domain(:not_a_naive_datetime) |> Result.error()
    end
  end
end
