defmodule A do
  @moduledoc false

  def simple(), do: :ok

  def with_args(_num, _string, _opts \\ []), do: :ok
end

defmodule A.Nested do
  @moduledoc false

  def test(), do: :ok
end

defmodule B do
  @moduledoc false

  def test(_a, _b \\ 22, _c \\ 33), do: :ok
end

defmodule BotArmy.B3JsonParserTest do
  @moduledoc false

  use ExUnit.Case

  alias BehaviorTree.Node
  alias BotArmy.B3JsonParser
  import BotArmy.Actions, only: [action: 2, action: 3]

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
        Node.select([
          action(A, :simple),
          action(A.Nested, :test),
          action(A, :simple),
          action(A, :with_args, [1, "hi", [name: false]]),
          action(BotArmy.Actions, :error, ["Oops"])
        ]),
        Node.repeat_until_succeed(Node.negate(action(A, :simple))),
        Node.repeat_until_fail(action(A, :simple)),
        Node.repeat_n(5, action(A, :with_args, [2, "bye"])),
        action(BotArmy.Actions, :wait, [1]),
        action(BotArmy.Actions, :wait, [1]),
        tree_b(1),
        tree_b(111, 222, 333)
      ])

  defp tree_b(a, b \\ 999, _c \\ 999),
    do:
      Node.sequence([
        action(B, :test, [1, 2, 3]),
        action(B, :test, [a]),
        action(B, :test, [a, b, 3])
      ])
end
