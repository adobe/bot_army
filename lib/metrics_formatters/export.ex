defmodule BotArmy.Metrics.Export do
  @moduledoc """
  Formats metrics data for export (via the `/metrics` http endpoint)
  """

  alias BotArmy.Metrics

  @derive Jason.Encoder
  defstruct bot_count: nil, total_error_count: nil, actions: %{}

  def generate_report() do
    {:ok, %Metrics{actions: actions, n: n}} = Metrics.get_state()

    total_error_count =
      actions
      |> Enum.reduce(0, fn {_, %{error_count: errors}}, acc -> acc + errors end)

    %__MODULE__{
      bot_count: n,
      total_error_count: total_error_count,
      actions: actions
    }
  end
end
