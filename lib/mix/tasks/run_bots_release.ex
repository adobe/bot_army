defmodule Mix.Tasks.RunBotsRelease do
  @moduledoc """
  Intended to be used with Distillery releases, not invoked directly, see 
  `Mix.Tasks.RunBots` to run locally and for docs.  There is also an http route 
  option.

  """
  use Mix.Task
  alias BotArmy.BotManager
  alias Mix.Tasks.Bots.Helpers

  def run(args) do
    Application.ensure_all_started(:logger)
    Application.ensure_all_started(:bot_army)
    Mix.Task.run("app.start")

    {flags, _, _} = OptionParser.parse(args, switches: [])

    metadata = [
      :bot_id,
      :action,
      :outcome,
      :error,
      :duration,
      :uptime,
      :bot_pid,
      :session_id,
      :bot_count
    ]

    Logger.configure(level: :debug)
    Logger.add_backend({LoggerFileBackend, :bot_log})

    Logger.configure_backend({LoggerFileBackend, :bot_log},
      path: "bot_run.log",
      level: :debug,
      metadata: metadata
    )

    {num, _} = Integer.parse(Keyword.get(flags, :n, "10"))
    bot_mod = Helpers.get_bot_mod(flags)
    tree_mod = Helpers.get_tree_mod(flags)

    IO.puts("Starting bot run with #{num} bots")
    IO.puts("USING TREE: #{tree_mod}")
    IO.puts("USING BOT: #{bot_mod}")

    Helpers.save_custom_config(flags)

    BotManager.run(%{n: num, tree: tree_mod.tree(), bot: bot_mod})
  end
end
