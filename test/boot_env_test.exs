defmodule BootEnvTest do
  use ExUnit.Case
  doctest BootEnv

  test "can't duplicate config names" do
    assert_raise BootEnv.Exception.SchemaParamDuplication,
                 ~r/config param \[:hello, :bar\] for Elixir.BootEnvTest.Duplicate has been already defined\!/,
                 fn ->
                   quote do
                     defmodule BootEnvTest.Duplicate do
                       use BootEnv

                       conf :hello do
                         env foo, do: is_integer(foo)
                         env bar, do: is_integer(bar)
                         env bar, do: is_binary(bar)
                       end
                     end
                   end
                   |> Code.compile_quoted()
                 end
  end

  test "can run vaid GS" do
    :ok = Application.put_env(:my_app, :foo, 100)
    :ok = Application.put_env(:my_app, :bar, 200)
    :ok = Application.put_env(:my_app, MyApp.Repo, host: 5432)

    gs = BootEnvTest.Valid

    {_, []} =
      quote do
        defmodule unquote(gs) do
          use BootEnv

          conf :my_app do
            env foo, do: is_integer(foo)
            env bar, do: is_integer(bar)

            conf MyApp.Repo do
              env host, do: is_binary(host)
            end
          end
        end
      end
      |> Code.eval_quoted()

    assert {:ok, _} = gs.start_link()

    {{r0, r1, r2, r3, r4}, []} =
      quote do
        require unquote(gs)

        {
          unquote(gs).get([:my_app]),
          unquote(gs).get([:my_app, :foo]),
          unquote(gs).get([:my_app, :bar]),
          unquote(gs).get([:my_app, MyApp.Repo]),
          unquote(gs).get([:my_app, MyApp.Repo, :host])
        }
      end
      |> Code.eval_quoted()

    assert r0 == %{MyApp.Repo => %{host: 5432}, :bar => 200, :foo => 100}
    assert r1 == 100
    assert r2 == 200
    assert r3 == %{host: 5432}
    assert r4 == 5432

    assert_raise BootEnv.Exception.InvalidParamKey, ~r//, fn ->
      quote do
        require unquote(gs)
        unquote(gs).get([:my_app, :not_exist])
      end
      |> Code.eval_quoted()
    end
  end
end
