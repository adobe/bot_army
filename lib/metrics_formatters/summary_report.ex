defmodule BotArmy.Metrics.SummaryReport do
  @moduledoc """
  Prints out a helpful summary about a bot run
  """

  require Logger
  alias BotArmy.Metrics

  def build_report do
    with {:ok, state} <- Metrics.get_state() do
      stop_time = Timex.now()

      report = """
      BOT RUN SUMMARY #{state.start_time} (UTC)
      #{state.n} bots for #{duration(state.start_time, stop_time)}
      ----------------------------------------
      #{
        Enum.reduce(state.actions, "", fn {key, %{runs: runs, avg_duration: avg_duration}}, acc ->
          acc <>
            "#{key} #{runs} times total (about #{round(runs / state.n)} times per bot) with an average duration of #{
              round(avg_duration)
            } ms\n\n"
        end)
      }
      """

      IO.puts("\n\n" <> report)
    else
      err -> err
    end
  end

  defp duration(start, stop) do
    stop
    |> Timex.diff(start, :duration)
    |> Timex.format_duration(:humanized)
  end
end
