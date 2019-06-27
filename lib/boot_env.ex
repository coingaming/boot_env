defmodule BootEnv do
  @moduledoc """
  Configuration provider to load and validate immutable application configs during boot process
  """

  require BootEnv.Exception, as: BootError

  @doc """
  Macro to declare configuration parameter
  and validation code for it (should be boolean expression)

  ## Example

  ```
  env host do
    String.valid?(host) and (host != "")
  end
  ```
  """
  defmacro env({name, ctx, _} = param, do: validator) when is_atom(name) and name != nil do
    [_ | _] = ctx_path = Keyword.get(ctx, __MODULE__)
    full_path = Enum.concat(ctx_path, [name])

    %Macro.Env{module: caller} = __CALLER__
    _ = Agent.start(fn -> %{} end, name: __MODULE__)

    validator_fn =
      {:fn, [],
       [
         {:->, [],
          [
            [param],
            validator
          ]}
       ]}

    __MODULE__
    |> Agent.update(fn %{} = mod_configs ->
      mod_configs
      |> Map.update(caller, %{full_path => validator_fn}, fn %{} = ms ->
        ms
        |> Map.has_key?(full_path)
        |> case do
          true ->
            #
            # TODO : similar check for `conf/2` name
            #
            BootError.schema_param_duplication(inspect(full_path))

          false ->
            Map.put(ms, full_path, validator_fn)
        end
      end)
    end)

    __MODULE__
    |> Agent.get(&Map.get(&1, caller))
    |> case do
      BootError.schema_param_duplication(_) = e ->
        raise e

      %{} = ms ->
        :ok = Enum.each(ms, fn {[_ | _], {:fn, _, _}} -> :ok end)
    end

    nil
  end

  @doc """
  Macro to declare configuration scope,
  can be nested and can contain `env/2` expressions

  ## Example

  ```
  conf :my_app do
    env foo, do: is_integer(foo)
    env bar, do: is_integer(bar)

    conf MyApp.Repo do
      env host, do: String.valid?(host)
    end
  end
  ```
  """
  defmacro conf(key_ast, do: code) do
    {k, []} = Code.eval_quoted(key_ast, [], __CALLER__)
    true = is_atom(k) and k != nil

    code
    |> Macro.prewalk(fn ast ->
      ast
      |> Macro.update_meta(fn meta ->
        meta
        |> Keyword.update(__MODULE__, [k], fn [_ | _] = ks ->
          Enum.concat(ks, [k])
        end)
      end)
    end)
  end

  defmacro __using__(_) do
    %Macro.Env{module: caller} = __CALLER__

    ets_table =
      "boot_env_ets_cache_#{Atom.to_string(caller)}"
      |> String.to_atom()

    quote do
      use GenServer
      import BootEnv, only: [conf: 2, env: 2]
      alias BootEnv.Util
      require BootEnv.Exception, as: BootError
      @before_compile Util

      defmacrop ets_table do
        unquote(ets_table)
      end

      def start_link(_ \\ []) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      @impl true
      def init(_) do
        ets_table() =
          :ets.new(ets_table(), [
            :protected,
            :named_table,
            {:read_concurrency, true},
            {:write_concurrency, true}
          ])

        :ok =
          boot_env()
          |> Enum.each(fn {[app | [_ | _] = path] = full_path, validator}
                          when is_function(validator, 1) ->
            val =
              app
              |> Application.get_all_env()
              |> Util.deep_get!(path)

            validator.(val)
            |> case do
              true ->
                true = :ets.insert(ets_table(), {full_path, val})

              false ->
                raise BootError.invalid_param_value(inspect(full_path))
            end
          end)

        {:ok, nil}
      end
    end
  end
end
