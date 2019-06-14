defmodule BotArmy.BotManagerTest do
  use ExUnit.Case

  @moduletag :slow

  import BotArmy.Actions, only: [action: 3, action: 2]
  alias BotArmy.Bot
  alias BotArmy.BotManager
  alias BotArmy.Actions
  alias BehaviorTree.Node

  describe "integration_test/1" do
    test "calls callback with result" do
      test_pid = self()

      BotManager.integration_test(%{
        id: "pass",
        tree:
          Node.sequence([
            action(Actions, :wait, [0])
          ]),
        callback: fn res ->
          send(test_pid, res)
        end
      })

      # note the bot takes 500ms between each tick
      assert_receive :ok, 2000

      BotManager.integration_test(%{
        id: "fail",
        tree:
          Node.sequence([
            action(Actions, :wait, [0]),
            action(Actions, :error, [:oops])
          ]),
        callback: fn res ->
          send(test_pid, res)
        end
      })

      assert_receive {:error, :oops}, 2000
    end
  end
end
