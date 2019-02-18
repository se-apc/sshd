defmodule SshdExample.Shell do
  @doc """
  Run do an interactive shell using IO.puts/IO.gets.  Do nothing by default
  """
  def shell(_user, _peer) do
    IO.puts("Interactive Login Example")
    input = IO.read(:line)
    IO.puts "You typed '#{input}''"
    IO.puts("Goodbye")
  end

  @doc """
  Execute a single command
  """
  def exec(cmd, user, _peer) do
    IO.puts("Command Execution Example")
    IO.puts("You asked to run '#{cmd}' as user #{user}")
    IO.puts("Goodbye")
  end
end
