defmodule Mix.Tasks.Bots.Run do
  @moduledoc """
  Task to run the bots.  Can call with various flags.  Opens an interactive window to 
  control the bots, and prints a nice summary at the end.

  Supported arguments:

  * `n` number of bots, defaults to 10
  * `tree` - [required] The full name of the module defining the integration test 
  tree (must be in scope).  Must expose the function `tree/0`.  Ex: 
  "MyService.Workflow.Simple"
  * `bot` - [optional] A custom callback module implementing `BotArmy.Bot`, otherwise 
  uses `BotArmy.Bot.Default`
  * `custom` - [optional] Configs for your custom domain.  You must specify these in 
  quotes as an Elixir map or keyword list (ex: --custom '[host: "dev"]').  Each 
  key/value pair will be placed into `BotArmy.SharedDAta` for access in your actions, 
  and other custom code.

  """
  use Mix.Task

  @shortdoc "Interactive loadtesting shell"
  def run(args) do
    Mix.Tasks.RunBotsRelease.run(args)

    IO.puts("Bots are running!  Enter 'q' to stop them and exit")
    receive_command()
  end

  defp receive_command do
    ""
    |> IO.gets()
    |> String.trim()
    |> String.downcase()
    |> execute_command
  end

  defp execute_command("q") do
    IO.puts("\nStopping bots")
    BotArmy.Metrics.SummaryReport.build_report()
  end

  defp execute_command(_), do: receive_command()
end
