# ----  FSM States -----

defprotocol BotArmy.IntegrationTest.FSMState do
  @typedoc """
  Response from a state specifying which state to transition to (or to keep the current 
  state), and the response to send to the caller, and the new state.
  """
  @type transition_response ::
          {
            :next_fsm_state,
            fsm_state :: BotArmy.IntegrationTest.FSMState.t(),
            response :: term(),
            BotArmy.IntegrationTest.t()
          }
          | {:keep_fsm_state, response :: term(), BotArmy.IntegrationTest.t()}

  @doc "work to do upon entering a state"
  @spec on_enter(
          BotArmy.IntegrationTest.FSMState.t(),
          BotArmy.IntegrationTest.t()
        ) ::
          {:ok, BotArmy.IntegrationTest.t()}
          | {:error, reason :: term(), BotArmy.IntegrationTest.t()}
  def on_enter(fsm_state, state)

  @doc "start a new test run"
  @spec run(
          BotArmy.IntegrationTest.FSMState.t(),
          opts :: map(),
          BotArmy.IntegrationTest.t()
        ) ::
          transition_response
  def run(fsm_state, opts, state)

  @doc "test passed"
  @spec test_succeeded(
          BotArmy.IntegrationTest.FSMState.t(),
          test_succeeded :: reference(),
          BotArmy.IntegrationTest.t()
        ) ::
          transition_response
  def test_succeeded(fsm_state, test_ref, state)

  @doc "test failed"
  @spec test_failed(
          BotArmy.IntegrationTest.FSMState.t(),
          test_succeeded :: reference(),
          reason :: term(),
          BotArmy.IntegrationTest.t()
        ) ::
          transition_response
  def test_failed(fsm_state, test_ref, reason, state)
end

defmodule BotArmy.IntegrationTest.FSMState.Ready do
  @moduledoc false
  defstruct([])
end

defmodule BotArmy.IntegrationTest.FSMState.Pre do
  @moduledoc false
  defstruct([])
end

defmodule BotArmy.IntegrationTest.FSMState.Parallel do
  @moduledoc false
  defstruct([])
end

defmodule BotArmy.IntegrationTest.FSMState.Post do
  @moduledoc false
  defstruct([])
end

alias BotArmy.IntegrationTest.FSMState

# FSMState implementations are at bottom of file

# ---- Runner ----

