defmodule BotArmy.MetricsExportTest do
  use ExUnit.Case, async: false

  alias BotArmy.Metrics.Export
  alias BotArmy.Metrics

  setup _context do
    Metrics.run(10)
  end

  # Note, the reference modules don't actually exist, but they are treated as atoms
  describe "metrics export" do
    test "total_error_count is the sum of all action errors" do
      send(Metrics, {:action, Actions.Renditions, :join, 212, :error})
      send(Metrics, {:action, Actions.Renditions, :request, 293, :error})

      report = Export.generate_report()

      assert Map.get(report, :total_error_count) == 2
    end

    test "successful actions are additive" do
      send(Metrics, {:action, Actions.Asset, :upload_image, 190, :succeed})
      send(Metrics, {:action, Actions.Asset, :upload_image, 320, :succeed})

      report = Export.generate_report()

      actions = Map.get(report, :actions)
      success_count = Map.get(actions, "Asset.upload_image")[:success_count]
      assert success_count == 2
    end

    test "error actions are additive" do
      send(Metrics, {:action, Actions.Renditions, :request, 212, :error})
      send(Metrics, {:action, Actions.Renditions, :request, 293, :error})

      report = Export.generate_report()

      actions = Map.get(report, :actions)
      error_count = Map.get(actions, "Renditions.request")[:error_count]
      assert error_count == 2
    end
  end
end
