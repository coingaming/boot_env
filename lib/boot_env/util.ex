defmodule BootEnv.Util do
  require BootEnv.Exception, as: BootError

  defmacro __before_compile__(%Macro.Env{module: caller}) do
    validators =
      BootEnv
      |> Agent.get(&Map.get(&1, caller))

    get_priv_clauses =
      validators
      |> Map.keys()
      |> Enum.map(fn path ->
        quote do
          defp get_priv(unquote(path)) do
            path_ast = unquote(path)
            this_ets = ets_table()

            quote do
              [{unquote(path_ast), val}] =
                unquote(this_ets)
                |> :ets.lookup(unquote(path_ast))

              val
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

      @doc """
      Safe macro to fetch valid config parameters,
      has compile-time and runtime guarantees
      according given `conf/2` and `env/2` schema
      """
      defmacro get_env(quoted_path) do
        {path, []} = quoted_path |> Code.eval_quoted([], __CALLER__)
        get_priv(path)
      end

      @doc """
      Function to reseed ETS storage, if you
      changed Application env and want to apply
      changes. Not recommended to use (runtime
      mutation of Application env is bad idea).
      """
      def reseed do
        GenServer.call(__MODULE__, :reseed)
      end
    end
  end

  @doc """
  Strict `get_in/2` function to fetch
  deep data from map/keyword list

  ## Examples

  ```
  iex> BootEnv.Util.deep_get!(%{foo: [bar: 123]}, [:foo, :bar])
  123

  iex> BootEnv.Util.deep_get!(%{foo: [bar: 123]}, [:foo, :bar, :baz])
  ** (BootEnv.Exception.InvalidConfig) 123

  iex> BootEnv.Util.deep_get!(%{foo: [bar: 123]}, [:foo, :hello])
  ** (BootEnv.Exception.MissingParam) :hello

  iex> BootEnv.Util.deep_get!(%{foo: [bar: 123]}, [:hello])
  ** (BootEnv.Exception.MissingParam) :hello
  ```
  """
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

  @doc """
  Safe `put_in/2` function to put
  value to nested map

  ## Examples

  ```
  iex> BootEnv.Util.deep_put(%{foo: 123}, [:bar, :baz], 321)
  %{foo: 123, bar: %{baz: 321}}

  iex> BootEnv.Util.deep_put(%{foo: %{hello: 123}}, [:foo, :bar, :baz], 321)
  %{foo: %{hello: 123, bar: %{baz: 321}}}
  ```
  """
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
