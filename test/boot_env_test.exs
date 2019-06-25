defmodule BootEnvTest do
  use ExUnit.Case
  doctest BootEnv

  test "can't duplicate config names" do
    assert_raise BootEnv.Exception.SchemaParamDuplication,
                 ~r/config param :bar for Elixir.BootEnvTest.Duplicate has been already defined/,
                 fn ->
                   quote do
                     defmodule BootEnvTest.Duplicate do
                       use BootEnv
                       env foo, do: is_integer(foo)
                       env bar, do: is_integer(bar)
                       env bar, do: is_binary(bar)
                     end
                   end
                   |> Code.compile_quoted()
                 end
  end
end
