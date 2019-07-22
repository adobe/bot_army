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
  """

  alias BehaviorTree.Node

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
end
