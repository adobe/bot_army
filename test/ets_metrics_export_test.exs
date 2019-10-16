defmodule BotArmy.EtsMetricsExportTest do
  use ExUnit.Case, async: false

  alias BotArmy.Metrics.Export
  alias BotArmy.EtsMetrics

  @moduletag :ets_metrics

  setup _context do
    EtsMetrics.run(10)
  end

  # Note, the reference modules don't actually exist, but they are treated as atoms
  describe "metrics export" do
    test "total_error_count is the sum of all action errors" do
      send(EtsMetrics, {:action, Actions.Renditions, :join, 212, :error})
      send(EtsMetrics, {:action, Actions.Renditions, :request, 293, :error})

      Process.sleep(100)

      report = Export.generate_report()

      assert Map.get(report, :total_error_count) == 2
    end

    test "successful actions are additive" do
      send(EtsMetrics, {:action, Actions.Asset, :upload_image, 190, :succeed})
      send(EtsMetrics, {:action, Actions.Asset, :upload_image, 320, :succeed})

      Process.sleep(100)

      report = Export.generate_report()

      actions = Map.get(report, :actions)
      success_count = Map.get(actions, "Asset.upload_image")[:success_count]
      assert success_count == 2
    end

    test "error actions are additive" do
      send(EtsMetrics, {:action, Actions.Renditions, :request, 212, :error})
      send(EtsMetrics, {:action, Actions.Renditions, :request, 293, :error})

      Process.sleep(100)

      report = Export.generate_report()

      actions = Map.get(report, :actions)
      error_count = Map.get(actions, "Renditions.request")[:error_count]
      assert error_count == 2
    end
  end
end
