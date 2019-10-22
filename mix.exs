defmodule BotArmy.MixProject do
  use Mix.Project

  def project,
    do: [
      app: :bot_army,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: [
        integration_test_local: :test
      ]
    ]

  def application do
    [
      mod: {BotArmy, []},
      extra_applications: [:logger]
    ]
  end

  defp deps,
    do: [
      {:behavior_tree, "~> 0.3.1"},
      {:credo, "~> 0.8.10", only: [:dev, :test]},
      {:con_cache, "~> 0.13.1"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:excoveralls, "~> 0.8", only: :test},
      {:jason, "~> 1.1"},
      {:httpoison, "~> 1.0"},
      {:logger_file_backend, "~> 0.0.10"},
      {:mix_test_watch, "~> 0.9", only: :dev, runtime: false},
      {:mox, "~> 0.4", only: :test},
      {:plug_cowboy, "~> 2.0"},
      {:poison, "~> 3.1.0"},
      {:timex, "~> 3.0"}
    ]

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]
end
