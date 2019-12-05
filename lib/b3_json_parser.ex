defmodule BotArmy.B3JsonParser do
  @moduledoc """
  Parses .json files created from the Behaviour3 visual editor
  (https://github.com/behavior3/behavior3editor) into a `BehaviorTree.Node`.

  Trees must be designed with the following specifications:

  - You can have multiple trees, but one of them must be called "Root" (case does not
  matter).  That one will become the top level tree.
  - The following default nodes can be parsed:
    - "Sequence" composite nodes
    - "Priority" composite nodes (note, these are synonymous with "select" style
    nodes)
    - Other trees.  You can set properties on these nodes and use them in that tree's
      "Runner" nodes, see the notes there.  This is how you can "pass" values into a
      subtree.  You can set "default values" as properties on the "root" node of the
      actual subtree, which will be overridden if also specified on the node of the
      supertree.
    - "Runner" (or custom "Action") action nodes will become actions based on the
      supplied title in module format (Ex: ModuleA.NestedB.my_function).  You can add
      a space after the title and then include any other description you want which
      will be ignored.  Note that using `<my_key>` in the title will render as the
      value for the property with that key.  You can add properties, which will be
      ignored except for one with a key of `args`.  Use that key with a value of any
      Elixir terms separated by commas (Ex. `"a string", 1, %{body: "my map"}`) to
      supply to the action.  You can also use the format `{{my_key}}` in the args'
      value, which will be replaced with the value corresponding to that key on the
      parent tree's properties.
  """

  alias BehaviorTree.Node
  import BotArmy.Actions, only: [action: 3]

  def parse(path) do
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

  defp get_args(%{"properties" => %{"args" => int_arg}}, _context) when is_integer(int_arg),
    do: [int_arg]

  defp get_args(%{"properties" => %{"args" => args}}, context) do
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

        # value can be a number, so make sure it is a string
        to_string(value)
      end)

    case pre_parsed_args |> (&("[" <> &1 <> "]")).() |> TermParser.parse() do
      {:ok, parsed_args} ->
        parsed_args

      {:error, e} ->
        raise ~s(Unable to parse args `#{pre_parsed_args}`.  Make sure they are in a valid Elixir terms format, like `"my_string", 99, [opt_a: true]`.
          Raw error: #{inspect(e, pretty: true)})
    end
  end

  defp get_args(_, _), do: []

  defp convert_tree(tree, project) do
    tree["root"]
    |> get_node(tree)
    |> convert_node(tree, project)
  end

  ### Composites

  defp convert_node(%{"name" => "Sequence"} = node, tree, project) do
    children =
      node["children"]
      |> Enum.map(fn node_id ->
        node_id
        |> get_node(tree)
        |> convert_node(tree, project)
      end)

    Node.sequence(children)
  end

  defp convert_node(%{"name" => "Priority"} = node, tree, project) do
    children =
      node["children"]
      |> Enum.map(fn node_id ->
        node_id
        |> get_node(tree)
        |> convert_node(tree, project)
      end)

    Node.select(children)
  end

  ### Decorators

  defp convert_node(%{"name" => "RepeatUntilSuccess"} = node, tree, project) do
    child =
      node["child"]
      |> get_node(tree)
      |> convert_node(tree, project)

    Node.repeat_until_succeed(child)
  end

  defp convert_node(%{"name" => "Inverter"} = node, tree, project) do
    child =
      node["child"]
      |> get_node(tree)
      |> convert_node(tree, project)

    Node.negate(child)
  end

  defp convert_node(%{"name" => "RepeatUntilFailure"} = node, tree, project) do
    child =
      node["child"]
      |> get_node(tree)
      |> convert_node(tree, project)

    Node.repeat_until_fail(child)
  end

  defp convert_node(%{"name" => "Repeater"} = node, tree, project) do
    child =
      node["child"]
      |> get_node(tree)
      |> convert_node(tree, project)

    n =
      case Map.get(node["properties"], "maxLoop") do
        n when is_integer(n) and n > 1 -> n
        _ -> raise "Repeater nodes must have a `maxLoop` integer property greater than 1"
      end

    Node.repeat_n(n, child)
  end

  ### Actions

  defp convert_node(%{"name" => name} = node, tree, _project)
       when name in ["Runner", "Action"] do
    args = get_args(node, tree["properties"])

    with {:format?, [function | mod_reversed]} when mod_reversed != [] and function != "" <-
           {:format?,
            node["title"]
            |> String.split(" ", parts: 2)
            |> hd
            |> String.split(".", trim: true)
            |> Enum.reverse()},
         mod <- Enum.reverse(mod_reversed),
         {:exists?, true} <-
           {:exists?,
            function_exported?(
              Module.concat(mod),
              String.to_atom(function),
              Enum.count(args)
            )} do
      action(Module.concat(mod), String.to_atom(function), args)
    else
      {:format?, _} ->
        raise "Runner action nodes must have a title like \"Module.Submodule.function_name\".  Unable to parse \"#{
                node["title"]
              }\"."

      {:exists?, false} ->
        raise "The provided action does not exist: \"#{node["title"]}/#{Enum.count(args)}\""

      _ ->
        raise "Unknown error parsing \"#{node["title"]}\""
    end
  end

  defp convert_node(%{"name" => "Error"} = node, tree, _project) do
    args = get_args(node, tree["properties"])
    action(BotArmy.Actions, :error, args)
  end

  defp convert_node(%{"name" => "Wait"} = node, tree, _project) do
    # TODO after changing to custom wait node type, parse args
    # args = get_args(node, tree["properties"])
    action(BotArmy.Actions, :wait, [1])
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
