defmodule Challenge.ServerTest do
  use ExUnit.Case, async: true

  alias Challenge.Node
  alias Challenge.Server

  defmodule ServerMock do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: opts[:name])
    end

    def init(opts) do
      {:ok, opts}
    end

    def handle_cast({msg, from}, opts) do
      send(opts[:test_pid], {msg, from, opts[:name]})
      {:noreply, opts}
    end
  end

  test "election is working" do
    nodes = [
      %Node{name: ServerMock1, seniority: 1},
      %Node{name: ServerMock2, seniority: 3}
    ]

    timeout = 100

    start_supervised!({Server, start_opts(nodes: nodes, name: Server1, mod_name: Server1)},
      restart: :temporary
    )

    start_supervised!({ServerMock, test_pid: self(), name: ServerMock1}, id: {ServerMock, 1})
    start_supervised!({ServerMock, test_pid: self(), name: ServerMock2}, id: {ServerMock, 2})

    assert_receive {:alive?, Server1, ServerMock2}

    GenServer.cast(Server1, {:finethanks, ServerMock2})

    Process.sleep(timeout)

    assert_receive {:alive?, Server1, ServerMock2}

    GenServer.cast(Server1, {:finethanks, ServerMock2})

    GenServer.cast(Server1, {:iamtheking, ServerMock2})

    state = :sys.get_state(Server1)
    assert state.leader == ServerMock2

    assert_receive {:ping, Server1, ServerMock2}, timeout + 10
    GenServer.cast(Server1, {:pong, ServerMock2})
    assert_receive {:ping, Server1, ServerMock2}, timeout + 10
    # assert_receive {:ping, Server1, ServerMock2}, timeout + 10
    # assert_receive {:ping, Server1, ServerMock2}, timeout + 10

    assert_receive {:alive?, Server1, ServerMock2}, timeout * 4 + 10
    Process.sleep(timeout)
    assert_receive {:iamtheking, Server1, ServerMock1}, timeout + 10
    assert_receive {:iamtheking, Server1, ServerMock2}, timeout + 10
    state = :sys.get_state(Server1)
    assert state.leader == Server1
  end

  test "response to alive message start new election" do
    nodes = [
      %Node{name: ServerMock3, seniority: 1},
      %Node{name: ServerMock4, seniority: 3}
    ]

    start_supervised!({Server, start_opts(nodes: nodes, mod_name: Server2, name: Server2)},
      restart: :temporary
    )

    start_supervised!({ServerMock, test_pid: self(), name: ServerMock3}, id: {ServerMock, 3})

    start_supervised!({ServerMock, test_pid: self(), name: ServerMock4}, id: {ServerMock, 4})

    assert_receive {:alive?, Server2, ServerMock4}
    GenServer.cast(Server2, {:finethanks, ServerMock4})

    GenServer.cast(Server2, {:iamtheking, ServerMock4})

    GenServer.cast(Server2, {:alive?, ServerMock4})

    assert_receive {:finethanks, Server2, ServerMock4}
    assert_receive {:alive?, Server2, ServerMock4}
  end

  test "response to alive message when seniority is max" do
    nodes = [
      %Node{name: ServerMock5, seniority: 1}
    ]

    start_supervised!(
      {Server, start_opts(nodes: nodes, max_nodes: 2, mod_name: Server3, name: Server3)},
      restart: :temporary
    )

    start_supervised!({ServerMock, test_pid: self(), name: ServerMock5}, id: {ServerMock, 5})

    Process.sleep(100)
    assert_receive {:iamtheking, Server3, ServerMock5}

    GenServer.cast(Server3, {:alive?, ServerMock5})

    assert_receive {:finethanks, Server3, ServerMock5}
    assert_receive {:iamtheking, Server3, ServerMock5}
  end

  defp start_opts(opts) do
    Keyword.merge(
      [election_start: 50, seniority: 2, max_nodes: 3, timeout: 100, leader: nil, max_pings: 3],
      opts
    )
  end
end
