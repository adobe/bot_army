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
      |> (fn
            # json output via save to file has a "wrapping" layer, whereas copy/paste
            # from Project > Export does not
            %{"data" => data} ->
              data

            full ->
              full
          end).()

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

  defp replace_templates!(str, context) when is_binary(str) and is_map(context) do
    Regex.replace(~r/{{([^}]+)}}/, str, fn _whole_match, key ->
      value = Map.get(context, key)

      unless value,
        do:
          raise(
            ~s(Unable to find a property with key `#{key}`in this node's tree's properties. Defined properties: `#{
              inspect(context)
            }`)
          )

      # The looked-up value might be an int, which doesn't work with Regex.replace
      # (becomes a binary), so we must to_string it first
      to_string(value)
    end)
  end

  defp replace_templates!(non_string, _context), do: non_string

  defp ensure_int(int) when is_integer(int), do: {:ok, int}

  defp ensure_int(other) do
    case Integer.parse(other) do
      {n, ""} -> {:ok, n}
      _ -> {:error, other}
    end
  end

  defp get_properties(node, context) do
    node["properties"]
    |> Enum.map(fn {k, v} ->
      {k, replace_templates!(v, context)}
    end)
    |> Enum.into(%{})
  end

  defp extract_args!(str, context) when is_binary(str) do
    [_all, args] = Regex.run(~r/^[^(]+\(([^)]*)\)/, str)
    args |> replace_templates!(context) |> parse_args!()
  end

  defp parse_args!(args) do
    case args |> (&("[" <> &1 <> "]")).() |> TermParser.parse() do
      {:ok, parsed_args} ->
        parsed_args

      {:error, e} ->
        raise ~s(Unable to parse args `#{args}`.  Make sure they are in a valid Elixir terms format, like `"my_string", 99, false, [opt_a: true], %{name: "Tom"}`.
          Raw error: #{inspect(e, pretty: true)})
    end
  end

  ###### Conversions

  ### Tree

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
        child = get_node(node_id, tree)

        with %{"weight" => weight_val} <- get_properties(child, tree["properties"]),
             {:ok, weight} when weight_val > 0 <- ensure_int(weight_val) do
          {convert_node(child, tree, project), weight}
        else
          e ->
            raise "All children nodes of a Random weighted node must have a \"weight\" proprty as an integer greater than 0, got: #{
                    inspect(child, pretty: true)
                  }
            specific error: #{inspect(e, pretty: true)}"
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

    with %{"n" => n_val} <- get_properties(node, tree["properties"]),
         {:ok, n} when n > 1 <- ensure_int(n_val) do
      Node.repeat_n(n, child)
    else
      e ->
        raise "Repeater nodes must have a `n` integer property greater than 1, got: #{
                inspect(node["properties"], pretty: true)
              }
        , specific error: #{inspect(e, pretty: true)}"
    end
  end

  ### Actions

  defp convert_node(%{"name" => name} = node, tree, _project)
       when name in ["runner", "action", "Action"] do
    with {:format?, [_all, mod_fn, args_str]} <-
           {:format?, Regex.run(~r/^([^(]+)\((.*)\)(?:\s.+|$)/, node["title"])},
         {:format?, [function_str | mod_reversed]} when mod_reversed != [] and function_str != "" <-
           {:format?, mod_fn |> String.split(".") |> Enum.reverse()},
         args <- args_str |> replace_templates!(tree["properties"]) |> parse_args!(),
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

  defp convert_node(%{"name" => "error"} = node, tree, _project) do
    args = extract_args!(node["title"], tree["properties"])

    action(BotArmy.Actions, :error, args)
  end

  defp convert_node(%{"name" => "wait"} = node, tree, _project) do
    args = extract_args!(node["title"], tree["properties"])

    unless match?([n | _] when n > 0, args),
      do:
        raise(
          "Wait nodes must have a \"seconds\" property greater than or equal to 0, or two integers like `wait(1, 10)`; got #{
            inspect(args)
          }"
        )

    action(BotArmy.Actions, :wait, args)
  end

  defp convert_node(%{"name" => "log"} = node, tree, _project) do
    args = extract_args!(node["title"], tree["properties"])
    action(BotArmy.Actions, :log, args)
  end

  defp convert_node(%{"name" => "succeed_rate"} = node, tree, _project) do
    args = extract_args!(node["title"], tree["properties"])

    unless match?([i] when i > 0 and i < 1, args),
      do:
        raise(
          "Succeed Rate nodes must have a \"rate\" argument between 0 and 1 like `succeed_rate(0.75); got #{
            inspect(args)
          }"
        )

    action(BotArmy.Actions, :succeed_rate, args)
  end

  defp convert_node(%{"name" => "done"}, _tree, _project) do
    action(BotArmy.Actions, :done, [])
  end

  defp convert_node(node, tree, project) do
    # might be a tree, check if the name is one of the tree ids
    tree_id = node["name"]

    target_tree =
      get_tree(tree_id, project) ||
        raise "Unknown node type: \"#{inspect(node, pretty: true)}\""

    node_props = get_properties(node, tree["properties"])

    target_tree
    |> Map.update!("properties", &Map.merge(&1, node_props))
    |> convert_tree(project)
  end
end
