defmodule BotArmy.BotManager do
  @moduledoc """
  Handles starting up the right number of bots and managing their lifecycle.

  Don't use this directly, use one of the provided mix tasks:

  * `mix bots.integration_test`      run the integration tests
  * `mix bots.run`                   Interactive loadtesting shell

  See the documentation for them for required params.

  """

  require Logger
  use GenServer
  alias BotArmy.{Bot, Metrics, Actions}

  @default_bot_count 1

  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, nil, Keyword.merge(opts, name: __MODULE__))

  def stop() do
    GenServer.stop(__MODULE__, :normal)
  end

  @doc """
  The way to start up bots.

  Opts map:

  * `n` - [optional] the number of bots to start up (defaults to 1)
  * `tree` - [required] the behavior tree for the bots to use
  * `bot` - [optional] a custom callback module implementing `BotArmy.Bot`, otherwise 
  uses `BotArmy.Bot.Default`

  Note that you cannot call this if bots are already running (call `BotManager.stop` 
  first).

  """
  def run(%{tree: %BehaviorTree.Node{}, bot: _} = opts),
    do: GenServer.cast(__MODULE__, {:run, opts})

  @doc """
  Run just one bot and stop when finished.  Useful for testing a bot out, or running 
  a bot as a "task."

  Opts map:

  * `tree` - [required] the behavior tree for the bots to use
  * `bot` - [optional] a custom callback module implementing `BotArmy.Bot`, otherwise 
  uses `BotArmy.Bot.Default`

  This wraps the provided tree so that it either errors if it fails, or performs 
  `BotArmy.Actions.done` if it succeeds.  This  guarantees the tree won't run more 
    than once (unless you intentionally create a loop using one of the `repeat` 
      nodes).

  """
  def one_off(%{tree: %BehaviorTree.Node{}} = opts),
    do: GenServer.cast(__MODULE__, {:one_off, opts})

  @doc """
  Allows the bots to be ran as an integration test, reporting the results.

  Opts map:

  * `tree` - [required] the behavior tree for the bots to use
  * `bot` - [optional] a custom callback module implementing `BotArmy.Bot`, otherwise 
  uses `BotArmy.Bot.Default`
  * `callback` - [required] a function that will be called with the result of the 
  test, which will either be `:ok` or `{:error, <reason>}`.

  The `tree` will be ran as a "one off".
  TODO run features in parallel

  """
  def integration_test(%{tree: %BehaviorTree.Node{}, callback: callback} = opts)
      when is_function(callback, 1),
      do:
        GenServer.cast(
          __MODULE__,
          {
            :one_off,
            opts
          }
        )

  def get_bot_count(), do: GenServer.call(__MODULE__, :get_bot_count)

  # ----------------Implementation------------------------

  def init(_state) do
    {:ok,
     %{
       bot_count: 0,
       target_bot_count: 0,
       last_id: 0,
       start_time: System.monotonic_time(:millisecond),
       tree: nil,
       bot: nil,
       integration_callback: nil
     }}
  end

  def handle_cast({:run, _opts}, %{bot_count: bot_count} = state) when bot_count > 0 do
    IO.puts("Warning, you must stop the BotManager first, before trying to start new bots")
    {:noreply, state}
  end

  def handle_cast({:run, opts}, state) do
    tree = Map.get(opts, :tree) || raise "No tree supplied"
    bot = Map.get(opts, :bot)
    target_count = Map.get(opts, :n) || @default_bot_count

    Logger.warn("Starting up #{target_count} bots...")

    Metrics.run(target_count)

    Enum.each(
      1..target_count,
      fn i ->
        {:ok, bot_pid} = start_bot(state.last_id + i, bot)

        Bot.run(bot_pid, tree)
        Process.monitor(bot_pid)

        # "preflighting" the first bot seems to "warm up" httpoison and prevent time 
        # outs ¯\_(ツ)_/¯
        if i == 1, do: Process.sleep(1000)
      end
    )

    new_state = %{
      state
      | bot_count: target_count,
        target_bot_count: target_count,
        last_id: state.last_id + target_count,
        start_time: System.monotonic_time(:millisecond),
        tree: tree,
        bot: bot
    }

    # TODO this locks in the tree that `run` was called with (restarting dead bots 
    # will use this tree) - might be nice to have more flexability here

    :timer.send_interval(5000, :check_bot_population)

    {:noreply, new_state}
  end

  def handle_cast({:one_off, _opts}, %{bot_count: bot_count} = state) when bot_count > 0 do
    IO.puts(
      "Warning, a bot is currently running, you must stop the BotManager first, then try again"
    )

    {:noreply, state}
  end

  def handle_cast({:one_off, opts}, state) do
    Logger.warn("Starting a new one-off bot")

    tree = Map.get(opts, :tree) || raise "No tree supplied"
    bot = Map.get(opts, :bot)

    {:ok, bot_pid} = start_bot(:one_off, bot)

    tree_with_done =
      BehaviorTree.Node.sequence([
        BehaviorTree.Node.select([
          tree,
          Actions.action(Actions, :error, ["Error: tree exited with `:fail`"])
        ]),
        Actions.action(Actions, :done)
      ])

    Bot.run(bot_pid, tree_with_done)
    Process.monitor(bot_pid)

    new_state = %{
      state
      | bot_count: 1,
        start_time: System.monotonic_time(:millisecond),
        tree: tree,
        bot: bot,
        integration_callback: Map.get(opts, :callback)
    }

    {:noreply, new_state}
  end

  def handle_call(:get_bot_count, _from, state) do
    {:reply, state.bot_count, state}
  end

  def handle_info(:check_bot_population, state) do
    # credo:disable-for-next-line
    IO.inspect(
      state.bot_count,
      label: :bot_count
    )

    # credo:disable-for-next-line
    IO.inspect(
      (System.monotonic_time(:millisecond) - state.start_time)
      |> Timex.Duration.from_milliseconds()
      |> Timex.format_duration(:humanized)
    )

    Logger.info(
      "",
      bot_count: state.bot_count,
      uptime:
        (System.monotonic_time(:millisecond) - state.start_time)
        |> Timex.Duration.from_milliseconds()
        |> Timex.format_duration(:humanized)
    )

    if state.bot_count < state.target_bot_count do
      Logger.warn(
        "Bot population has waned, starting up more bots...",
        bot_count: state.bot_count
      )

      # add more bots in batches
      bots_to_start = min(50, state.target_bot_count - state.bot_count)

      Enum.each(
        1..bots_to_start,
        fn i ->
          {:ok, bot_pid} = start_bot(state.last_id + i, Map.get(state, :bot))

          Bot.run(bot_pid, state.tree)
          Process.monitor(bot_pid)
        end
      )

      new_state = %{
        state
        | bot_count: state.bot_count + bots_to_start,
          last_id: state.last_id + bots_to_start
      }

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, _object, :shutdown}, state) do
    Logger.info("Bot finished work.", bot_count: state.bot_count - 1)

    if state.bot_count - 1 == 0,
      do:
        Logger.warn(
          "All bots have finished",
          uptime:
            (System.monotonic_time(:millisecond) - state.start_time)
            |> Timex.Duration.from_milliseconds()
            |> Timex.format_duration(:humanized)
        )

    with callback when is_function(callback, 1) <- Map.get(state, :integration_callback),
         do: callback.(:ok)

    {:noreply, %{state | bot_count: state.bot_count - 1}}
  end

  def handle_info({:DOWN, _ref, :process, _object, {:error, reason} = error}, state) do
    Logger.error("Bot died due to error", error: reason, bot_count: state.bot_count - 1)

    with callback when is_function(callback, 1) <- Map.get(state, :integration_callback),
         do: callback.(error)

    {:noreply, %{state | bot_count: state.bot_count - 1}}
  end

  def handle_info({:DOWN, _ref, :process, _object, reason}, state) do
    Logger.error("Bot died unexpectedly!", bot_count: state.bot_count - 1)

    with callback when is_function(callback, 1) <- Map.get(state, :integration_callback),
         do: callback.({:error, reason})

    {:noreply, %{state | bot_count: state.bot_count - 1}}
  end

  defp start_bot(id, bot_callback_module) do
    bot_mod = bot_callback_module || Bot.Default

    DynamicSupervisor.start_child(
      BotSupervisor,
      {bot_mod, [id: id]}
    )
  end
end
