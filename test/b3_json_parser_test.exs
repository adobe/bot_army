defmodule A do
  @moduledoc false

  def simple(), do: :ok

  def with_args(num, string, opts \\ []), do: :ok
end

defmodule A.Nested do
  @moduledoc false

  def test(), do: :ok
end

defmodule BotArmy.B3JsonParserTest do
  @moduledoc false

  use ExUnit.Case

  alias BehaviorTree.Node
  alias BotArmy.B3JsonParser

  describe "B3JsonParser" do
    test "parse/1" do
      path = "test/b3_json_sample.json"
      parsed = B3JsonParser.parse(path)
      assert parsed == expected_parsed_tree()
    end
  end

  defp expected_parsed_tree,
    do:
      Node.sequence([
        :a
        # Node.select([
        #   action(Sample, :validate_number, [n]),
        #   action(Common, :error, ["The number must be between 1 and 10"])
        # ]),
        # action(Sample, :init_guesses_count),
        # Node.repeat_until_succeed(action(BotArmy.Actions, :wait, [0])),
        # action(BotArmy.Actions, :wait, [60])
      ])
end
