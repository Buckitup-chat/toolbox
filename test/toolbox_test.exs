defmodule ToolboxTest do
  use ExUnit.Case
  doctest Toolbox

  test "greets the world" do
    assert Toolbox.hello() == :world
  end
end
