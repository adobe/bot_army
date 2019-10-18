defmodule BotArmy.EtsMetrics do
  @moduledoc """
  Stores information during the but run for metrics gathering.
  """

  use GenServer
  require Logger

  defstruct n: nil, start_time: nil, actions: %{}

  def start_link(_) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def run(count) when is_integer(count) do
    GenServer.cast(__MODULE__, {:run, count})
  end

  # ----

  def init(state) do
    :metrics = :ets.new(:metrics, [:set, :protected, :named_table, read_concurrency: true])

    {:ok, state}
  end

  def handle_cast({:run, count}, state) do
    run_state = %__MODULE__{
      n: count,
      start_time: Timex.now(),
      actions: %{}
    }

    true = :ets.insert(:metrics, {"metrics", run_state})

    {:noreply, state}
  end

  def handle_info({:action, module, action, duration, outcome}, state)
      when is_atom(module) and is_atom(action) and is_integer(duration) and duration >= 0 do
    success = if outcome == :succeed, do: 1, else: 0
    error = if outcome == :error, do: 1, else: 0

    try do
      case :ets.lookup(:metrics, "metrics") do
        [{"metrics", metrics}] ->
          new_actions =
            Map.update(
              metrics.actions,
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

          new_metrics = Map.put(metrics, :actions, new_actions)

          true = :ets.insert(:metrics, {"metrics", new_metrics})

        _ ->
          nil
      end
    rescue
      e in ArgumentError ->
        Logger.error("ArgumentError processing metrics: #{inspect(e)}")

      e ->
        Logger.error("Error processing metrics: #{inspect(e)}")
    end

    {:noreply, state}
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
