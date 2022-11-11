defmodule Challenge.NodeTest do
  use ExUnit.Case, async: true

  alias Challenge.Node

  test "build_and_connect/2" do
    assert Node.build_and_connect(3, "example.com") == %Node{
             name: {Challenge.Server, :"3@example.com"},
             seniority: 3,
             connected: :ignored
           }
  end
end
