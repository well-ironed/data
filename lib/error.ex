defmodule Error do
  defstruct [:kind, :reason, :details]

  @type kind :: :domain
  @type reason :: atom()

  @opaque t(a) :: %__MODULE__{
            kind: kind,
            reason: reason,
            details: a
          }

  @opaque t :: t(map())

  @spec domain(atom(), a) :: t(a) when a: map
  def domain(reason, details \\ %{}) when is_atom(reason) and is_map(details) do
    %__MODULE__{kind: :domain, reason: reason, details: details}
  end

  @spec kind(t) :: kind
  def kind(%__MODULE__{kind: kind}), do: kind

  @spec reason(t) :: reason
  def reason(%__MODULE__{reason: reason}), do: reason

  @spec details(t(a)) :: a when a: map
  def details(%__MODULE__{details: details}), do: details

  @spec map_details(t(a), (a -> b)) :: t(b) when a: map, b: map
  def map_details(%__MODULE__{details: details} = error, f) do
    %__MODULE__{error | details: f.(details)}
  end
end
