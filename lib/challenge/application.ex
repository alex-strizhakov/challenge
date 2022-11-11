defmodule Challenge.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Challenge.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  defp children do
    env = Application.get_env(:challenge, :env)

    if env != :test do
      name = Node.self()
      [seniority, host] = name |> to_string() |> String.split("@")
      seniority = String.to_integer(seniority)
      max_nodes = Application.get_env(:challenge, :max_nodes)
      max_pings = Application.get_env(:challenge, :max_pings)

      nodes = for i <- 1..max_nodes, seniority != i, do: Challenge.Node.build_and_connect(i, host)
      timeout = Application.get_env(:challenge, :timeout)
      election_start = Application.get_env(:challenge, :election_start)

      opts = [
        timeout: timeout,
        seniority: seniority,
        name: {Challenge.Server, name},
        nodes: nodes,
        max_nodes: max_nodes,
        max_pings: max_pings,
        election_start: election_start,
        leader: nil
      ]

      [
        {Challenge.Server, opts}
      ]
    else
      []
    end
  end
end
