defmodule Data.Parser do
  alias FE.{Maybe,Result}
  import Result, only: [ok: 1, error: 1]
  import Maybe, only: [just: 1, nothing: 0]

  @type t(a, b) :: (any -> Result.t(a, b))

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

  @spec one_of([a], b) :: t(a, b) when a: var, b: var
  def one_of(elements, default) do
    fn x ->
      case Enum.member?(elements, x) do
        true -> ok(x)
        false -> error(default)
      end
    end
  end

  @spec maybe(t(a,b)) :: t(Maybe.t(a), Maybe.t(b)) when a: var, b: var
  def maybe(parser) do
    fn {:just, val} ->
      case parser.(val) do
        {:ok, res} -> ok(just(res))
        {:error, e} -> error(e)
      end
      :nothing -> ok(nothing())
    end
  end

end
