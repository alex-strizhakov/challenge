defmodule Challenge.Server do
  use GenServer

  require Logger

  defmodule State do
    defstruct name: nil,
              leader: nil,
              pinged: false,
              timer: nil,
              opts: [],
              nodes: [],
              seniority: nil

    @type t :: %__MODULE__{
            name: atom | {atom, node},
            leader: atom | {atom, node},
            pinged: boolean,
            timer: reference,
            opts: keyword,
            nodes: list,
            seniority: pos_integer | nil
          }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:mod_name] || __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting new node #{inspect(opts[:name])}")

    {nodes, opts} = Keyword.pop!(opts, :nodes)
    {seniority, opts} = Keyword.pop!(opts, :seniority)
    {name, opts} = Keyword.pop!(opts, :name)
    Process.send_after(self(), :start_election, opts[:election_start])
    {:ok, %State{opts: opts, nodes: nodes, seniority: seniority, name: name}}
  end

  @impl true
  def handle_info(:start_election, state) do
    {:noreply, start_election(state)}
  end

  def handle_info(:check_election, state) do
    Logger.info("Checking election #{inspect(state.name)}")

    Process.cancel_timer(state.timer)

    {:noreply, start_leading(state)}
  end

  def handle_info(:check_leader, state) do
    Logger.info("Checking leader on #{inspect(state.name)}")
    {:noreply, start_election(state)}
  end

  def handle_info(:ping_leader, state) do
    state =
      if state.leader != state.name do
        Logger.info("Ping #{inspect(state.leader)}")
        GenServer.cast(state.leader, {:ping, state.name})

        timer = Process.send_after(self(), :start_election, state.opts[:timeout] * 4)
        Map.put(state, :timer, timer)
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:iamtheking, from}, state) do
    Logger.info("Received iamtheking message from #{inspect(from)}. Changing leader")

    if state.timer do
      Process.cancel_timer(state.timer)
    end

    state = state |> start_pinging() |> Map.put(:leader, from)

    {:noreply, state}
  end

  def handle_cast({:alive?, from}, state) do
    Logger.info("Answering finethanks to #{inspect(from)}")
    GenServer.cast(from, {:finethanks, state.name})

    if state.timer do
      Process.cancel_timer(state.timer)
    end

    state =
      if state.seniority == state.opts[:max_nodes] do
        start_leading(state)
      else
        start_election(state)
      end

    {:noreply, state}
  end

  def handle_cast({:finethanks, from}, state) do
    Logger.info("Waiting for becoming the king message from #{inspect(from)}")

    if state.timer do
      Process.cancel_timer(state.timer)
    end

    timer =
      if is_nil(state.leader) do
        Process.send_after(self(), :check_leader, state.opts[:timeout])
      end

    state = Map.put(state, :timer, timer)
    {:noreply, state}
  end

  def handle_cast({:ping, from}, state) when state.leader == state.name do
    Logger.info("Ping from #{inspect(from)}")
    GenServer.cast(from, {:pong, state.name})
    {:noreply, state}
  end

  def handle_cast({:pong, from}, state) when state.leader == from do
    Logger.info("Pong from leader #{inspect(from)}")
    Process.cancel_timer(state.timer)
    {:noreply, start_pinging(state)}
  end

  def handle_cast(msg, state) do
    Logger.warn("Received unexpected message #{inspect(msg)}")
    {:noreply, state}
  end

  defp start_pinging(state) do
    timer = Process.send_after(self(), :ping_leader, state.opts[:timeout])
    Map.put(state, :timer, timer)
  end

  defp start_election(state) do
    Logger.info("Starting new election on #{inspect(state.name)}")

    state.nodes
    |> Enum.filter(fn node -> node.seniority > state.seniority end)
    |> Enum.each(fn node ->
      Logger.info("Is #{inspect(node.name)} alive?")
      GenServer.cast(node.name, {:alive?, state.name})
    end)

    timer = Process.send_after(self(), :check_election, state.opts[:timeout])
    %{state | timer: timer}
  end

  defp start_leading(state) do
    Logger.info("Starting sending messages that current node is leader. #{inspect(state.name)}")

    Enum.each(state.nodes, fn node ->
      Logger.info("I'm leader message from #{inspect(state.name)} to #{inspect(node.name)}")

      GenServer.cast(node.name, {:iamtheking, state.name})
    end)

    %{state | leader: state.name}
  end
end
