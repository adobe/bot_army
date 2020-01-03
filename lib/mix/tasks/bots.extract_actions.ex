defmodule Mix.Tasks.Bots.ExtractActions do
  @moduledoc """
  Generates "custom action nodes" for the [behavior tree
  editor](https://git.corp.adobe.com/BotTestingFramework/behavior_tree_editor).

  This will scan all actions defined in the supplied `actions-dir` directory to build
  a json representation.  If you provide a `bt-json-file`, it will insert the
  generated nodes into the `custom_nodes` section (replacing any existing nodes!),
  otherwise it will print the json to screen for you to copy and paste via the
  "Project > Import > Nodes as JSON" menu option (this appends to existing custom
  nodes).

  Parameters:

  * `actions-dir` - [required] Path to the directory containing all of your actions.
  * `module-base` - [optional] If all of your actions start with a common prefix (Ex:
  `MyProject.Actions`), you can include this parameter to strip that prefix, making
  it easier to read the nodes in the visual editor.  Be sure to include the
  `module_base` option in `BotArmy.BTParser.parse!/2` to ensure the stripped base
  gets re-appended.
  * `bt-json-file` - [optional] Location of behavior tree editor project file.
  """

  # TODO ensure this makes it into the docs files

  use Mix.Task

  @shortdoc "Extract actions or behavior tree editor"

  def run(args) do
    # Needs this line to boot the actual tests application
    Mix.Task.run("app.start")

    Code.compiler_options(ignore_module_conflict: true)

    {flags, _, _} =
      OptionParser.parse(args,
        strict: [actions_dir: :string, module_base: :string, bt_json_file: :string]
      )

    actions_dir =
      Keyword.get(flags, :actions_dir) || raise "You must specify the \"actions_dir\" parameter"

    module_base =
      flags
      |> Keyword.get(:module_base, "")
      |> String.trim_trailing(".")
      |> String.replace_suffix("", ".")

    unless File.dir?(actions_dir), do: raise("#{inspect(actions_dir)} is not a valid directory")

    exported_actions =
      actions_dir
      |> Path.join("/**/*.ex")
      |> Path.wildcard()
      |> Enum.flat_map(&process_file(&1, module_base))

    bt_json_file = Keyword.get(flags, :bt_json_file)

    if bt_json_file do
      json =
        bt_json_file
        |> File.read!()
        |> Jason.decode!()

      json_with_custom_nodes = put_in(json, ["data", "custom_nodes"], exported_actions)

      File.write!(bt_json_file, Jason.encode!(json_with_custom_nodes))

      IO.puts(
        "SUCCESS, open (or close and reopen) #{bt_json_file} in the behavior tree editor to see the custom actions."
      )
    else
      inner =
        exported_actions
        |> Enum.map_join(",", &Jason.encode!/1)

      IO.puts("[" <> inner <> "]")
      IO.puts("SUCCESS, copy the above to import custom nodes")
    end
  end

  defp process_file(file, module_base) do
    [{mod, _} | _] = Code.compile_file(file)

    case Code.fetch_docs(mod) do
      {:docs_v1, _annotation1, _beam_language, _format, _module_doc, _metadata1, fn_docs} ->
        Enum.map(fn_docs, fn
          {{_kind, _function_name, _arity}, _annotation2, signature, fn_docs, _metadata2} ->
            signature =
              mod
              |> Module.split()
              |> Enum.concat(signature)
              |> Enum.join(".")
              |> String.replace_prefix(module_base, "")
              |> String.replace(~r/\(\s?[^,\s\)]+,?\s*/, "(")

            docs =
              (is_map(fn_docs) && Map.get(fn_docs, "en")) ||
                raise "No docs defined for #{signature}.  Please add some docs and retry"

            %{
              version: "0.3.0",
              scope: "node",
              name: signature,
              category: "action",
              title: signature,
              description: docs,
              properties: %{}
            }
        end)

      e ->
        raise "Error processing #{file}: #{inspect(e, pretty: true)}"
    end
  end
end
