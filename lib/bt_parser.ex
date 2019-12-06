defmodule BotArmy.BTParser do
  @moduledoc """
  Parses JSON files created from the Behavior Tree visual editor
  (https://git.corp.adobe.com/BotTestingFramework/behavior_tree_editor) into a
  `BehaviorTree.Node`, ready to be supplied to a bot.
  """

  alias BehaviorTree.Node
  import BotArmy.Actions, only: [action: 3]

  @doc """
  Parses the supplied JSON file created with the visual editor.
  """
  @spec parse!(path :: String.t()) :: BehaviorTree.Node.t()
  def parse!(path) do
    project =
      path
      |> File.read!()
      |> Jason.decode!()

    root_tree =
      Enum.find(
        project["trees"],
        fn %{"title" => title} -> String.downcase(title) == "root" end
      )

    unless root_tree,
      do:
        raise(
          "You must name one of your trees \"Root\".  Found trees: #{
            project["trees"] |> Enum.map(& &1["title"]) |> Enum.join(", ")
          }"
        )

    tree = convert_tree(root_tree, project)
    tree
  end

  defp get_tree(id, project) do
    Enum.find(
      project["trees"],
      fn
        %{"id" => ^id} -> true
        _ -> false
      end
    )
  end

  defp get_node(id, tree) do
    Map.get(tree["nodes"], id)
  end

  defp parse_args!(args, context) do
    pre_parsed_args =
      Regex.replace(~r/{{([^}]+)}}/, args, fn _whole_match, key ->
        value = Map.get(context, key)

        unless value,
          do:
            raise(
              ~s(Unable to find a property with key `#{key}`in this node's tree's properties. Defined properties: `#{
                inspect(context)
              }`)
            )

        # value might be a number, so make sure it is a string
        to_string(value)
      end)

    case pre_parsed_args |> (&("[" <> &1 <> "]")).() |> TermParser.parse() do
      {:ok, parsed_args} ->
        parsed_args

      {:error, e} ->
        raise ~s(Unable to parse args `#{pre_parsed_args}`.  Make sure they are in a valid Elixir terms format, like `"my_string", 99, false, [opt_a: true], %{name: "Tom"}`.
          Raw error: #{inspect(e, pretty: true)})
    end
  end

  defp convert_tree(tree, project) do
    tree["root"]
    |> get_node(tree)
    |> convert_node(tree, project)
  end

  ### Composites

  defp convert_node(%{"name" => "sequence"} = node, tree, project) do
    children =
      node["children"]
      |> Enum.map(fn node_id ->
        node_id
        |> get_node(tree)
        |> convert_node(tree, project)
      end)

    Node.sequence(children)
  end

  defp convert_node(%{"name" => "select"} = node, tree, project) do
    children =
      node["children"]
      |> Enum.map(fn node_id ->
        node_id
        |> get_node(tree)
        |> convert_node(tree, project)
      end)

    Node.select(children)
  end

  defp convert_node(%{"name" => "random"} = node, tree, project) do
    children =
      node["children"]
      |> Enum.map(fn node_id ->
        node_id
        |> get_node(tree)
        |> convert_node(tree, project)
      end)

    Node.random(children)
  end

  defp convert_node(%{"name" => "random_weighted"} = node, tree, project) do
    children =
      node["children"]
      |> Enum.map(fn node_id ->
        case get_node(node_id, tree) do
          %{"properties" => %{"weight" => weight}} = child
          when is_integer(weight) and weight > 0 ->
            {convert_node(child, tree, project), weight}

          child ->
            raise "All children nodes of a Random weighted node must have a \"weight\" proprty as an integer greater than 0, got #{
                    inspect(child, pretty: true)
                  }"
        end
      end)

    Node.random_weighted(children)
  end

  ### Decorators

  defp convert_node(%{"name" => "repeat_until_succeed"} = node, tree, project) do
    child =
      node["child"]
      |> get_node(tree)
      |> convert_node(tree, project)

    Node.repeat_until_succeed(child)
  end

  defp convert_node(%{"name" => "repeat_until_fail"} = node, tree, project) do
    child =
      node["child"]
      |> get_node(tree)
      |> convert_node(tree, project)

    Node.repeat_until_fail(child)
  end

  defp convert_node(%{"name" => "negate"} = node, tree, project) do
    child =
      node["child"]
      |> get_node(tree)
      |> convert_node(tree, project)

    Node.negate(child)
  end

  defp convert_node(%{"name" => "always_fail"} = node, tree, project) do
    child =
      node["child"]
      |> get_node(tree)
      |> convert_node(tree, project)

    Node.always_fail(child)
  end

  defp convert_node(%{"name" => "always_succeed"} = node, tree, project) do
    child =
      node["child"]
      |> get_node(tree)
      |> convert_node(tree, project)

    Node.always_succeed(child)
  end

  defp convert_node(%{"name" => "repeat_n"} = node, tree, project) do
    child =
      node["child"]
      |> get_node(tree)
      |> convert_node(tree, project)

    n =
      case Map.get(node["properties"], "n") do
        n when is_integer(n) and n > 1 -> n
        _ -> raise "Repeater nodes must have a `n` integer property greater than 1"
      end

    Node.repeat_n(n, child)
  end

  ### Actions

  defp convert_node(%{"name" => name} = node, tree, _project)
       when name in ["runner", "action", "Action"] do
    with {:format?, [_all, mod_fn, args_str]} <-
           {:format?, Regex.run(~r/^([^(]+)\((.*)\)(?:\s.+|$)/, node["title"])},
         {:format?, [function_str | mod_reversed]} when mod_reversed != [] and function_str != "" <-
           {:format?, mod_fn |> String.split(".") |> Enum.reverse()},
         args <- parse_args!(args_str, tree["properties"]),
         mod <- mod_reversed |> Enum.reverse() |> Module.concat(),
         function <- String.to_atom(function_str),
         {:exists?, true} <-
           {:exists?,
            function_exported?(
              mod,
              function,
              Enum.count(args)
            )} do
      action(mod, function, args)
    else
      {:format?, _} ->
        raise "Runner/custom action nodes must have a title like \"Module.Submodule.function_name(1,2,3)\" all in valid Elixir terms.  Unable to parse \"#{
                node["title"]
              }\"."

      {:exists?, false} ->
        raise "The provided action does not exist: \"#{node["title"]}\""

      _ ->
        raise "Unknown error parsing \"#{node["title"]}\""
    end
  end

  defp convert_node(%{"name" => "error"} = node, _tree, _project) do
    msg = node["properties"]["msg"] || raise "Error nodes must have a \"msg\" property."
    action(BotArmy.Actions, :error, [msg])
  end

  defp convert_node(
         %{"name" => "wait", "properties" => %{"seconds" => n}},
         _tree,
         _project
       )
       when is_integer(n) do
    unless n >= 0,
      do:
        raise(
          "Wait nodes must have a \"seconds\" property greater than or equal to 0, got #{
            inspect(n)
          }"
        )

    action(BotArmy.Actions, :wait, [n])
  end

  defp convert_node(
         %{"name" => "wait", "properties" => %{"seconds" => str}},
         _tree,
         _project
       )
       when is_binary(str) do
    case str |> String.split(",") |> Enum.map(&(&1 |> String.trim() |> Integer.parse())) do
      [{a, _}, {b, _}] when is_integer(a) and is_integer(b) ->
        action(BotArmy.Actions, :wait, [a, b])

      _ ->
        raise "Wait nodes must have a \"seconds\" property with a value of either a positive integer or two positive integers separated by a comma, got #{
                inspect(str)
              }"
    end
  end

  defp convert_node(%{"name" => "wait"} = node, _tree, _project) do
    raise "Wait nodes must have a \"seconds\" property with a value of either a positive integer or two positive integers separated by a comma, got #{
            inspect(node, pretty: true)
          }"
  end

  defp convert_node(%{"name" => "log"} = node, _tree, _project) do
    msg = node["properties"]["msg"] || raise "Log nodes must have a \"msg\" property."
    action(BotArmy.Actions, :log, [msg])
  end

  defp convert_node(%{"name" => "succeed_rate"} = node, _tree, _project) do
    rate = node["properties"]["rate"] || raise "Succeed Rate nodes must have a \"rate\" property."
    action(BotArmy.Actions, :succeed_rate, [rate])
  end

  defp convert_node(%{"name" => "done"}, _tree, _project) do
    action(BotArmy.Actions, :done, [])
  end

  defp convert_node(node, _tree, project) do
    # might be a tree, check if the name is one of the tree ids
    tree_id = node["name"]

    tree =
      get_tree(tree_id, project) ||
        raise "Unknown node type: \"#{inspect(node, pretty: true)}\""

    tree
    |> Map.update!("properties", &Map.merge(&1, node["properties"]))
    |> convert_tree(project)
  end
end
