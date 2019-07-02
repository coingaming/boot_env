# BootEnv

Elixir configuration provider inspired by Haskell programming experience. Runtime configuration of Haskell programs is a bit different if we compare with other languages like Elixir. Haskell program business logic mainly contains pure functions which can call only pure functions by their nature. This means that in random place of Haskell program something like Elixir function `Application.get_env/2` or `System.get_env/1` can't be called at all (because these functions are not pure). As a result of this, in Haskell programs all needed runtime configurations are usually fetched, transformed and validated during initial boot process of program, and after this passed to main loop function as arguments (typed values).

<img src="priv/img/logo.png" width="300"/>

## Benefits

- configuration parameters have a schema
- configuration parameters are validated during boot process according schema
- if runtime configuration is incorrect then application will crash on boot (it's much better than runtime errors in random moment of time)
- `get_env/1` expressions have compile-time guarantees of correctness according given schema
- configuration parameters are stored in ETS table, so fetching by key is super fast

## Usage

Define configuration schema in dedicated module:

- define namespaces with `conf/2` expressions
- multiple `conf/2` expressions are supported
- `conf/2` expressions can be nested
- define configuration parameters with `env/2` expressions
- do-block of `env/2` expression is boolean expression (parameter validation code)

```elixir
defmodule MyApp.BootEnv do
  use BootEnv

  conf :my_app do
    env ecto_repos, do: is_list(ecto_repos)
    env logo_url, do: Regex.match?(~r/^https?\:\/\/.+$/, logo_url)

    env backoffice_pagination do
      is_integer(backoffice_pagination) and
        backoffice_pagination > 0
    end

    conf MyApp.Repo do
      env username, do: String.valid?(username)
      env password, do: String.valid?(password)
      env database, do: String.valid?(database)
      env hostname, do: String.valid?(hostname)
      env pool_size, do: is_integer(pool_size) and pool_size > 1
    end
  end
end
```

Start configuration provider as first child in supervision tree:

```elixir
children =
  [
    # Start BootEnv configuration first
    MyApp.BootEnv,
    # Start the Ecto repository
    MyApp.Repo
    # ...
  ]
```

Fetch runtime configuration parameter with `get_env/1` expression where it's needed:

```elixir
require MyApp.BootEnv, as: Conf
img_tag(Conf.get_env([:my_app, :logo_url]), class: "image")
#=> <img src="https://foo.bar/img/smile.png" class="image">
```

## Installation

The package can be installed by adding `boot_env` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:boot_env, "~> 0.1.1"}
  ]
end
```

## Notes

I very recommend to combine this tool with [ExEnv](https://github.com/coingaming/ex_env).
