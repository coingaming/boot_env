defmodule BootEnvTest do
  use ExUnit.Case
  doctest BootEnv

  test "can't duplicate config names" do
    assert_raise BootEnv.Exception.SchemaParamDuplication,
                 ~r//,
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
    :ok = Application.put_env(:my_app, MyApp.Repo, host: "127.0.0.1")

    gs = BootEnvTest.Valid

    {_, []} =
      quote do
        defmodule unquote(gs) do
          use BootEnv

          conf :my_app do
            env foo, do: is_integer(foo)
            env bar, do: is_integer(bar)

            conf MyApp.Repo do
              env host, do: String.valid?(host)
            end
          end
        end
      end
      |> Code.eval_quoted()

    {{r0, r1, r2}, []} =
      quote do
        require unquote(gs)
        {:ok, _} = unquote(gs).start_link()

        {
          unquote(gs).get_env([:my_app, :foo]),
          unquote(gs).get_env([:my_app, :bar]),
          unquote(gs).get_env([:my_app, MyApp.Repo, :host])
        }
      end
      |> Code.eval_quoted()

    assert r0 == 100
    assert r1 == 200
    assert r2 == "127.0.0.1"

    assert_raise BootEnv.Exception.InvalidParamKey, ~r//, fn ->
      quote do
        require unquote(gs)
        unquote(gs).get_env([:my_app, :not_exist])
      end
      |> Code.eval_quoted()
    end

    #
    # reseed
    #

    :ok = Application.put_env(:my_app, :foo, 999)

    {x, []} =
      quote do
        require unquote(gs)
        unquote(gs).get_env([:my_app, :foo])
      end
      |> Code.eval_quoted()

    assert x == 100
    assert :ok = gs.reseed()

    {y, []} =
      quote do
        require unquote(gs)
        unquote(gs).get_env([:my_app, :foo])
      end
      |> Code.eval_quoted()

    assert y == 999
  end
end
