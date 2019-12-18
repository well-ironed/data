defmodule Data.Constructor do
  alias Data.Parser.KV
  alias FE.Result

  @doc """

  Given a list of `field_spec`s, a `module`, and an input `map` or `Keyword`,
  create and run a parser which will either parse successfully and return an
  `{:ok, %__MODULE__{}}` or fail and return an `{:error, Error.t}` with details
  about the parsing failure.

  """
  @spec struct([KV.field_spec(any, any)], module(), KV.input) :: Result.t(struct, Error.t())
  def struct(field_specs, struct_module, input) do
    field_specs
    |> KV.new()
    |> Result.and_then(fn parser -> parser.(input) end)
    |> Result.map(&struct(struct_module, &1))
  end

end
