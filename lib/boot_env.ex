defmodule BootEnv do
  @moduledoc """
  TODO : !!!!!!!!!!
  """

  require BootEnv.Exception, as: BootError

  @doc """
  TODO : !!!!!!!!!!
  """
  defmacro env({name, ctx, _} = param, do: validator) when is_atom(name) and name != nil do
    [_ | _] = ctx_path = Keyword.get(ctx, __MODULE__)
    full_path = ctx_path ++ [name]

    %Macro.Env{module: caller} = __CALLER__
    _ = Agent.start(fn -> %{} end, name: __MODULE__)

    __MODULE__
    |> Agent.update(fn %{} = mod_configs ->
      mod_configs
      |> Map.update(caller, MapSet.new([full_path]), fn %MapSet{} = ms ->
        ms
        |> MapSet.member?(full_path)
        |> case do
          true ->
            BootError.schema_param_duplication(
              "config param #{inspect(full_path)} for #{caller} has been already defined!"
            )

          false ->
            MapSet.put(ms, full_path)
        end
      end)
    end)

    __MODULE__
    |> Agent.get(&Map.get(&1, caller))
    |> case do
      %MapSet{} -> :ok
      BootError.schema_param_duplication(_) = e -> raise e
    end

    #
    # TODO !!!
    #

    nil
  end

  defmacro conf(key_ast, do: code) do
    {k, []} = Code.eval_quoted(key_ast, [], __CALLER__)
    true = is_atom(k) and k != nil

    code
    |> Macro.prewalk(fn ast ->
      ast
      |> Macro.update_meta(fn meta ->
        meta
        |> Keyword.update(__MODULE__, [k], fn [_ | _] = ks ->
          ks ++ [k]
        end)
      end)
    end)
  end

  defmacro __using__(_) do
    quote do
      use GenServer
      import BootEnv, only: [conf: 2, env: 2]
      alias BootEnv.Util
      require BootEnv.Exception, as: BootError
      @before_compile Util

      def start_link(_ \\ []) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      @impl true
      def init(_) do
        state =
          boot_env()
          |> Enum.reduce(%{}, fn [app | [_ | _] = path] = full_path, acc = %{} ->
            val =
              app
              |> Application.get_all_env()
              |> Util.deep_get!(path)

            acc
            |> Util.deep_put(full_path, val)
          end)

        {
          :ok,
          state
        }
      end

      @impl true
      def handle_call({:get, path}, _, %{} = state) do
        {
          :reply,
          Util.deep_get!(state, path),
          state
        }
      end
    end
  end
end
