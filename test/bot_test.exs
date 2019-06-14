defmodule BotArmy.BotTest do
  use ExUnit.Case

  import BotArmy.Actions, only: [action: 3]
  alias BotArmy.Actions
  alias BotArmy.Bot
  alias BehaviorTree.Node

  describe "handling errors" do
    test "dies with the proper reason" do
      tree =
        Node.sequence([
          action(Actions, :error, [:error_reason])
        ])

      {:ok, bot_pid} = Bot.Default.start_link(id: :test_bot)

      Process.flag(:trap_exit, true)
      ref = Process.monitor(bot_pid)

      :ok = Bot.run(bot_pid, tree)

      assert_receive {:DOWN, ^ref, :process, ^bot_pid, {:error, :error_reason}}, 500
    end
  end
end
