defmodule SshdExample.Config do

  def get_port(:"network.ssh_port") do
    2022
  end

  @doc """
  Passphrase to use when decoding the servers private key
  """
  def key_passphrase(:eth0) do
    "weak_password"
  end

  @doc """
  Is interface enabled?

  This is an extension hook to allow individual SSH interfaces to be enabled/disabled at runtime
  """
  def enable?(:eth0) do
    true
  end
end
