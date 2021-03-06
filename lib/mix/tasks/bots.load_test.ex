# Copyright 2020 Adobe
# All Rights Reserved.

# NOTICE: Adobe permits you to use, modify, and distribute this file in
# accordance with the terms of the Adobe license agreement accompanying
# it. If you have received this file from a source other than Adobe,
# then your use, modification, or distribution of it requires the prior
# written permission of Adobe.

defmodule Mix.Tasks.Bots.LoadTest do
  @moduledoc """
  Task to run the bots.  Can call with various flags.  Opens an interactive window to
  control the bots, and prints a nice summary at the end.

  Supported arguments:

  * `n` number of bots, defaults to 10
  * `tree` - [required] The full name of the module defining the test
  tree (must be in scope).  Must expose the function `tree/0`.  Ex:
  "MyService.Workflow.Simple"
  * `bot` - [optional] A custom callback module implementing `BotArmy.Bot`, otherwise
  uses `BotArmy.Bot.Default`
  * `custom` - [optional] Configs for your custom domain.  You must specify these in
  quotes as an Elixir map or keyword list (ex: --custom '[host: "dev"]').  Each
  key/value pair will be placed into `BotArmy.SharedData` for access in your actions,
  and other custom code.
  * `disable-log-file` - [optional] Disables file-based logging.
  * `format-json-logs` - [optional] BotArmy will output JSON-formatted log entries.
  """
  use Mix.Task

  @shortdoc "Interactive loadtesting shell"
  def run(args) do
    Mix.Tasks.LoadTestRelease.run(args)

    IO.puts("Bots are running!  Enter 'q' to stop them and exit")
    receive_command()
  end

  defp receive_command do
    ""
    |> IO.gets()
    |> String.trim()
    |> String.downcase()
    |> execute_command()
  end

  defp execute_command("q") do
    IO.puts("\nStopping bots")
    BotArmy.Metrics.SummaryReport.build_report()
  end

  defp execute_command(_), do: receive_command()
end
