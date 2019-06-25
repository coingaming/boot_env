defmodule BootEnv do
  @moduledoc """
  TODO : !!!!!!!!!!
  """

  require BootEnv.Exception, as: E

  @doc """
  TODO : !!!!!!!!!!
  """
  defmacro env({name, _, _} = param, do: validator) when is_atom(name) do
    %Macro.Env{module: caller} = __CALLER__
    _ = Agent.start(fn -> %{} end, name: __MODULE__)

    __MODULE__
    |> Agent.update(fn %{} = mod_configs ->
      mod_configs
      |> Map.update(caller, MapSet.new(), fn %MapSet{} = ms ->
        ms
        |> MapSet.member?(name)
        |> case do
          true ->
            E.schema_param_duplication(
              "config param #{inspect(name)} for #{caller} has been already defined!"
            )

          false ->
            MapSet.put(ms, name)
        end
      end)
    end)

    __MODULE__
    |> Agent.get(&Map.get(&1, caller))
    |> case do
      %MapSet{} -> :ok
      E.schema_param_duplication(_) = e -> raise e
    end

    #
    # TODO : !!!
    #
  end

  defmacro __using__(_) do
    quote do
      import BootEnv, only: [env: 2]
      #
      # TODO : !!!
      #
    end
  end
end
