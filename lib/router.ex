defmodule BotArmy.Router do
  @moduledoc """
  The exposed HTTP routes for communiating with the bots.

  The parameters are similar to the docs in the mix tasks under `mix/tasks`.
  """

  require Logger
  use Plug.Router
  plug(Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason)
  alias BotArmy.Metrics.Export
  alias Mix.Tasks.Bots.Helpers
  alias BotArmy.LoadTest
  alias BotArmy.LogFormatters.JSONLogFormatter

  plug(:match)
  plug(:dispatch)

  post "/load_test/start" do
    %{
      "n" => num,
      "tree" => tree,
      "bot" => bot,
      "custom" => custom,
      "log_options" => log_opts
    } = conn.body_params

    start_logs(log_opts)

    bot_mod = Helpers.get_bot_mod(bot: bot)
    tree_mod = Helpers.get_tree_mod(tree: tree)
    Helpers.save_custom_config(custom: custom)

    LoadTest.run(%{n: num, tree: tree_mod.tree(), bot: bot_mod})

    send_resp(conn, 200, "Bots started")
  end

  delete "/load_test/stop" do
    LoadTest.stop()
    send_resp(conn, 200, "Bots stopped")
  end

  get "/metrics" do
    with %Export{} = report <- Export.generate_report(),
         {:ok, report_json} <- Jason.encode(report) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, report_json)
    else
      e ->
        send_resp(conn, 500, inspect(e))
    end
  end

  get "/logs" do
    send_file(conn, 200, "bot_run.log")
  end

  get "/health" do
    send_resp(conn, 200, "healthy")
  end

  defp start_logs(opts) do
    metadata = [
      :bot_id,
      :bot_run_id,
      :action,
      :outcome,
      :error,
      :duration,
      :uptime,
      :bot_pid,
      :bot_count
    ]

    if Map.get(opts, "disable-log-file", "false") == "false" do
      Logger.add_backend({LoggerFileBackend, :bot_log})

      Logger.configure_backend({LoggerFileBackend, :bot_log},
        path: "bot_run.log",
        level: :debug,
        metadata: metadata
      )
    end

    Logger.configure_backend(:console, metadata: metadata, level: :debug)

    if Map.get(opts, "format-json-logs", "false") == "true" do
      Logger.configure_backend(:console, format: {JSONLogFormatter, :format})
    end
  end
end
