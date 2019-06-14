defmodule BotArmy.SharedData do
  @moduledoc """
  While the "context" lets you share state between actions, `SharedData` lets you 
  share state between bots.  In addition, it is a central place to hold global data, 
  like runtime config data.

  This module is a simple wrapper around a basic ETS table.  As noted above, the 
  runner tasks/router will store runtime config here as well.

  Note that this does not supply any kind of locking mechanism, so be aware of race 
  conditions.  This is by design for two reasons.  First, config is a read-only use 
  case.  Second, for data-sharing, bots represent users, which operate independently 
  of each other in real life with async data sharing patterns (email, slack).
  """

  use Agent
  @cache_name :bot_shared_data

  @doc false
  def start_link(_) do
    ConCache.start_link(
      name: @cache_name,
      ttl_check_interval: false,
      ets_options: [write_concurrency: true, read_concurrency: true]
    )
  end

  @doc "Get a value by key (returns `nil` if not found)"
  def get(key) do
    ConCache.get(@cache_name, key)
  end

  @doc "Put a value by key."
  def put(key, value) do
    ConCache.put(@cache_name, key, value)
  end

  @doc "Update a value by key. `update_fn` is val -> val."
  def update(key, update_fn) do
    ConCache.update(@cache_name, key, &{:ok, update_fn.(&1)})
  end
end