defmodule BotArmy.IntegrationTest do
  @moduledoc """
  Manages an integration test run.

  Don't use this directly, call from `mix bots.integration_test`.  See the 
  documentation for the available params.

  This will run the "pre" tree first, then the "parallel" trees concurrently, then 
  the "post" tree.  The post tree will always run, even if prior trees fail.
  """

  defmodule BotMonitor do
    @moduledoc """
    watches the bots for the runner, reporting any succeeding or failing tests.
    """

    use GenServer
    require Logger

    def start_link(opts \\ []),
      do: GenServer.start_link(__MODULE__, nil, Keyword.merge(opts, name: __MODULE__))

    @doc """
    Pass a pid to monitor, returns the ref
    """
    def monitor(pid), do: GenServer.call(__MODULE__, {:monitor, pid})

    # ------

    def init(state), do: {:ok, state}

    def handle_call({:monitor, bot_pid}, _from, state) do
      ref = Process.monitor(bot_pid)
      {:reply, {:ok, ref}, state}
    end

    def handle_info({:DOWN, ref, :process, _object, :shutdown}, state) do
      BotArmy.IntegrationTest.test_succeeded(ref)
      {:noreply, state}
    end

    def handle_info({:DOWN, ref, :process, _object, reason}, state) do
      BotArmy.IntegrationTest.test_failed(ref, reason)
      {:noreply, state}
    end

    def handle_info(other, state) do
      Logger.error("unexpected message #{inspect(other)}")
      {:stop, :unexpected_message, state}
    end
  end

  use GenServer
  require Logger
  alias BotArmy.{Bot, Actions}

  defstruct [
    :current_fsm_state,
    :start_time,
    :workflow,
    :bot,
    :callback,
    :test_names,
    :test_status
  ]

  def start_link(opts \\ []),
    # starts in "ready" state
    do:
      GenServer.start_link(
        __MODULE__,
        %FSMState.Ready{},
        Keyword.merge(opts, name: __MODULE__)
      )

  def stop() do
    GenServer.stop(__MODULE__, :normal)
  end

  @doc """
  Starts the integration test.

  This supports parallel trees, and a pre and post step.

  Opts map:

  * `workflow` - [required] the module defining the work to be done.  Must implement 
  `BotArmy.IntegrationTest.Workflow`.
  * `bot` - [optional] a custom callback module implementing `BotArmy.Bot`, otherwise 
  uses `BotArmy.Bot.Default`
  * `callback` - [required] a function that will be called with the result of the 
  test, which will either be `:passed` or `{:failed, <failed tests>}` where "failed 
  tests" is a list of tuples with test keys and failure reasons.

  Returns `:ok` or `{:error, reason}`.
  """
  def run(%{workflow: workflow, callback: callback} = opts)
      when is_function(callback, 1) and is_atom(workflow),
      do: GenServer.call(__MODULE__, {:run, opts})

  @doc """
  Report montitored bots upon succeeding.
  """
  def test_succeeded(ref) do
    # NOTE we would prefer this (and the one for test_failed) to be `call`s instead 
    # of `cast`s, but that opens a potential dead lock if a bot finishes work before 
    # all of the bots have been started.  If this becomes a problem, consider 
    # separate monitor per bot, or monitor directly from the runner.
    GenServer.cast(__MODULE__, {:test_succeeded, ref})
  end

  @doc """
  Report montitored bots upon failing.
  """
  def test_failed(ref, reason) do
    GenServer.cast(__MODULE__, {:test_failed, ref, reason})
  end

  # ----------------Implementation------------------------

  def init(starting_state) do
    BotArmy.IntegrationTest.BotMonitor.start_link()

    {:ok, %__MODULE__{current_fsm_state: starting_state}}
  end

  # delegate run/test_succeeded/test_failed messages to current state

  def handle_info(:enter_state, %__MODULE__{current_fsm_state: current_fsm_state} = state) do
    current_fsm_state
    |> FSMState.on_enter(state)
    |> case do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, reason, new_state} ->
        {:stop, reason, new_state}
    end
  end

  defp handle_transition_response(response) do
    case response do
      {:next_fsm_state, next_fsm_state, response, new_state} ->
        send(self(), :enter_state)
        {:reply, response, %{new_state | current_fsm_state: next_fsm_state}}

      {:keep_fsm_state, response, new_state} ->
        {:reply, response, new_state}

      other ->
        Logger.error("Unexpected transition response: #{inspect(other)}")

        {:stop, {:unexpcted_transition_response, other},
         :state_dropped_from_unexpected_transition}
    end
  end

  def handle_cast(
        {:test_succeeded, ref},
        %__MODULE__{current_fsm_state: current_fsm_state} = state
      ) do
    current_fsm_state
    |> FSMState.test_succeeded(ref, state)
    |> handle_transition_response
    |> (fn {_, _, new_state} -> {:noreply, new_state} end).()
  end

  def handle_cast(
        {:test_failed, ref, reason},
        %__MODULE__{current_fsm_state: current_fsm_state} = state
      ) do
    current_fsm_state
    |> FSMState.test_failed(ref, reason, state)
    |> handle_transition_response
    |> (fn {_, _, new_state} -> {:noreply, new_state} end).()
  end

  def handle_call(
        {:run, opts},
        _from,
        %__MODULE__{current_fsm_state: current_fsm_state} = state
      ) do
    current_fsm_state
    |> FSMState.run(opts, state)
    |> handle_transition_response
  end

  def handle_call(other, _from, state) do
    Logger.error("Got unexpected call #{inspect(other)}")
    {:stop, other, state}
  end

  # helpers

  def start_bot(id, tree, bot_callback_module) do
    {:ok, bot_pid} =
      DynamicSupervisor.start_child(
        BotSupervisor,
        {bot_callback_module, [id: id]}
      )

    {:ok, ref} = BotArmy.IntegrationTest.BotMonitor.monitor(bot_pid)
    :ok = Bot.run(bot_pid, tree_with_done(tree))
    ref
  end

  def tree_with_done(tree),
    do:
      BehaviorTree.Node.sequence([
        BehaviorTree.Node.select([
          tree,
          Actions.action(Actions, :error, [:tree_outcome_failed])
        ]),
        Actions.action(Actions, :done)
      ])

  def add_test(key, tests), do: Map.put(tests, key, :running)
  def mark_test_passed(key, tests), do: Map.replace!(tests, key, :passed)
  def mark_test_failed(key, reason, tests), do: Map.replace!(tests, key, {:failed, reason})

  def tests_complete?(test_status),
    do: not Enum.any?(test_status, fn {_k, outcome} -> outcome === :running end)

  def run_passed?(test_status),
    do: Enum.all?(test_status, fn {_k, outcome} -> outcome === :passed end)

  def find_failed_tests(test_status),
    do:
      Enum.flat_map(test_status, fn {k, outcome} ->
        case outcome do
          {:failed, reason} -> [{k, reason}]
          _ -> []
        end
      end)
