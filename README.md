# Sshd

Sshd is a thin wrapper around the Erlang `:ssh` module.  It allows the endpoints to be configured via `config/config.exs` and managed at runtime.

## Example

See the `example` project for examples of the different hooks available

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sshd` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sshd, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/sshd](https://hexdocs.pm/sshd).

