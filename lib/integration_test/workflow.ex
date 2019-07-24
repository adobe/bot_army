defmodule BotArmy.IntegrationTest.Workflow do
  @moduledoc """
  A behaviour to implement when defining an integration test run.

  This behaviour allows defining multiple trees to run in parallel, as well as a 
  "pre" and "post" tree.

  For example, a "pre" tree might check the server health and obtain a log in token 
  to store in `BotArmy.SharedData`.  Then multiple trees could use the same token to 
  run various tests in parallel.  Finally, a "post" tree could do a final check or 
  cleanup.

  Note that each parallel tree will be run by a new bot instance.  Keep race 
  conditions in mind if your tests make use of the same resource.  If any tree fails 
  (including the pre and post trees), the entire run will fail.  The post tree will 
  always run, even if prior trees fail

  You can define each stage directly by implementing the callbacks, or you can use 
  the supplied macros.

      defmodule MyWorkflow do
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

  """

  alias BehaviorTree.Node

  defmodule ExistingPreError do
    defexception [:message]
  end

  defmodule ExistingPostError do
    defexception [:message]
  end

  defmodule ExistingParallelError do
    defexception [:message]
  end

  defmodule DuplicateParallelTestNameError do
    defexception [:message]
  end

  @doc """
  Optional.  A tree to run before doing anything else in this run.

  This is useful for set up or testing preconditions.
  """
  @callback pre() :: Node.t()

  @doc """
  Required.  A map of trees which will each be run in parallel with their own bot.  
  The key is used for reporting.
  """
  @callback parallel() :: %{required(any()) => Node.t()}

  @doc """
  Optional.  A tree to run after all other trees in this run have completed, or if 
  any tree fails.

  This is useful for tear down or testing postconditions.
  """
  @callback post() :: Node.t()

  defmacro __using__(_) do
    quote do
      @before_compile BotArmy.IntegrationTest.Workflow

      import BotArmy.IntegrationTest.Workflow, only: [pre: 1, post: 1, parallel: 2]

      Module.register_attribute(__MODULE__, :parallel_tests, accumulate: true)

      @behaviour BotArmy.IntegrationTest.Workflow
      def bot_army_workflow?, do: true

      @impl BotArmy.IntegrationTest.Workflow
      def pre,
        do:
          Node.always_succeed(
            BotArmy.Actions.action(BotArmy.Actions, :log, ["No pre step defined."])
          )

      @impl BotArmy.IntegrationTest.Workflow
      def post,
        do:
          Node.always_succeed(
            BotArmy.Actions.action(BotArmy.Actions, :log, ["No post step defined."])
          )

      defoverridable BotArmy.IntegrationTest.Workflow
    end
  end

  @doc """
  A simple way to define your "pre" test.

      pre setup_tree

  This is optional, and may only be defined once.
  """
  defmacro pre(node) do
    quote do
      if Module.defines?(__MODULE__, {:pre, 0}) do
        raise ExistingPreError, "pre is already defined"
      else
        def pre, do: unquote(node)
      end
    end
  end

  @doc """
  A simple way to define your "post" test.

      post clean_up_tree

  This is optional, and may only be defined once.
  """
  defmacro post(node) do
    quote do
      if Module.defines?(__MODULE__, {:post, 0}) do
        raise ExistingPostError, "post is already defined"
      else
        def post, do: unquote(node)
      end
    end
  end

  @doc """
  A simple way to define each test you want to run in parallel.  Add as many of these 
  as you want in your workflow module.

  You can specify a name and node, or use do syntax if you need to run other code to 
  set up the tree.

      parallel "test xyz", xyz_test_node

      parallel "test abc" do
        n = :rand.uniform()
        abc_test_node(n)
      end


  You must have at least one of these, and all test names must be unique.
  """
  defmacro parallel(name, contents) do
    contents =
      case contents do
        [do: block] ->
          quote do
            unquote(block)
          end

        _ ->
          quote do
            unquote(contents)
          end
      end

    quote do
      cond do
        Module.defines?(__MODULE__, {:parallel, 0}) ->
          raise ExistingParallelError, "parallel is already defined"

        __MODULE__
        |> Module.get_attribute(:parallel_tests)
        |> Keyword.keys()
        |> Enum.member?(unquote(name)) ->
          raise DuplicateParallelTestNameError, ~s("#{unquote(name)}" is already defined)

        :else ->
          Module.put_attribute(__MODULE__, :parallel_tests, {unquote(name), unquote(contents)})
      end
    end
  end

  @doc false
  defmacro __before_compile__(_) do
    quote do
      unless Module.defines?(__MODULE__, {:parallel, 0}) do
        @impl BotArmy.IntegrationTest.Workflow
        def parallel do
          Enum.reduce(@parallel_tests, %{}, fn {name, node}, acc ->
            Map.put(acc, name, node)
          end)
        end
      end
    end
  end
end
