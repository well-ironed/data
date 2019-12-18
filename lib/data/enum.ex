defmodule Data.Enum do
  @moduledoc """
  Functions which extend built-in Enum functionality.
  """

  @doc """

  Takes a key-value-type Enum (`map`, `MapSet`, associative list) with binary
  keys, and returns a `Keyword`, where all keys have been converted to atoms.

  The optional paramter `:safe`, which defaults to `true`, determines whether
  new atoms should be generated dynamically on-the-fly.

  If `:safe` is `true` and an unknown atom would have to be created, this
  function throws an `ArgumentError`.  If `:safe` is `false`, then a new atom
  is created.

  Generating new atoms on-the-fly poses a security risk in prodution systems
  and should be avoided.


  ## Examples
      # note: the atom :hello does not exist in the VM
      iex> Data.Enum.atomize_keys!(%{"hello" => "world"})
      ** (ArgumentError) argument error

      # note: now, the atom does exist!
      iex> :present; Data.Enum.atomize_keys!(%{"present" => "yes!"})
      [present: "yes!"]

      # now, we'll generate a new atom
      iex> Data.Enum.atomize_keys!(%{"something_new" => "DANGER ZONE"},
      ...> safe: false)
      [something_new: "DANGER ZONE"]

  """
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
