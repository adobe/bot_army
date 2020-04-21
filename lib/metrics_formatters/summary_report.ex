# Copyright 2020 Adobe
# All Rights Reserved.

# NOTICE: Adobe permits you to use, modify, and distribute this file in
# accordance with the terms of the Adobe license agreement accompanying
# it. If you have received this file from a source other than Adobe,
# then your use, modification, or distribution of it requires the prior
# written permission of Adobe.

defmodule BotArmy.Metrics.SummaryReport do
  @moduledoc """
  Prints out a helpful summary about a bot run
  """

  require Logger

  def build_report do
    case :ets.lookup(:metrics, "metrics") do
      [{"metrics", state}] ->
        compile_and_print_report(state)

      err ->
        err
    end
  end

  defp compile_and_print_report(state) do
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
  end

  defp duration(start, stop) do
    stop
    |> Timex.diff(start, :duration)
    |> Timex.format_duration(:humanized)
  end
end
