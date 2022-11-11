defmodule Challenge.Node do
  defstruct [:name, :seniority, :connected]

  @type t :: %__MODULE__{
          name: node,
          seniority: pos_integer,
          connected: boolean | :ignored
        }

  def build_and_connect(seniority, host) do
    name = :"#{seniority}@#{host}"

    %__MODULE__{
      name: {Challenge.Server, name},
      seniority: seniority,
      connected: Node.connect(name)
    }
  end
end