end

# ---- State implementations ----

# ---- Ready ----

defimpl FSMState, for: FSMState.Ready do
  import BotArmy.IntegrationTest
  require Logger

  def on_enter(_, state), do: {:ok, state}

  def run(_, opts, %BotArmy.IntegrationTest{} = state) do
    Logger.warn("Starting integration test...")

    new_state = %{
      state
      | start_time: System.monotonic_time(:millisecond),
        workflow: Map.get(opts, :workflow),
        bot: Map.get(opts, :bot, BotArmy.Bot.Default),
        callback: Map.get(opts, :callback),
        test_names: %{},
        test_status: %{}
    }

    {:next_fsm_state, %FSMState.Pre{}, :ok, new_state}
  end

  def test_succeeded(_, _test_ref, %BotArmy.IntegrationTest{} = state) do
    Logger.warn("Error, unexpected 'test_succeeded' message during Ready state")
    {:keep_fsm_state, :ok, state}
  end

  def test_failed(_, _test_ref, _reason, %BotArmy.IntegrationTest{} = state) do
    Logger.warn("Error, unexpected 'test_failed' message during Ready state")
    {:keep_fsm_state, :ok, state}
  end
end

# ---- Pre ----

defimpl FSMState, for: FSMState.Pre do
  import BotArmy.IntegrationTest
  require Logger

  def on_enter(_, state) do
    Logger.warn("Running pre tree..")

    start_bot("pre", state.workflow.pre(), state.bot)

    {:ok, %{state | test_status: add_test("pre", state.test_status)}}
  end

  def run(_, _opts, %BotArmy.IntegrationTest{} = state) do
    Logger.warn("Error, a test is already running")
    {:keep_fsm_state, {:error, :already_running}, state}
  end

  def test_succeeded(_, _test_ref, %BotArmy.IntegrationTest{} = state) do
    new_test_status = mark_test_passed("pre", state.test_status)

    {:next_fsm_state, %FSMState.Parallel{}, :ok, %{state | test_status: new_test_status}}
  end

  def test_failed(_, _test_ref, reason, %BotArmy.IntegrationTest{} = state) do
    Logger.error("Pre tree failed (#{inspect(reason)})")

    new_test_status = mark_test_failed("pre", reason, state.test_status)

    {:next_fsm_state, %FSMState.Post{}, :ok, %{state | test_status: new_test_status}}
  end
end

# ---- Parallel ----

