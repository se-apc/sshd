defmodule Sshd.Default do
  @moduledoc """
  Default functions that can be overridden
  """

  @doc """
  Verify the Username / Password.

  Access can be granted based on user, password, remote_ip and remote_port
  """

  # def pwdfun("some_user", "some_password", _peer_addr = {{169, 254, 5, _x}, _port}, _state) do
  #   true
  # end

  # default to deny everyone
  def pwdfun(_username, _password, _peer_addr = {_remote_ip, _port}, _state) do
    false
  end


  @doc """
  Return the dynamic port for the given args
  """
  def get_port(:"network.ssh_port") do
    2022
  end

  @doc """
  Run do an interactive shell using IO.puts/IO.gets.  Do nothing by default
  """
  def shell(_user, _peer) do
    IO.puts("Interactive Login unsupported")
  end

  @doc """
  Execute a single command
  """
  def exec(_cmd, _user, _peer) do
    IO.puts("Command Execution unsupported")
  end

  @doc """
  Is interface enabled?

  This is an extension hook to allow individual SSH interfaces to be enabled/disabled at runtime
  """
  def enable?(_interface) do
    true
  end

  @doc """
  Passphrase to use when decoding the servers private key
  """
  def key_passphrase(_args) do
    "weak_password"
  end
end
