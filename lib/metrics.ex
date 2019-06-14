defmodule BotArmy.Metrics do
  @moduledoc """
  Stores information during the but run for metrics gathering.
  """

  use GenServer
  require Logger

  defstruct n: nil, start_time: nil, actions: %{}

  def start_link(_),
    do: GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)

  def run(count) when is_integer(count), do: GenServer.cast(__MODULE__, {:run, count})

  def get_state, do: GenServer.call(__MODULE__, :get_state)

  # ----

  def init(state), do: {:ok, state}

  def handle_cast({:run, count}, _state),
    do:
      {:noreply,
       %__MODULE__{
         n: count,
         start_time: Timex.now(),
         actions: %{}
       }}

  def handle_call(:get_state, _from, %{start_time: nil} = state) do
    {:reply, {:error, :report_is_not_running}, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_info({:action, module, action, duration, outcome}, state)
      when is_atom(module) and is_atom(action) and is_integer(duration) and duration >= 0 do
    success = if outcome == :succeed, do: 1, else: 0
    error = if outcome == :error, do: 1, else: 0

    new_actions =
      Map.update(
        state.actions,
        "#{module |> Module.split() |> List.last()}.#{action}",
        %{runs: 1, avg_duration: duration, success_count: success, error_count: error},
        fn %{
             runs: runs,
             avg_duration: avg_duration,
             success_count: success_count,
             error_count: error_count
           } ->
          %{
            runs: runs + 1,
            avg_duration: running_avg(avg_duration, duration, runs + 1),
            success_count: success_count + success,
            error_count: error_count + error
          }
        end
      )

    new_state = Map.put(state, :actions, new_actions)
    {:noreply, new_state}
  end

  def handle_info(m, state) do
    IO.puts("Ignoring unknown message #{inspect(m)}")
    {:noreply, state}
  end

  # -------

  # make sure to call with the new count, in other words, `prev_count + 1`
  defp running_avg(prev_avg, current_val, new_count) do
    prev_avg + (current_val - prev_avg) / new_count
  end
end
