defmodule Mix.Tasks.Bots.Helpers do
  @moduledoc false

  alias BotArmy.SharedData

  @doc "Supply the provided flags, receive the bot module.  Errors if it fails."
  def get_bot_mod(flags) do
    bot_string = flags |> Keyword.get(:bot)

    if is_nil(bot_string),
      do: BotArmy.Bot.Default,
      else: parse_module(bot_string)
  end

  @doc "Supply the provided flags, receive the tree function.  Errors if it fails."
  def get_tree_mod(flags) do
    tree_mod_string = flags |> Keyword.get(:tree)

    if is_nil(tree_mod_string),
      do: raise("You must specify the module defining the tree (Ex: `--tree Test.Load`)")

    tree_mod = parse_module(tree_mod_string)

    if not function_exported?(tree_mod, :tree, 0),
      do: raise("Cannot find `#{tree_mod}.tree/0`.  Does it exist?")

    tree_mod
  end

  @doc "Supply the provided flags, receive the workflow.  Errors if it fails."
  def get_workflow_mod(flags) do
    workflow_string = flags |> Keyword.get(:workflow)

    if is_nil(workflow_string),
      do:
        raise(
          "You must specify the module defining the integration workflow (Ex: `--workflow Test.Integration.Workflow`)"
        )

    workflow_mod = parse_module(workflow_string)

    if not workflow_mod.bot_army_workflow?,
      do: raise("#{} must implement `BotArmy.Workflow`")

    workflow_mod
  end

  @doc """
  Saves custom config in SharedData.
  """
  def save_custom_config(flags) do
    flags
    |> Keyword.get(:custom, "[]")
    |> TermParser.parse()
    |> case do
      {:ok, term} ->
        IO.puts("Custom config: #{inspect(term)}")

        Enum.each(term, fn {key, value} ->
          SharedData.put(key, value)
        end)

      {:error, e} ->
        raise "Invalid `custom` config (#{inspect(e)})"
    end
  end

  @doc false
  defp parse_module(string) when is_binary(string) do
    {:module, mod} =
      string
      |> String.split(".")
      |> Module.safe_concat()
      |> Code.ensure_loaded()

    mod
  end
end
