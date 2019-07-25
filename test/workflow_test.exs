defmodule BotArmy.IntegrationTest.WorkflowTest do
  use ExUnit.Case

  import BotArmy.Actions, only: [action: 3]
  alias BotArmy.{Actions, IntegrationTest.Workflow}
  alias BehaviorTree.Node

  defmodule TestWorkflow do
    use Workflow

    pre Node.always_succeed(action(Actions, :log, ["pre"]))

    post Node.always_succeed(action(Actions, :log, ["post"]))

    parallel "test 1", Node.always_succeed(action(Actions, :log, ["first parallel"]))

    parallel "test 2", Node.always_succeed(action(Actions, :wait, [0]))

    # do syntax variant
    parallel "test 3" do
      var = "runtime"

      Node.sequence([
        action(Actions, :log, [var]),
        action(Actions, :wait, [0])
      ])
    end
  end

  test "using `pre` macro creates the `pre` callback" do
    assert(TestWorkflow.pre() == Node.always_succeed(action(Actions, :log, ["pre"])))
  end

  test "using `post` macro creates the `post` callback" do
    assert TestWorkflow.post() == Node.always_succeed(action(Actions, :log, ["post"]))
  end

  test "prevents using more than one pre" do
    assert_raise BotArmy.IntegrationTest.Workflow.ExistingPreError, fn ->
      defmodule DoublePre do
        use Workflow
        pre Node.always_succeed(action(Actions, :log, ["pre"]))
        pre Node.always_succeed(action(Actions, :log, ["pre"]))
      end
    end
  end

  test "prevents using more than one post" do
    assert_raise BotArmy.IntegrationTest.Workflow.ExistingPostError, fn ->
      defmodule DoublePost do
        use Workflow

        post Node.always_succeed(action(Actions, :log, ["post"]))
        post Node.always_succeed(action(Actions, :log, ["post"]))
      end
    end
  end

  test "using `parallel` macro builds up the `parallel` callback" do
    assert TestWorkflow.parallel() ==
             %{
               "test 1" => Node.always_succeed(action(Actions, :log, ["first parallel"])),
               "test 2" => Node.always_succeed(action(Actions, :wait, [0])),
               "test 3" =>
                 Node.sequence([
                   action(Actions, :log, ["runtime"]),
                   action(Actions, :wait, [0])
                 ])
             }
  end

  test "using macros with external functions" do
    defmodule ExternalFunction do
      use Workflow

      parallel "using external", Node.always_succeed(log("ok"))

      parallel "other" do
        x = "other"
        Node.always_succeed(log(x))
      end

      def log(x) do
        action(Actions, :log, [x])
      end
    end

    assert ExternalFunction.parallel() ==
             %{
               "using external" => Node.always_succeed(action(Actions, :log, ["ok"])),
               "other" => Node.always_succeed(action(Actions, :log, ["other"]))
             }
  end

  test "prevents adding parallel tests when `def parallel` already exists" do
    assert_raise BotArmy.IntegrationTest.Workflow.ExistingParallelError, fn ->
      defmodule ParallelAlreadyDefined do
        use Workflow

        @impl BotArmy.IntegrationTest.Workflow
        def parallel, do: %{"test 1" => action(Actions, :wait, [0])}

        parallel "too late", Node.always_succeed(action(Actions, :log, ["should error"]))
      end
    end
  end

  test "defining parallel directly still works" do
    defmodule DefParallel do
      use Workflow

      @impl BotArmy.IntegrationTest.Workflow
      def parallel, do: %{"test 1" => Node.always_succeed(action(Actions, :wait, [0]))}
    end

    assert DefParallel.parallel() ==
             %{
               "test 1" => Node.always_succeed(action(Actions, :wait, [0]))
             }
  end

  test "parallel prevents using the same name" do
    assert_raise BotArmy.IntegrationTest.Workflow.DuplicateParallelTestNameError,
                 ~s("test 1" is already defined),
                 fn ->
                   defmodule SameName do
                     use Workflow

                     parallel "test 1", Node.always_succeed(action(Actions, :log, ["ok"]))

                     parallel "test 1",
                              Node.always_succeed(action(Actions, :log, ["not ok, same name"]))
                   end
                 end
  end

  test "errors if no parallel tests defined" do
    assert_raise BotArmy.IntegrationTest.Workflow.NoParallelTestsDefinedError, fn ->
      defmodule NoParallel do
        use Workflow
      end
    end
  end
end
