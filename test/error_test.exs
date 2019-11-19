defmodule ErrorTest do
  use ExUnit.Case, async: true

  alias Error

  test "a domain error can be created with reason" do
    assert Error.domain(:reason) == %Error{
             kind: :domain,
             reason: :reason,
             details: %{}
           }
  end

  test "a domain error can be created with reason and details" do
    assert Error.domain(:reason, %{extra: :info}) == %Error{
             kind: :domain,
             reason: :reason,
             details: %{extra: :info}
           }
  end

  test "error kind can be accessed" do
    error = Error.domain(:r, %{})
    assert Error.kind(error) == :domain
  end

  test "error reason can be accessed" do
    error = Error.domain(:a, %{c: :d})
    assert Error.reason(error) == :a
  end

  test "error details can be accessed when set explicitly" do
    error = Error.domain(:i, %{k: :l})
    assert Error.details(error) == %{k: :l}
  end

  test "default error details can be accessed" do
    error = Error.domain(:m)
    assert Error.details(error) == %{}
  end

  test "details can be mapped over" do
    error = Error.domain(:m, %{a: :b, c: :d})
    error = Error.map_details(error, fn d -> Map.put(d, :e, :f) end)
    assert Error.details(error) == %{a: :b, c: :d, e: :f}
  end
end
