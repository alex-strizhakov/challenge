import Config

config :challenge,
  env: Mix.env(),
  max_nodes: 5,
  timeout: 500,
  election_start: 0

env_config = "#{config_env()}.exs"

if File.exists?(env_config), do: import_config(env_config)
