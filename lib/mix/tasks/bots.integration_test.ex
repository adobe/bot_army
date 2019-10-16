defmodule Mix.Tasks.Bots.IntegrationTest do
  @moduledoc """
  Runs integration tests in an iex context, logging the result and returning an
  appropriate exit code.

  Parameters:

  * `v` - [optional] "Verbose", this will log more and print out all bot actions to
  the console (in addition to the log file).  Recommended on CI to help debug.
  * `workflow` - [required] The full name of the module defining the integration
  workflow (must be in scope).  Must implement `BotArmy.IntegrationTest.Workflow`.  Ex:
  "MyService.Workflow.Simple"
  * `bot` - [optional] A custom callback module implementing `BotArmy.Bot`, otherwise
  uses `BotArmy.Bot.Default`
  * `custom` - [optional] Configs for your custom domain.  You must specify these in
  quotes as an Elixir map or keyword list (ex: `--custom '[host: "dev"]'`).  Each
  key/value pair will be placed into `BotArmy.SharedData` for access in your actions,
  and other custom code.
  * `disable-log-file` - [optional] Disables file-based logging.
  * `format-json-logs` - [optional] BotArmy will output JSON-formatted log entries.
  """
  require Logger

  use Mix.Task
  alias BotArmy.IntegrationTest
  alias Mix.Tasks.Bots.Helpers
  alias BotArmy.LogFormatters.JSONLogFormatter

  @shortdoc "run the integration tests"
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
      :bot_count,
      :custom
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

    backend_configuration =
      if Keyword.get(flags, :v) do
        [level: :debug, metadata: metadata]
      else
        [level: :warn, metadata: [:bot_id, :action, :bot_run_id, :outcome]]
      end

    backend_configuration =
      if Keyword.get(log_flags, :format_json_logs) do
        backend_configuration ++ [format: {JSONLogFormatter, :format}]
      else
        backend_configuration
      end

    Logger.configure_backend(:console, backend_configuration)

    bot_mod = Helpers.get_bot_mod(flags)
    workflow_mod = Helpers.get_workflow_mod(flags)

    IO.puts("Starting integration tests...")
    IO.puts("USING WORKFLOW: #{workflow_mod}")
    IO.puts("USING BOT: #{bot_mod}")

    Helpers.save_custom_config(flags)

    pid = self()

    :ok =
      IntegrationTest.run(%{
        workflow: workflow_mod,
        bot: bot_mod,
        callback: fn
          :passed ->
            IO.puts("\n\nTest SUCCEEDED!!\n")
            send(pid, :succeed)

          {:failed, failures} ->
            IO.puts("\n\nTest FAILED!!\n")

            Enum.map(failures, fn {test_name, reason} ->
              IO.puts("Test \"#{test_name}\" failed: #{inspect(reason)}")
            end)

            send(pid, :fail)
        end
      })

    receive do
      :succeed ->
        :ok

      :fail ->
        exit({:shutdown, 1})
  end
end
