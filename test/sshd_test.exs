defmodule SshdTest do
  use ExUnit.Case
  doctest Sshd

  test "greets the world" do
    assert Sshd.hello() == :world
  end
end
