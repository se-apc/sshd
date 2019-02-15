defmodule Sshd.Table do
  @moduledoc """
  The module is used to store the SSH Daemon References. It should be started atleast
  one level above the Sshd module (where the ssh daemons are started) so that in the event
  that Sshd, crashes, the old daemon references can be retrieved and used again (if they daemon
  is still alive). The daemon references are stored in an ets database.
  """

  @doc """
  Create new ets database
  """
  def create() do
    :ets.new(__MODULE__, [:set, :public, :named_table])
  end

  @doc """
  Function for storing an SSH Reference `ref` with Key `key` in the ets database
  """
  def set(key, ref) do
    :ets.insert(__MODULE__, {key, ref})
  end

  @doc """
  Function for getting an SSH Daemon Reference with Key `key` in the ets database
  """
  def get(key) do
    with [{_name, ref}] <- :ets.lookup(__MODULE__, key),
         {:ok, _} <- :ssh.daemon_info(ref) do
      ref
    else
      ## if the daemon is not alive
      _ ->
        nil
    end
  end
end
