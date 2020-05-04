# Bot Army

A framework for building and running "bots" for load testing and integration testing.
Bots are defined by [Behavior
Trees](https://hexdocs.pm/behavior_tree/BehaviorTree.html) to replicate different
user sequences.

This package is a generic runner. It works in conjunction with domain specific bots
that you define in the service you want to test.

See [the bot army starter](https://github.com/adobe/bot_army_starter) for a sample
set up.

## Behavior what?

Behavior trees. It's a nifty way to declaratively express complex and variable
sequences of actions. Most importantly, they are composable, which makes them easy
to work with, and easy to scale.

[Read up on the docs](https://hexdocs.pm/behavior_tree/BehaviorTree.html) or [Watch a
video](https://www.youtube.com/watch?v=3sLYzxuKGXI).

Bots look like this:

```elixir
# in MyService.Workflow.Simple
def tree do
  BehaviorTree.Node.sequence([
    BotArmy.Actions.action(MyService.Actions, :get_ready),
    BotArmy.Actions.action(BotArmy.Actions, :wait, [5]),
    BehaviorTree.Node.select([
      BotArmy.Actions.action(MyService.Actions, :try_something, [42]),
      BotArmy.Actions.action(MyService.Actions, :try_something_else),
      BotArmy.Actions.action(BotArmy.Actions, :error, ["Darn, didn't work!"])
    ]),
    MyService.Workflow.DifficultWork.tree(),
    BotArmy.Actions.action(BotArmy.Actions, :done)
  ])
end
```

```elixir
# in MyService.Actions
def get_ready(context) do
  {id: id} = set_up()
  {:succeed, id: id} # adds `id` to the context for future actions to use
end

def try_something(context, magic_number) do
  case do_it(context.id, magic_number) do
    {:ok, _} -> :succeed
    {:error, _} -> :fail
  end
end

def try_something_else(context), do: ...
```

See `BotArmy.Bot` and `BotArmy.IntegrationTest` and `BotArmy.Actions` for more details.

## What if I want to make trees with a GUI editor?

No problem, check out the [Behavior Tree
Editor](https://github.com/adobe/behavior_tree_editor) to make json files that you
can parse with `BotArmy.BTParser.parse!/2`. You can export your actions with
`mix bots.extract_actions`.

![Behavior Tree Editor
example](https://raw.githubusercontent.com/adobe/behavior_tree_editor/master/preview.png)

## Release the bots!

Run the bots with `mix bots.load_test`:

    mix bots.load_test --n 100 --tree MyService.Workflow.Simple

## Integration testing

The bots can double as an integration testing system, which you can integrate into
your CI pipeline. Integration tests are run via
[ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html) just like normal unit tests. See
`BotArmy.IntegrationTest` for useful helpers that allow you to run trees as your
tests.

## Logging

> By default, logs are shunted to the `./bot_run.log` file.

It's hard to keep up with thousands of bots. The logs help, but need to be analyzed
in meaningful ways. Using [`lnav`](http://lnav.org) to view the `bot_run.log` file
is extremely useful. One useful approach is simply to find where errors occurred,
but making use of the SQL feature can give very useful metrics. Try these queries
for example (note that the key words are auto-derived from the log format):

    # list how many times each action ran
    ;select count(action_0), action_0 from logline group by action_0

    #see how long actions took on aggregate
    ;select min(duration), mode(duration), max(duration), avg(duration), action_0 from logline group by action_0 order by avg(duration) desc

    # Show count and duration for each distinct action attempted by the bots, grouped
    by success or failure.
    ;select count(action_0), avg(duration), outcome, action_0, outcome from logline group by outcome, action_0

    # list actions with their num of failures and errors and success rate
    ;SELECT action_0,count(*) as runs,count(CASE outcome WHEN "fail" then 1 end) as fails,count(CASE WHEN outcome LIKE "error%" then 1 end) as errors,round(100 * (count(CASE outcome WHEN "succeed" then 1 end)) / count(*)) as success_rate FROM logline group by action_0 order by success_rate desc

    # list average number of times bots perform each action (for the duration of the
    logs queried)
    ;select action_0, avg(runs) from (select bot_id, action_0, count(*) runs from logline group by bot_id, action_0) group by action_0 order by avg(runs) desc

`lnav` also offers some nice filtering options. For example:

    # Show only log lines where with a duration value of 1000ms or larger.
    :filter-in duration=\d{4,}ms

> Logging Configuration Options

Other logging formats may be useful depending on application. For example, if logs are output to Splunk or some other log aggregation tooling, it may be beneficial to use JSON-formatted logs rather than a line-by-line representation.

To enable JSON-formatted logs, pass the `--format-json-logs` option when starting your bot run.

To disable log outputs to a file, pass the `--disable-log-file` option when starting your bot run.

## Metrics schema

During the course of a run a `Bot` will generate information pertaining to their
activity in a system.

In order to communicate this information with the outside world a `BotManager` will
retain information about an ongoing attack which conforms to the following schema.

```
{
    bot_count: ...,
    total_error_count: ...,
    actions: {
        <action_name>: {
            duration (running average): ...,
            success_count: ...,
            error_count: ...
        }
    }
}
```

Where `bot_count` is expected to change over the course of a run and represents a
point in time count of the number of bots currently alive.

`actions` is a map whose keys are the name of the action and whose value is a map
containing key value pairs with the following information: The running average
duration the given action has taken to complete, the number of successful invocations
of the given action, and the number of errors encountered when running the given
action.

`total_error_count` is the aggregate of all errors reported by the bots. This can be
used to catch any lurking problems not directly reported via the `actions` error
counts.

## Communicating with the bots from outside

The bots expose a simple HTTP api on port `8124`.

You can use the following routes:

- `POST [host]:8124/load_test/start` (same params as `mix bots.load_test`)
- `DELETE [host]:8124/load_test/stop`
- `GET [host]:8124/metrics`
- `GET [host]:8124/logs`

## Are there tests?

> Who tests the tests?

Some. Run `make test`.
