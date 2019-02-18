defmodule SshdExample.Password do
  @moduledoc """
  Development functions that can be overridden
  """

  @doc """
  Verify the Username / Password.

  Access can be granted based on user, password, remote_ip and remote_port
  """

  def pwdfun("test", "test", _peer_addr = {_remote_ip, _port}, _state) do
    true
  end

  def pwdfun(_username, _password, _peer_addr = {_remote_ip, _port}, _state) do
    false
  end
end
