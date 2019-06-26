defmodule BootEnv.Util do
  require BootEnv.Exception, as: BootError

  defmacro __before_compile__(%Macro.Env{module: caller}) do
    validators =
      BootEnv
      |> Agent.get(&Map.get(&1, caller))

    get_priv_clauses =
      validators
      |> Map.keys()
      |> Enum.flat_map(fn [_ | _] = path ->
        1..length(path)
        |> Enum.map(&Enum.take(path, &1))
      end)
      |> Enum.uniq()
      |> Enum.map(fn path ->
        quote do
          defp get_priv(unquote(path)) do
            path_ast = unquote(path)
            gs = __MODULE__

            quote do
              GenServer.call(unquote(gs), {:get, unquote(path_ast)})
            end
          end
        end
      end)

    quote do
      defp boot_env, do: unquote(validators |> Map.to_list())
      unquote_splicing(get_priv_clauses)

      defp get_priv(path) do
        raise BootError.invalid_param_key(inspect(path))
      end

      defmacro get(quoted_path) do
        {path, []} = quoted_path |> Code.eval_quoted([], __CALLER__)
        get_priv(path)
      end
    end
  end

  def deep_get!(some, []) do
    some
  end

  def deep_get!(some, [k | ks]) do
    cond do
      is_map(some) ->
        some
        |> Map.has_key?(k)
        |> case do
          true ->
            some
            |> Map.get(k)
            |> deep_get!(ks)

          false ->
            raise BootError.missing_param(inspect(k))
        end

      Keyword.keyword?(some) ->
        some
        |> Keyword.has_key?(k)
        |> case do
          true ->
            some
            |> Keyword.get(k)
            |> deep_get!(ks)

          false ->
            raise BootError.missing_param(inspect(k))
        end

      true ->
        raise BootError.invalid_config(inspect(some))
    end
  end

  def deep_put(%{} = acc, [k], v) do
    Map.put(acc, k, v)
  end

  def deep_put(%{} = acc, [k | ks], v) do
    acc
    |> Map.update(
      k,
      deep_put(%{}, ks, v),
      fn %{} = prev ->
        deep_put(prev, ks, v)
      end
    )
  end
end
