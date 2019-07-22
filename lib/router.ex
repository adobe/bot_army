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
  alias BotArmy.{IntegrationTest, LoadTest}

  plug(:match)
  plug(:dispatch)

  post "/load_test/start" do
    %{
      "n" => num,
      "tree" => tree,
      "bot" => bot,
      "custom" => custom
    } = conn.body_params

    bot_mod = Helpers.get_bot_mod(bot: bot)
    tree_mod = Helpers.get_tree_mod(tree: tree)
    Helpers.save_custom_config(custom: custom)

    LoadTest.run(%{n: num, tree: tree_mod.tree(), bot: bot_mod})

    send_resp(conn, 200, "Bots started")
  end

  post "/integration_test/start" do
    %{
      "id" => id,
      "callback_url" => callback_url,
      "tree" => tree,
      "bot" => bot,
      "custom" => custom
    } = conn.body_params

    bot_mod = Helpers.get_bot_mod(bot: bot)
    tree_mod = Helpers.get_tree_mod(tree: tree)
    Helpers.save_custom_config(custom: custom)

    IntegrationTest.run(%{
      id: id,
      tree: tree_mod.tree(),
      bot: bot_mod,
      callback: fn result ->
        integration_callback(callback_url, %{id: id, result: result})
      end
    })

    send_resp(conn, 200, "Bots started")
  end

  delete "/load_test/stop" do
    LoadTest.stop()
    send_resp(conn, 200, "Bots stopped")
  end

  delete "/integration_test/stop" do
    IntegrationTest.stop()
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
    send_file(conn, 200, "standard.log")
  end

  get "/health" do
    send_resp(conn, 200, "healthy")
  end

  defp integration_callback(url, %{id: id, result: result}) do
    Logger.info(inspect(result, label: "Completed integration test, reporting results"))

    url
    |> HTTPoison.post(Poison.encode!(%{id: id, result: inspect(result)}), [
      {"content-type", "application/json"}
    ])
    |> case do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        :ok

      resp ->
        Logger.error("Failed to contact #{url}.  Error: #{inspect(resp, pretty: true)}")
        :error
    end
  end
end
