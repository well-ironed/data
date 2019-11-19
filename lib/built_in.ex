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
end
