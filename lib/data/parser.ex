defmodule Data.Parser do
  alias FE.Result

  @type t(a, b) :: (any -> Result.t(a, b))

  @spec predicate((a -> boolean()), b | (a -> b)) :: t(a, b) when a: var, b: var
  def predicate(p, default) when is_function(default, 1) do
    fn x ->
      case p.(x) do
        true -> Result.ok(x)
        false -> default.(x) |> Result.error()
      end
    end
  end

  def predicate(p, default), do: predicate(p, fn _ -> default end)

  @spec one_of([a], b) :: t(a, b) when a: var, b: var
  def one_of(elements, default) do
    fn x ->
      case Enum.member?(elements, x) do
        true -> Result.ok(x)
        false -> Result.error(default)
      end
    end
  end
end
