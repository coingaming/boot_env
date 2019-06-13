defmodule BootEnvTest do
  use ExUnit.Case
  doctest BootEnv

  test "greets the world" do
    assert BootEnv.hello() == :world
  end
end
