# Copyright 2020 Adobe
# All Rights Reserved.

# NOTICE: Adobe permits you to use, modify, and distribute this file in
# accordance with the terms of the Adobe license agreement accompanying
# it. If you have received this file from a source other than Adobe,
# then your use, modification, or distribution of it requires the prior
# written permission of Adobe.

defmodule BotArmy do
  @moduledoc false
  use Application

  alias BotArmy.{Router, EtsMetrics, LoadTest, SharedData}

  def start(_types, _args) do
    children = [
      # Note, the LoadTest monitors all the bots, so if the BotSupervisor crashes, it 
      # will update accordingly
      SharedData,
      LoadTest,
      {DynamicSupervisor, strategy: :one_for_one, name: BotSupervisor},
      EtsMetrics,
      Plug.Cowboy.child_spec(scheme: :http, plug: Router, options: [port: 8124])
    ]

    Supervisor.start_link(children, strategy: :rest_for_one)
  end
end
