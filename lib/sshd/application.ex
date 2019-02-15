defmodule Sshd.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    ## create SSH table for storing SSH References
    Sshd.Table.create()

    children = [
      Sshd
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sshd.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
