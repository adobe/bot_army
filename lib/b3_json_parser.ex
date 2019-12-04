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
    - Other trees
    - "Runner" (or custom "Action") action nodes will become actions based on the
      supplied title in module format (Ex: ModuleA.NestedB.my_function).  You can add
      a space after the title and then include any other description you want which
      will be ignored.  Note that using `<my_key>` in the title will render as the
      value for the property with that key.  You can add properties, which will be
      ignored except for one with a key of `args`.  Use that key with a value of any
      Elixir terms separated by commas (Ex. `"a string", 1, %{body: "my map"}`) to
      supply to the action.
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
    IO.inspect(tree)
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

  defp get_args(node) do
    # TODO
    []
  end

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

  ### Actions

  defp convert_node(%{"name" => name} = node, _tree, _project)
       when name in ["Runner", "Action"] do
    args = get_args(node)

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

  defp convert_node(%{"name" => "Error"} = node, _tree, _project) do
    args = get_args(node)
    action(Actions, :error, args)
  end

  defp convert_node(node, _tree, project) do
    # might be a tree, check if the name is one of the tree ids
    case get_tree(node["name"], project) do
      nil -> raise "Unknown node type: \"#{inspect(node, pretty: true)}\""
      node -> convert_tree(node, project)
    end
  end
end
