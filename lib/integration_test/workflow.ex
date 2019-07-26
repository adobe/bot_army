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

  defmodule NoParallelTestsDefinedError do
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

      import BotArmy.IntegrationTest.Workflow, only: [pre: 1, post: 1, parallel: 2, merge: 1]

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
  Merge multiple workfows together.

  Use in an empty "master run" workflow module.  Pass in a list of workflow module 
  names, and this will define `pre` as a `Node.sequence` of each merged workflows' 
  `pre`s, and the same for `post`.  It will also merge all `parallel` tests into one 
  `parallel` definition.

      defmodule MasterWorkflow do
        use Workflow
        merge([Workflow1, Workflow2])
      end

  """
  defmacro merge(workflows) do
    quote do
      @impl BotArmy.IntegrationTest.Workflow
      def pre do
        unquote(workflows)
        |> Enum.map(fn workflow ->
          apply(workflow, :pre, [])
        end)
        |> Node.sequence()
      end

      @impl BotArmy.IntegrationTest.Workflow
      def post do
        unquote(workflows)
        |> Enum.map(fn workflow ->
          apply(workflow, :post, [])
        end)
        |> Node.sequence()
      end

      @impl BotArmy.IntegrationTest.Workflow
      def parallel do
        Enum.reduce(unquote(workflows), %{}, fn workflow, acc ->
          Map.merge(apply(workflow, :parallel, []), acc, fn name, _, _ ->
            raise DuplicateParallelTestNameError,
                  "\"#{name}\" parallel test already exists in another workflow, please rename it"
          end)
        end)
      end
    end
  end

  @doc """
  A simple way to define your "pre" test.

      pre setup_tree

  This is optional, and may only be defined once.
  """
  defmacro pre(contents) do
    quote do
      if Module.defines?(__MODULE__, {:pre, 0}) do
        raise ExistingPreError, "pre is already defined"
      else
        def pre, do: unquote(contents)
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
        |> Enum.member?(unquote(:"#{name}")) ->
          raise DuplicateParallelTestNameError, ~s("#{unquote(name)}" is already defined)

        :else ->
          Module.put_attribute(__MODULE__, :parallel_tests, unquote(:"#{name}"))
          def unquote(:"#{name}")(), do: unquote(contents)
      end
    end
  end

  @doc false
  defmacro __before_compile__(_) do
    quote do
      unless Module.defines?(__MODULE__, {:parallel, 0}) do
        if Enum.empty?(@parallel_tests),
          do: raise(NoParallelTestsDefinedError, "you must define at least one parallel test")

        @impl BotArmy.IntegrationTest.Workflow
        def parallel do
          Enum.reduce(@parallel_tests, %{}, fn name, acc ->
            Map.put(acc, Atom.to_string(name), apply(__MODULE__, name, []))
          end)
        end
      end
    end
  end
end
