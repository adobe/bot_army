defmodule BotArmy.Actions do
  @moduledoc """
  Generic Actions.

  Actions are functions that take the bot's context and any supplied arguments, 
  perform some useful side effects, and then return the outcome.  The context is 
  always passed as the first argument.

  Valid outcomes are: `:succeed`, `:fail`, `:continue`, `:done` or `{:error, 
  reason}`.

  `:succeed`, `:fail`, and `:continue` can also be in the form of `{:succeed, key: 
  "value"}` if you want save/update the context.
  """

  require Logger

  @doc """
  A semantic helper to define actions in your behavior tree.

      Node.sequence([
        ...
        action(BotArmy.Actions, :wait, [5]),
        ...
        action(BotArmy.Actions, :done)
      ])
  """
  def action(module, fun, args \\ []) do
    {module, fun, args}
  end

  @doc """
  Makes the calling process wait for the given number of seconds
  """
  def wait(_context, s \\ 5) do
    Process.sleep(trunc(1000 * s))
    :succeed
  end

  @doc """
  Makes the calling process wait for a random number of seconds in the range defined 
  by the given integers min and max
  """
  def wait(_context, min, max) when is_integer(min) and is_integer(max) do
    Process.sleep(1000 * Enum.random(min..max))
    :succeed
  end

  @doc """
  Given a rate as a percentage, this will succeed that percent of the time, and fail 
  otherwise.

  For example `succeed_rate(context, 0.25)` will succeed on average 1 our of 4 tries.
  """
  def succeed_rate(_context, rate) when is_float(rate) and rate < 1 and rate > 0 do
    if :rand.uniform() <= rate,
      do: :succeed,
      else: :fail
  end

  @doc """
  This will stop the bot from running (by default bots "loop" continously through 
  their behavior trees
  """
  def done(_), do: :done

  @doc """
  Signal that this bot has errored, causing the bot's process to die with the given 
  reason.
  """
  def error(_, reason), do: {:error, reason}

  @doc """
  A helpful way to "tap" the flow of the behavior tree for debugging.
  """
  def log(_context, message) do
    Logger.info(message)
    :succeed
  end
end