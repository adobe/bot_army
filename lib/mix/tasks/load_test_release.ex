defmodule Mix.Tasks.LoadTestRelease do
  @moduledoc """
  Intended to be used with Distillery releases, not invoked directly, see
  `Mix.Tasks.LoadTest` to run locally and for docs.  There is also an http route
  option.

  """
  require Logger

  use Mix.Task
  alias BotArmy.LoadTest
  alias Mix.Tasks.Bots.Helpers
  alias BotArmy.LogFormatters.JSONLogFormatter

  def run(args) do
    Application.ensure_all_started(:logger)
    Application.ensure_all_started(:bot_army)
    Mix.Task.run("app.start")

    {flags, _, _} = OptionParser.parse(args, switches: [])

    {log_flags, _, _} =
      OptionParser.parse(args, strict: [disable_log_file: :boolean, format_json_logs: :boolean])

    metadata = [
      :bot_id,
      :bot_run_id,
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

    unless Keyword.get(log_flags, :disable_log_file) do
      Logger.add_backend({LoggerFileBackend, :bot_log})

      Logger.configure_backend({LoggerFileBackend, :bot_log},
        path: "bot_run.log",
        level: :debug,
        metadata: metadata
      )
    end

    Logger.configure_backend(:console, metadata: metadata, level: :debug)

    if Keyword.get(log_flags, :format_json_logs) do
      Logger.configure_backend(:console, format: {JSONLogFormatter, :format})
    end

    {num, _} = Integer.parse(Keyword.get(flags, :n, "10"))
    bot_mod = Helpers.get_bot_mod(flags)
    tree_mod = Helpers.get_tree_mod(flags)

    IO.puts("Starting bot run with #{num} bots")
    IO.puts("USING TREE: #{tree_mod}")
    IO.puts("USING BOT: #{bot_mod}")

    Helpers.save_custom_config(flags)

    LoadTest.run(%{n: num, tree: tree_mod.tree(), bot: bot_mod})
  end
end
