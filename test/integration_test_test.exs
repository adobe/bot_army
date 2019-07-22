defmodule BotArmy.IntegrationTestTest do
  use ExUnit.Case

  import BotArmy.Actions, only: [action: 3]
  alias BotArmy.{IntegrationTest, Actions, IntegrationTest.Workflow}
  alias BehaviorTree.Node

  defmodule TestWorkflowSucceed do
    use Workflow
    def parallel, do: %{"test 1" => Node.always_succeed(action(Actions, :wait, [0]))}
  end

  defmodule TestWorkflowFail do
    use Workflow

    def parallel,
      do: %{
        "test 1" => action(Actions, :error, [:manual_error]),
        "test 2" => Node.always_succeed(action(Actions, :wait, [0])),
        "test 3" => Node.always_fail(action(Actions, :wait, [0]))
      }
  end

  test "only one run at a time allowed" do
    test_pid = self()

    :ok =
      IntegrationTest.run(%{
        id: "pass",
        workflow: TestWorkflowSucceed,
        callback: fn res ->
          send(test_pid, res)
        end
      })

    assert {:error, :already_running} =
             IntegrationTest.run(%{
               id: "pass",
               workflow: TestWorkflowSucceed,
               callback: fn res ->
                 send(test_pid, res)
               end
             })

    # need to wait for the first run to finish
    assert_receive :passed
  end

  describe "calls callback with result" do
    test "for success" do
      test_pid = self()

      :ok =
        IntegrationTest.run(%{
          id: "pass",
          workflow: TestWorkflowSucceed,
          callback: fn res ->
            send(test_pid, res)
          end
        })

      assert_receive :passed
    end

    test "for failure" do
      test_pid = self()

      :ok =
        IntegrationTest.run(%{
          id: "fail",
          workflow: TestWorkflowFail,
          callback: fn res ->
            send(test_pid, res)
          end
        })

      failures = [
        {"test 1", {:error, :manual_error}},
        {"test 3", {:error, :tree_outcome_failed}}
      ]

      assert_receive {:failed, ^failures}
      # need to give IntegrationTest time to get restarted
      Process.sleep(10)
    end

    test "for runtime errors in actions" do
      defmodule TestWorkflowRuntimeError do
        use Workflow
        def parallel, do: %{"test 1" => action(Actions, :does_not_exist, [0])}
      end

      test_pid = self()

      :ok =
        IntegrationTest.run(%{
          id: "fail",
          workflow: TestWorkflowRuntimeError,
          callback: fn res ->
            send(test_pid, res)
          end
        })

      # not sure why, but runtime failures in actions take longer to catch than 100ms
      assert_receive {:failed, [{"test 1", {:undef, _}}]}, 300
      # need to give IntegrationTest time to get restarted
      Process.sleep(10)
    end
  end

  test "failed pre run fails tests" do
    defmodule TestWorkflowPreFail do
      use Workflow
      def pre, do: Node.always_fail(action(Actions, :wait, [0]))
      def parallel, do: %{"test 1" => Node.always_succeed(action(Actions, :wait, [0]))}
    end

    test_pid = self()

    :ok =
      IntegrationTest.run(%{
        id: "pre-fail",
        workflow: TestWorkflowPreFail,
        callback: fn res ->
          send(test_pid, res)
        end
      })

    assert_receive {:failed, [{"pre", _}]}
  end

  test "failed post run fails tests" do
    defmodule TestWorkflowPostFail do
      use Workflow
      def parallel, do: %{"test 1" => Node.always_succeed(action(Actions, :wait, [0]))}
      def post, do: Node.always_fail(action(Actions, :wait, [0]))
    end

    test_pid = self()

    :ok =
      IntegrationTest.run(%{
        id: "pre_fail",
        workflow: TestWorkflowPostFail,
        callback: fn res ->
          send(test_pid, res)
        end
      })

    assert_receive {:failed, [{"post", _}]}
  end

  describe "concurrent run cases" do
    test "both pass = test passes" do
      defmodule TestWorkflowBothPass do
        use Workflow

        def parallel,
          do: %{
            "test 1" => Node.always_succeed(action(Actions, :wait, [0])),
            "test 2" => Node.always_succeed(action(Actions, :wait, [0]))
          }
      end

      test_pid = self()

      :ok =
        IntegrationTest.run(%{
          id: "both_pass",
          workflow: TestWorkflowBothPass,
          callback: fn res ->
            send(test_pid, res)
          end
        })

      assert_receive :passed
    end

    test "one fails fast = test fails" do
      defmodule TestWorkflowFastFail do
        use Workflow

        def parallel,
          do: %{
            "test 1" => Node.always_succeed(action(Actions, :wait, [10 / 1000])),
            "test 2" => Node.always_fail(action(Actions, :wait, [0]))
          }
      end

      test_pid = self()

      :ok =
        IntegrationTest.run(%{
          id: "fast_fail",
          workflow: TestWorkflowFastFail,
          callback: fn res ->
            send(test_pid, res)
          end
        })

      assert_receive {:failed, [{"test 2", _}]}
    end

    test "one fails slow = test fails" do
      defmodule TestWorkflowSlowFail do
        use Workflow

        def parallel,
          do: %{
            "test 1" => Node.always_fail(action(Actions, :wait, [10 / 1000])),
            "test 2" => Node.always_succeed(action(Actions, :wait, [0]))
          }
      end

      test_pid = self()

      :ok =
        IntegrationTest.run(%{
          id: "slow_fail",
          workflow: TestWorkflowSlowFail,
          callback: fn res ->
            send(test_pid, res)
          end
        })

      assert_receive {:failed, [{"test 1", _}]}
    end

    test "post runs after all test finish" do
      defmodule TestWorkflowMultipleSlow do
        use Workflow

        def parallel,
          do: %{
            "test 1" => Node.always_fail(action(Actions, :wait, [10 / 1000])),
            "test 2" => Node.always_fail(action(Actions, :wait, [20 / 1000])),
            "test 3" => Node.always_fail(action(Actions, :wait, [0]))
          }
      end

      test_pid = self()

      :ok =
        IntegrationTest.run(%{
          id: "all_finish",
          workflow: TestWorkflowMultipleSlow,
          callback: fn res ->
            send(test_pid, res)
          end
        })

      assert_receive {:failed,
                      [
                        {"test 1", _},
                        {"test 2", _},
                        {"test 3", _}
                      ]}
    end
  end
end
