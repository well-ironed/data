defmodule Data.BuiltIn do
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

  @spec list([a], Data.Parser.parser(a, b)) :: Result.t(b, Error.t) when a: var, b: var
  def list(xs, p) when is_list(xs) do
    Result.fold(Result.ok([]), xs, fn el, acc ->
      case p.(el) do
        {:ok, parsed} ->
          Result.ok([parsed|acc])
        {:error, why} ->
          why
          |> Error.map_details(&Map.put(&1, :failed_element, el))
          |> Result.error()
      end
    end)
    |> Result.map(&Enum.reverse(&1))
  end

  def list(_, _), do: Error.domain(:not_a_list) |> Result.error()
end
