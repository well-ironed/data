defmodule Data.Enum do
  @spec atomize_keys!(Enum.t(), Keyword.t()) :: Keyword.t()
  def atomize_keys!(enum, opts \\ []) do
    safe? = Keyword.get(opts, :safe, true)

    Enum.map(enum, fn {key, value} when is_binary(key) ->
      case safe? do
        true -> {String.to_existing_atom(key), value}
        false -> {String.to_atom(key), value}
      end
    end)
  end
end
