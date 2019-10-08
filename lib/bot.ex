defmodule BotArmy.Bot do
  @moduledoc """
  A "live" bot that can perform actions described by a behavior tree
  (`BehaviorTree.Node`).

  Bots are just GenServers that continuously tick through the provided behavior tree
  until they die or get an outcome of `:done`.

  Each bot has a "bag of state" called the "context" (sometimes called a "blackboard"
  in behaviour tree terminology), which is used to pass values between actions.

  Bots ingest actions (the leaf nodes of the tree) in the form of MFA tuples.  The
  function will be called with the current context and any provided arguments. The
  function must return an outcome, and may also return key-value pairs to
  store/update in the context.

  See the [README](readme.html#behavior-what) for an example.

  Accepted outcomes are: `:succeed`, `:fail`, `:continue`, `:done` or `{:error,
  reason}`.
  `:succeed`, `:fail` and `:continue` can also be in the form of `{:succeed, key:
  "value"}` if you want save/update the context.

  `:succeed` and `:fail` will advance the tree via `BehaviorTree`, while `:continue`
  will leave the tree as it is for the next tick (this can be useful for example for
  attempting an action multiple times with a sleep and a "max tries" counter in the
  context). `:done` stops the bot process successfully, and `{:error, reason}` kills
  the bot process with the provided reason.

  Note the following keys are reserved, and should not be overwritten: `id`, `bt`,
  `start_time`


  Extending the Bot
  -----------------

  You can use Bot exactly as it is.  However, if you need to add additional
  functionality to your bots, you can do so.

  `BotArmy.Bot` is actually a behaviour that you can use (`use BotArmy.Bot`) in a
  custom callback module.  It has a couple of callbacks for config, logging, and
  lifecycle hooks (TODO).  Since Bot itself uses a GenServer, you can also add
  GenServer callbacks, such as `init`, or `handle_[call|cast|info]`
  (`format_status/2` is particularly useful).

  For example, you may have a syncing system over websockets that updates the state
  in the bot's context.  By extending Bot with some additional handlers, you can add
  this functionality.

  The aforementioned "context" is just the GenServer's state, so your Actions will
  have access to everything there.  You can set up initial state in `init/1`, and
  modify it in your handlers as necessary.  If you implement `init/1`, the argument
  will be the starting state, so you can merge your state into that, but must return
  it.  Again, please be mindful not to overwrite the following keys in the state:
  `id`, `bt`, `start_time`.

  IMPORTANT - if you do extend Bot, you must set the `bot` param when starting a run
  (see the docs in the mix tasks).

  """

  @doc """
  Implement this callback if you want a custom way to log action outcomes.
  Defaults to a call to `Logger.info` with nice meta data.
  """
  @callback log_action_outcome(
              action_mfa :: {module, atom, list(any)},
              duration :: integer,
              outcome :: atom
            ) :: any

  require Logger
  alias BehaviorTree, as: BT

  defmacro __using__(_) do
    quote do
      @behaviour BotArmy.Bot

      alias BehaviorTree, as: BT
      require Logger
      use GenServer, restart: :temporary

      def start_link(opts \\ []), do: BotArmy.Bot.start_link(__MODULE__, opts)

      @impl BotArmy.Bot
      def log_action_outcome(action_mfa, duration, outcome),
        do: BotArmy.Bot.log_action_outcome(action_mfa, duration, outcome)

      @impl GenServer
      def init(args), do: {:ok, args}

      @impl GenServer
      def handle_call({:run, _}, _from, %{bt: _} = state),
        do: {:reply, {:error, :already_running}, state}

      @impl GenServer
      def handle_call({:run, tree}, _from, state) do
        # we inspect the exit reasons for better logging
        Process.flag(:trap_exit, true)

        Logger.metadata(bot_id: state.id, bot_pid: self())

        send(self(), :tick)

        # TODO maybe include a pre-run hook?
        {:reply, :ok, Map.put(state, :bt, BT.start(tree))}
      end

      @impl GenServer
      def handle_info(:tick, %{bt: _} = state) do
        BotArmy.Bot.tick(__MODULE__, state)
      end

      @impl GenServer
      def format_status(_, [_, state]) do
        # the behavior tree is so noisy, so remove it from logging if the bot dies
        "Bot state elided.  Overwrite `format_status/2` in a custom `Bot` to change."
      end

      @impl GenServer
      def terminate(:normal, state) do
        # TODO maybe callback modules will want to override this?  They could, but
        # would lose the logging.  Maybe we add another callback for clean_up/logging
        # side effects?
        # need to convert :normal to :shutdown to kill off linked processes (like the
        # socketApi)
        {:stop, :shutdown, state}
      end

      @impl GenServer
      def terminate(reason, state) do
        BotArmy.Bot.handle_error(reason, state)
      end

      defoverridable init: 1, log_action_outcome: 3, format_status: 2
    end
  end

  @doc """
  Start up a new bot using the supplied bot implementation.

  Takes a keyword list of options that will be passed to the GenServer.  The
  following keys are also used:

  * `:id` - [required] an identifier for this specific bot, used for logging
  purposes.

  """
  def start_link(bot_callback_module, opts \\ []) do
    id = Keyword.get(opts, :id) || raise "You must specify a unique `id` for this bot"

    state = %{
      id: id,
      start_time: System.monotonic_time(:millisecond)
    }

    Logger.info("A new baby bot is born")
    GenServer.start_link(bot_callback_module, state, opts)
  end

  @doc """
  Instruct the bot to run the supplied behavior tree.

  Note, the bot will repeatedly loop through the tree unless you include an action
  that returns `:done`, at which point it will die.

  Returns an error tuple if called on a bot that is already running.

  """
  def run(pid, tree) do
    GenServer.call(pid, {:run, tree})
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def tick(callback_mod, %{bt: bt} = state) do
    # TODO make a `pre_tick` optional_callback for side effects?  Maybe `post_tick`
    # with result?

    action_mfa = BT.value(bt)
    {action_module, action_fun_atom, args} = action_mfa

    start_time = System.monotonic_time(:millisecond)
    result = apply(action_module, action_fun_atom, [state | args])
    duration = System.monotonic_time(:millisecond) - start_time

    outcome =
      case result do
        {v, _} -> v
        v -> v
      end

    callback_mod.log_action_outcome(action_mfa, duration, outcome)
    send(BotArmy.Metrics, {:action, action_module, action_fun_atom, duration, outcome})

    case result do
      :succeed ->
        send(self(), :tick)
        {:noreply, %{state | bt: BT.succeed(bt)}}

      :fail ->
        send(self(), :tick)
        {:noreply, %{state | bt: BT.fail(bt)}}

      :continue ->
        send(self(), :tick)
        {:noreply, state}

      {:succeed, updates} ->
        send(self(), :tick)
        new_state = Enum.into(updates, state)
        {:noreply, %{new_state | bt: BT.succeed(bt)}}

      {:fail, updates} ->
        send(self(), :tick)
        new_state = Enum.into(updates, state)
        {:noreply, %{new_state | bt: BT.fail(bt)}}

      {:continue, updates} ->
        send(self(), :tick)
        new_state = Enum.into(updates, state)
        {:noreply, new_state}

      :done ->
        duration = System.monotonic_time(:millisecond) - state.start_time

        Logger.info(
          "Bot finished work",
          bot_id: state.id,
          uptime:
            duration
            |> Timex.Duration.from_milliseconds()
            |> Timex.format_duration(:humanized)
        )

        {:stop, :shutdown, state}

      {:error, reason} ->
        BotArmy.Bot.handle_error({:error, reason}, state)
    end
  end

  @doc false
  def log_action_outcome({action_module, action_fun_atom, _args}, duration, outcome) do
    Logger.info(
      "",
      action:
        "#{inspect(action_module)}.#{action_fun_atom |> to_string |> String.trim_leading(":")}",
      duration: duration,
      outcome: outcome
    )
  end

  @doc false
  def handle_error(:shutdown, state) do
    {:stop, :shutdown, state}
  end

  @doc false
  def handle_error(error, state) do
    duration = System.monotonic_time(:millisecond) - state.start_time
    {action_module, action_fun_atom, _args} = BT.value(state.bt)

    Logger.error(
      "",
      bot_id: state.id,
      bot_pid: self(),
      outcome: :error,
      action:
        "#{inspect(action_module)}.#{action_fun_atom |> to_string |> String.trim_leading(":")}",
      uptime:
        duration
        |> Timex.Duration.from_milliseconds()
        |> Timex.format_duration(:humanized)
    )

    {:stop, error, state}
  end
end

defmodule BotArmy.Bot.Default do
  @moduledoc """
  The standard bot, implementing the BotArmy.Bot behaviour, without any additional
  functionality or configuration.
  """
  use BotArmy.Bot

  def handle_info(unhandled_message, state) do
    Logger.warn("unhandled message in bot: #{inspect(unhandled_message)}")
    {:noreply, state}
  end
end
