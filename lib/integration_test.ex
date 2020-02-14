defmodule BotArmy.IntegrationTest do
  @moduledoc """
  Adds macros to assist in running bot trees in ExUnit.

  Create a test file as per the normal ExUnit process, for example, in
  `test/my_project_test.exs`:

      defmodule MyProjectTest do
        @moduledoc false

        # This will set up ExUnit.Case, import `action` from BotArmy.Actions and
        # alias BehaviorTree.Node.  You can pass `async: true` just like with `use
        # ExUnit.Case` if you want to run this test file in parallel to other async
        # files (be careful of tests that mutate a global state!).
        use BotArmy.IntegrationTest, async: true

        alias MyProject.Actions.Sample

        # use this if you want a log file (applies to all tests in module)
        log_to_file()

        # use this if you use a custom bot module (applies to all tests in module)
        use_bot_module(MyProject.CustomBot)

        # normal ExUnit setup how ever you need
        setup do
          %{magic_number: 9}
        end

        # you can also setup/cleanup via a tree similar to using `test_tree`
        pre_all_tree "pre all" do
          Node.sequence([action(BotArmy.Actions, :log, ["Pre all ..."])])
        end

        # Run test trees with `test_tree`, which works very much like ExUnit's
        # `test`, except it will run the bot and pass or fail based on its outcome.
        #
        # Setting the `:verbose` tag will show all of the bot's logs for that test,
        # otherwise only errors will show.

        @tag :verbose
        test_tree "validate target number", context do
          Node.select([
            action(Sample, :validate_number, [context.magic_number]),
            action(BotArmy.Actions, :error, [context.magic_number <> " is an invalid number"])
          ])
        end

  Note, if a tree takes longer than 1 minute to run, it will fail the test.  You can
  set `@moduletag timeout: n` (or `@tag timeout: n` per test) to raise this limit.
  """

  require Logger

  @timeout 60_000

  defmacro __using__(opts) do
    quote do
      use ExUnit.Case, unquote(opts)
      import BotArmy.IntegrationTest
      import BotArmy.Actions, only: [action: 2, action: 3]
      alias BehaviorTree.Node

      @timeout 60_000

      setup :configure_logger
    end
  end

  @doc """
  Include `log_to_file()` if you want the full logs to be saved to a file.  You can
  pass a path to the file you want to log to, or it defaults to `bot_run.log`.
  """
  defmacro log_to_file(path \\ "bot_run.log") do
    quote do
      setup_all do
        setup_log_to_file(unquote(path))
        :ok
      end
    end
  end

  @doc """
  Specify this at the top of your module to use a specific bot module (see `BotArmy.Bot`).

  Defaults to `BotArmy.Bot.Default`.
  """
  defmacro use_bot_module(mod) do
    quote do
      setup_all do: [bot_module: unquote(mod)]
    end
  end

  @doc """
  Runs a tree before all the tests in the module.

  The body must return a tree.
  """
  defmacro pre_all_tree(message, context \\ quote(do: _), do: contents) do
    # don't show any output for setup trees
    configure_logger(%{})

    quote bind_quoted: [
            context: Macro.escape(context),
            contents: Macro.escape(contents, unquote: true),
            message: message
          ] do
      setup_all unquote(context) = context do
        :ok =
          run_tree(
            unquote(contents),
            to_bot_id(unquote(message)),
            # timeout is not in the context for setup_all
            context
            |> Map.take([:bot_module])
            |> Keyword.new()
            |> Keyword.merge(timeout: 3 * @timeout)
          )
      end
    end
  end

  @doc """
  Runs a tree before each test in the module.

  The body either needs to return a tree or `nil`, which is useful if you want to
  conditionally run a tree based on a test's tag.
  """
  defmacro pre_tree(message, context \\ quote(do: _), do: contents) do
    # don't show any output for setup trees
    configure_logger(%{})

    quote bind_quoted: [
            context: Macro.escape(context),
            contents: Macro.escape(contents, unquote: true),
            message: message
          ] do
      setup unquote(context) = context do
        case unquote(contents) do
          nil ->
            :ok

          tree ->
            :ok =
              run_tree(
                tree,
                to_bot_id(unquote(message)),
                context |> Map.take([:bot_module, :timeout]) |> Keyword.new()
              )
        end
      end
    end
  end

  @doc """
  Runs a tree after all the tests in the module.

  The body must return a tree.
  """
  defmacro post_all_tree(message, context \\ quote(do: _), do: contents) do
    # don't show any output for setup trees
    configure_logger(%{})

    quote bind_quoted: [
            context: Macro.escape(context),
            contents: Macro.escape(contents, unquote: true),
            message: message
          ] do
      setup_all unquote(context) = context do
        do_post_tree(unquote(message), context, unquote(contents))
      end
    end
  end

  @doc """
  Runs a tree after each test in the module.

  The body either needs to return a tree or `nil`, which is useful if you want to
  conditionally run a tree based on a test's tag.
  """
  defmacro post_tree(message, context \\ quote(do: _), do: contents) do
    # don't show any output for setup trees
    configure_logger(%{})

    quote bind_quoted: [
            context: Macro.escape(context),
            contents: Macro.escape(contents, unquote: true),
            message: message
          ] do
      setup unquote(context) = context do
        case unquote(contents) do
          nil -> :ok
          tree -> do_post_tree(unquote(message), context, tree)
        end
      end
    end
  end

  @doc false
  def do_post_tree(message, context, contents) do
    ExUnit.Callbacks.on_exit(fn ->
      # Need an unlinked, monitored process to properly run a bot in on_exit
      p =
        spawn(fn ->
          result =
            run_tree(
              contents,
              to_bot_id(message),
              context |> Map.take([:bot_module, :timeout]) |> Keyword.new()
            )

          unless match?(:ok, result),
            do: raise("#{inspect(result, pretty: true)}")
        end)

      ref = Process.monitor(p)

      timeout = Map.get(context, :timeout, @timeout)

      receive do
        {:DOWN, ^ref, :process, ^p, :normal} ->
          :ok

        {:DOWN, ^ref, :process, ^p, e} ->
          raise("Error during post tree. #{inspect(e)}")
      after
        timeout ->
          raise "Timeout while running post tree after #{timeout}ms."
      end
    end)
  end

  @doc """
  This works very much like ExUnit's `test` macro, except it runs your bot tree and
  fails or succeeds based on the outcome.  The body must return a valid tree.  You
  can use values from the context in the tree, just as with normal ExUnit tests.

  Your tree will be wrapped in order to always call the `done` action when it
  finishes (to prevent the default of looping through the tree from the top).
  """
  defmacro test_tree(message, context \\ quote(do: _), contents) do
    contents =
      case contents do
        [do: block] ->
          quote do
            unquote(block)
          end

        _ ->
          quote do
            try(unquote(contents))
          end
      end

    context = Macro.escape(context)
    contents = Macro.escape(contents, unquote: true)

    quote bind_quoted: [context: context, contents: contents, message: message] do
      name = ExUnit.Case.register_test(__ENV__, :test, message, [])

      def unquote(name)(unquote(context) = context) do
        opts = context |> Map.take([:bot_module, :timeout]) |> Keyword.new()

        tree = unquote(contents)

        bot_id = to_bot_id(unquote(message))

        assert :ok = run_tree(tree, bot_id, opts)
      end
    end
  end

  @doc """
  Runs a bot tree.  Used internally, but you could call it directly if you have a
  reason to.

  Takes an `opts` param that can include `bot_module` (defaults to
  `BotArmy.Bot.Default`).
  """
  def run_tree(
        %BehaviorTree.Node{} = tree,
        bot_id,
        opts \\ []
      )
      when is_binary(bot_id) do
    unless match?(%BehaviorTree.Node{}, tree),
      do: raise("the block of 'test_tree' must return a BehaviorTree.Node")

    bot_module = Keyword.get(opts, :bot_module, BotArmy.Bot.Default)
    timeout = Keyword.get(opts, :timeout, @timeout)

    case Code.ensure_loaded(bot_module) do
      {:module, ^bot_module} -> :ok
      e -> raise "Error finding bot module #{bot_module}.  Error: #{inspect(e)}"
    end

    Logger.debug("Using bot module #{bot_module}")

    Process.flag(:trap_exit, true)
    {:ok, bot_pid} = BotArmy.Bot.start_link(bot_module, id: bot_id)
    :ok = BotArmy.Bot.run(bot_pid, tree_with_done(tree))

    receive do
      {:EXIT, ^bot_pid, :shutdown} -> :ok
      {:EXIT, ^bot_pid, {:error, err}} -> {:error, err}
      {:EXIT, ^bot_pid, other} -> {:error, other}
    after
      timeout -> {:error, "Timeout while running test after #{timeout}ms"}
    end
  end

  @doc false
  def tree_with_done(tree),
    do:
      BehaviorTree.Node.sequence([
        BehaviorTree.Node.select([
          tree,
          BotArmy.Actions.action(BotArmy.Actions, :error, [:tree_failed])
        ]),
        BotArmy.Actions.action(BotArmy.Actions, :done)
      ])

  @doc false
  def setup_log_to_file(path) when is_binary(path) do
    metadata = [
      :bot_id,
      :bot_run_id,
      :action,
      :outcome,
      :error,
      :duration,
      :uptime,
      :bot_pid,
      :session_id,
      :bot_count,
      :custom
    ]

    Logger.add_backend({LoggerFileBackend, :bot_log})

    Logger.configure_backend({LoggerFileBackend, :bot_log},
      path: path,
      level: :debug,
      metadata: metadata
    )

    :ok
  end

  @doc false
  def configure_logger(context) do
    verbose = Map.get(context, :verbose)

    metadata = [
      :outcome,
      :action,
      :error,
      :duration,
      :bot_id,
      :bot_pid,
      :session_id,
      :custom
    ]

    backend_configuration =
      if verbose do
        [level: :debug, metadata: metadata]
      else
        [level: :error, metadata: [:outcome, :action, :bot_id]]
      end

    Logger.configure_backend(:console, backend_configuration)

    :ok
  end

  @doc false
  def to_bot_id(message) do
    message
    |> String.replace(~r/\s/, "_")
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
  end
end
