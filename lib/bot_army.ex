defmodule BotArmy do
  @moduledoc false
  use Application

  alias BotArmy.{Router, Metrics, LoadTest, IntegrationTest, SharedData}

  def start(_types, _args) do
    children = [
      # Note, the LoadTest/IntegrationTest monitors all the bots, so if the 
      # BotSupervisor crashes, it will update accordingly
      SharedData,
      LoadTest,
      IntegrationTest,
      {DynamicSupervisor, strategy: :one_for_one, name: BotSupervisor},
      Metrics,
      Plug.Cowboy.child_spec(scheme: :http, plug: Router, options: [port: 8124])
    ]

    Supervisor.start_link(children, strategy: :rest_for_one)
  end
end
