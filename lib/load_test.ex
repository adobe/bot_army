defmodule BotArmy.LoadTest do
  @moduledoc """
  Manages a load test run.

  Don't use this directly, call from `mix bots.load_test`.  See the documentation for the 
  available params.

  This will start up the target number of bots.  If bots die off, this will restart 
  them in batches to return to the target number.

  Bots run until calling `stop`.
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
  Starts up the bots.

  Opts map:

  * `n` - [optional] the number of bots to start up (defaults to 1)
  * `tree` - [required] the behavior tree for the bots to use
  * `bot` - [optional] a custom callback module implementing `BotArmy.Bot`, otherwise 
  uses `BotArmy.Bot.Default`

  Note that you cannot call this if bots are already running (call `BotArmy.LoadTest.stop` 
  first).

  """
  def run(%{tree: %BehaviorTree.Node{}, bot: _} = opts),
    do: GenServer.cast(__MODULE__, {:run, opts})

  @doc """
  Run just one bot and stop when finished.  Useful for testing a bot out, or running 
  a bot as a "task."

  Opts map:

  * `tree` - [required] the tree defining the work to be done.
  * `bot` - [optional] a custom callback module implementing `BotArmy.Bot`, otherwise 
  uses `BotArmy.Bot.Default`

  This wraps the provided tree so that it either errors if it fails, or performs 
  `BotArmy.Actions.done` if it succeeds.  This  guarantees the tree won't run more 
  than once (unless you intentionally create a loop using one of the `repeat` nodes).

  """
  def one_off(%{tree: %BehaviorTree.Node{}} = opts),
    do: GenServer.cast(__MODULE__, {:one_off, opts})

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
       bot: nil
     }}
  end

  def handle_cast({:run, _opts}, %{bot_count: bot_count} = state) when bot_count > 0 do
    IO.puts("Warning, you must stop the run first, before trying to start new bots")
    {:noreply, state}
  end

  def handle_cast({:run, opts}, state) do
    tree = Map.get(opts, :tree) || raise "No tree supplied"
    bot = Map.get(opts, :bot, BotArmy.Bot.Default)
    target_count = Map.get(opts, :n) || @default_bot_count

    Logger.warn("Starting up #{target_count} bots...")

    Metrics.run(target_count)

    Enum.each(
      1..target_count,
      fn i ->
        {:ok, bot_pid} = start_bot(state.last_id + i, bot)

        Process.monitor(bot_pid)
        Bot.run(bot_pid, tree)

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
    IO.puts("Warning, a bot is currently running, you must stop the run first, then try again")

    {:noreply, state}
  end

  def handle_cast({:one_off, opts}, state) do
    Logger.warn("Starting a new one-off run")

    tree = Map.get(opts, :tree) || raise "No tree supplied"
    bot = Map.get(opts, :bot, BotArm.Bot.Default)

    tree_with_done =
      BehaviorTree.Node.sequence([
        BehaviorTree.Node.select([
          tree,
          Actions.action(Actions, :error, ["Error: tree exited with `:fail`"])
        ]),
        Actions.action(Actions, :done)
      ])

    {:ok, bot_pid} = start_bot(:one_off, bot)
    Process.monitor(bot_pid)
    Bot.run(bot_pid, tree_with_done)

    new_state = %{
      state
      | bot_count: 1,
        start_time: System.monotonic_time(:millisecond),
        tree: tree,
        bot: bot
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

          Process.monitor(bot_pid)
          Bot.run(bot_pid, state.tree)
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
    Logger.warn("Bot finished work.", bot_count: state.bot_count - 1)

    if state.bot_count - 1 == 0,
      do:
        Logger.warn(
          "All bots have finished",
          uptime:
            (System.monotonic_time(:millisecond) - state.start_time)
            |> Timex.Duration.from_milliseconds()
            |> Timex.format_duration(:humanized)
        )

    {:noreply, %{state | bot_count: state.bot_count - 1}}
  end

  def handle_info({:DOWN, _ref, :process, _object, reason}, state) do
    Logger.error("Bot died!", error: inspect(reason), bot_count: state.bot_count - 1)

    {:noreply, %{state | bot_count: state.bot_count - 1}}
  end

  defp start_bot(id, bot_callback_module) do
    DynamicSupervisor.start_child(
      BotSupervisor,
      {bot_callback_module, [id: id]}
    )
  end
end