defimpl FSMState, for: FSMState.Parallel do
  import BotArmy.IntegrationTest
  require Logger

  def on_enter(_, state) do
    Logger.warn("Beginning parallel tests...")

    refs =
      state.workflow.parallel()
      |> Enum.reduce(%{}, fn {key, tree}, acc ->
        ref = start_bot(key, tree, state.bot)
        Map.put(acc, ref, key)
      end)

    new_test_status =
      state.workflow.parallel()
      |> Enum.reduce(state.test_status, fn {k, _v}, tests -> add_test(k, tests) end)

    {:ok, %{state | test_status: new_test_status, test_names: refs}}
  end

  def run(_, _opts, %BotArmy.IntegrationTest{} = state) do
    Logger.warn("Error, a test is already running")
    {:keep_fsm_state, {:error, :already_running}, state}
  end

  def test_succeeded(_, test_ref, %BotArmy.IntegrationTest{} = state) do
    test_name = Map.get(state.test_names, test_ref, "unknown")
    Logger.warn("\"#{test_name}\" test passed...")

    new_test_status = mark_test_passed(test_name, state.test_status)

    if tests_complete?(new_test_status) do
      # start post
      Logger.warn("Parallel tests completed")

      {:next_fsm_state, %FSMState.Post{}, :ok, %{state | test_status: new_test_status}}
    else
      # keep going until all are finished
      {:keep_fsm_state, :ok, %{state | test_status: new_test_status}}
    end
  end

  def test_failed(_, test_ref, reason, %BotArmy.IntegrationTest{} = state) do
    test_name = Map.get(state.test_names, test_ref, "unknown")

    Logger.warn("\"#{test_name}\" test failed... #{inspect(reason)}")

    new_test_status = mark_test_failed(test_name, reason, state.test_status)

    if tests_complete?(new_test_status) do
      Logger.warn("Parallel tests completed")

      {:next_fsm_state, %FSMState.Post{}, :ok, %{state | test_status: new_test_status}}
    else
      # keep going until all are finished, but mark outcome as failed
      {:keep_fsm_state, :ok, %{state | test_status: new_test_status}}
    end
  end
end

# ---- Post ----

defimpl FSMState, for: FSMState.Post do
  import BotArmy.IntegrationTest
  require Logger

  def on_enter(_, state) do
    Logger.warn("Running post tree..")

    start_bot("post", state.workflow.post(), state.bot)

    {:ok, %{state | test_status: add_test("post", state.test_status)}}
  end

  def run(_, _opts, %BotArmy.IntegrationTest{} = state) do
    Logger.warn("Error, a test is already running")
    {:keep_fsm_state, {:error, :already_running}, state}
  end

  def test_succeeded(_, _test_ref, %BotArmy.IntegrationTest{} = state) do
    new_test_status = mark_test_passed("post", state.test_status)

    if run_passed?(new_test_status) do
      Logger.warn("Integration tests PASSED.",
        duration:
          (System.monotonic_time(:millisecond) - state.start_time)
          |> Timex.Duration.from_milliseconds()
          |> Timex.format_duration(:humanized)
      )

      state.callback.(:passed)
    else
      Logger.error("Integration tests FAILED.",
        duration:
          (System.monotonic_time(:millisecond) - state.start_time)
          |> Timex.Duration.from_milliseconds()
          |> Timex.format_duration(:humanized)
      )

      state.callback.({:failed, find_failed_tests(new_test_status)})
    end

    {:next_fsm_state, %FSMState.Ready{}, :ok, %{state | test_status: new_test_status}}
  end

  def test_failed(_, _test_ref, reason, %BotArmy.IntegrationTest{} = state) do
    new_test_status = mark_test_failed("post", reason, state.test_status)

    Logger.error("Post tree did not successfully complete. #{inspect(reason)}")

    Logger.error("Integration tests FAILED.",
      duration:
        (System.monotonic_time(:millisecond) - state.start_time)
        |> Timex.Duration.from_milliseconds()
        |> Timex.format_duration(:humanized)
    )

    state.callback.({:failed, find_failed_tests(new_test_status)})

    {:next_fsm_state, %FSMState.Ready{}, :ok, %{state | test_status: new_test_status}}
  end
end
