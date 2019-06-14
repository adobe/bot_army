defmodule Mix.Tasks.Bots.IntegrationTest do
  @moduledoc """
  Runs integration tests in an iex context, logging the result and returning an 
  appropriate exit code.  

  Parameters: 

  * `v` - [optional] "Verbose", this will log more and print out all bot actions to 
  the console (in addition to the log file).  Recommended on CI to help debug.
  * `tree` - [required] The full name of the module defining the integration test 
  tree (must be in scope).  Must expose the function `tree/0`.  Ex: 
  "MyService.Workflow.Simple"
  * `bot` - [optional] A custom callback module implementing `BotArmy.Bot`, otherwise 
  uses `BotArmy.Bot.Default`
  * `custom` - [optional] Configs for your custom domain.  You must specify these in 
  quotes as an Elixir map or keyword list (ex: `--custom '[host: "dev"]'`).  Each 
  key/value pair will be placed into `BotArmy.SharedDAta` for access in your actions, 
  and other custom code.
  """
  use Mix.Task
  alias BotArmy.BotManager
  alias Mix.Tasks.Bots.Helpers

  @shortdoc "run the integration tests"
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
      :bot_count,
      :custom
    ]

    Logger.configure(level: :debug)
    Logger.add_backend({LoggerFileBackend, :bot_log})

    Logger.configure_backend({LoggerFileBackend, :bot_log},
      path: "bot_run.log",
      level: :debug,
      metadata: metadata
    )

    if Keyword.get(flags, :v),
      do:
        Logger.configure_backend(:console,
          level: :debug,
          metadata: metadata
        ),
      else: Logger.configure_backend(:console, level: :warn)

    bot_mod = Helpers.get_bot_mod(flags)
    tree_mod = Helpers.get_tree_mod(flags)

    IO.puts("Starting integration tests...")
    IO.puts("USING TREE: #{tree_mod}")
    IO.puts("USING BOT: #{bot_mod}")

    Helpers.save_custom_config(flags)

    pid = self()

    BotManager.integration_test(%{
      tree: tree_mod.tree(),
      bot: bot_mod,
      callback: fn
        :ok ->
          IO.puts("\n\nTest SUCCEEDED!!\n")
          send(pid, :succeed)

        error ->
          IO.puts("\n\nTest FAILED!!\n")
          IO.puts(inspect(error))
          send(pid, :fail)
      end
    })

    receive do
      :succeed ->
        :ok

      :fail ->
        exit({:shutdown, 1})
    after
      5 * 60 * 60 * 1000 ->
        IO.puts(:stderr, "ERROR - Tests didn't finish after 5 minutes.")
        exit({:shutdown, 1})
    end
  end
end
