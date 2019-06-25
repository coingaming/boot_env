defmodule BootEnv.Exception do
  @error_list [
    :schema_param_duplication,
    :invalid_param_value,
    :invalid_param_key,
    :invalid_config,
    :missing_param
  ]

  @exception_list @error_list
                  |> Stream.map(&(&1 |> Atom.to_string() |> Macro.camelize()))
                  |> Enum.map(&Module.concat(__MODULE__, &1))

  @exception_list
  |> Enum.each(fn mod ->
    defmodule mod do
      @type t :: %__MODULE__{message: String.t()}
      defexception [:message]
    end
  end)

  @error_list
  |> Enum.zip(@exception_list)
  |> Enum.each(fn {error, exception} ->
    @doc """
    Shortcut for #{exception} exception

    ## Examples

    ```
    iex> require #{__MODULE__}
    iex> #{__MODULE__}.#{error}("my error message")
    %#{exception}{message: "my error message"}
    ```
    """
    defmacro unquote(error)(message) do
      exception = unquote(exception)

      quote do
        %unquote(exception){message: unquote(message)}
      end
    end
  end)
end
