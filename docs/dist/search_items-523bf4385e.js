searchNodes=[{"ref":"BotArmy.Actions.html","title":"BotArmy.Actions","type":"module","doc":"Generic Actions. Actions are functions that take the bot&#39;s context and any supplied arguments, perform some useful side effects, and then return the outcome. The context is always passed as the first argument. Valid outcomes are: :succeed, :fail, :continue, :done or {:error, reason}. :succeed, :fail, and :continue can also be in the form of {:succeed, key: &quot;value&quot;} if you want save/update the context."},{"ref":"BotArmy.Actions.html#action/3","title":"BotArmy.Actions.action/3","type":"function","doc":"A semantic helper to define actions in your behavior tree. Node.sequence([ ... action(BotArmy.Actions, :wait, [5]), ... action(BotArmy.Actions, :done) ])"},{"ref":"BotArmy.Actions.html#done/1","title":"BotArmy.Actions.done/1","type":"function","doc":"This will stop the bot from running (by default bots &quot;loop&quot; continously through their behavior trees"},{"ref":"BotArmy.Actions.html#error/2","title":"BotArmy.Actions.error/2","type":"function","doc":"Signal that this bot has errored, causing the bot&#39;s process to die with the given reason."},{"ref":"BotArmy.Actions.html#log/2","title":"BotArmy.Actions.log/2","type":"function","doc":"A helpful way to &quot;tap&quot; the flow of the behavior tree for debugging."},{"ref":"BotArmy.Actions.html#succeed_rate/2","title":"BotArmy.Actions.succeed_rate/2","type":"function","doc":"Given a rate as a percentage, this will succeed that percent of the time, and fail otherwise. For example succeed_rate(context, 0.25) will succeed on average 1 our of 4 tries."},{"ref":"BotArmy.Actions.html#wait/2","title":"BotArmy.Actions.wait/2","type":"function","doc":"Makes the calling process wait for the given number of seconds"},{"ref":"BotArmy.Actions.html#wait/3","title":"BotArmy.Actions.wait/3","type":"function","doc":"Makes the calling process wait for a random number of seconds in the range defined by the given integers min and max"},{"ref":"BotArmy.Bot.html","title":"BotArmy.Bot","type":"behaviour","doc":"A &quot;live&quot; bot that can perform actions described by a behavior tree (BehaviorTree.Node). Bots are just GenServers that continuously tick through the provided behavior tree until they die or get an outcome of :done. Each bot has a &quot;bag of state&quot; called the &quot;context&quot; (sometimes called a &quot;blackboard&quot; in behaviour tree terminology), which is used to pass values between actions. Bots ingest actions (the leaf nodes of the tree) in the form of MFA tuples. The function will be called with the current context and any provided arguments. The function must return an outcome, and may also return key-value pairs to store/update in the context. See the README for an example. Accepted outcomes are: :succeed, :fail, :continue, :done or {:error, reason}. :succeed, :fail and :continue can also be in the form of {:succeed, key: &quot;value&quot;} if you want save/update the context. :succeed and :fail will advance the tree via BehaviorTree, while :continue will leave the tree as it is for the next tick (this can be useful for example for attempting an action multiple times with a sleep and a &quot;max tries&quot; counter in the context). :done stops the bot process successfully, and {:error, reason} kills the bot process with the provided reason. Note the following keys are reserved, and should not be overwritten: id, bt, start_time Extending the Bot You can use Bot exactly as it is. However, if you need to add additional functionality to your bots, you can do so. BotArmy.Bot is actually a behaviour that you can use (use BotArmy.Bot) in a custom callback module. It has a couple of callbacks for config, logging, and lifecycle hooks (TODO). Since Bot itself uses a GenServer, you can also add GenServer callbacks, such as init, or handle_[call|cast|info] (format_status/2 is particularly useful). For example, you may have a syncing system over websockets that updates the state in the bot&#39;s context. By extending Bot with some additional handlers, you can add this functionality. The aforementioned &quot;context&quot; is just the GenServer&#39;s state, so your Actions will have access to everything there. You can set up initial state in init/1, and modify it in your handlers as necessary. If you implement init/1, the argument will be the starting state, so you can merge your state into that, but must return it. Again, please be mindful not to overwrite the following keys in the state: id, bt, start_time. IMPORTANT - if you do extend Bot, you must set the bot param when starting a run (see the docs in the mix tasks)."},{"ref":"BotArmy.Bot.html#c:log_action_outcome/3","title":"BotArmy.Bot.log_action_outcome/3","type":"callback","doc":"Implement this callback if you want a custom way to log action outcomes. Defaults to a call to Logger.info with nice meta data."},{"ref":"BotArmy.Bot.html#run/2","title":"BotArmy.Bot.run/2","type":"function","doc":"Instruct the bot to run the supplied behavior tree. Note, the bot will repeatedly loop through the tree unless you include an action that returns :done, at which point it will die. Returns an error tuple if called on a bot that is already running."},{"ref":"BotArmy.Bot.html#start_link/2","title":"BotArmy.Bot.start_link/2","type":"function","doc":"Start up a new bot using the supplied bot implementation. Takes a keyword list of options that will be passed to the GenServer. The following keys are also used: :id - [required] an identifier for this specific bot, used for logging purposes."},{"ref":"BotArmy.Bot.Default.html","title":"BotArmy.Bot.Default","type":"module","doc":"The standard bot, implementing the BotArmy.Bot behaviour, without any additional functionality or configuration."},{"ref":"BotArmy.Bot.Default.html#child_spec/1","title":"BotArmy.Bot.Default.child_spec/1","type":"function","doc":"Returns a specification to start this module under a supervisor. See Supervisor."},{"ref":"BotArmy.Bot.Default.html#start_link/1","title":"BotArmy.Bot.Default.start_link/1","type":"function","doc":""},{"ref":"BotArmy.IntegrationTest.html","title":"BotArmy.IntegrationTest","type":"module","doc":"Manages an integration test run. Don&#39;t use this directly, call from mix bots.integration_test. See the documentation for the available params. This will run the &quot;pre&quot; tree first, then the &quot;parallel&quot; trees concurrently, then the &quot;post&quot; tree. The post tree will always run, even if prior trees fail."},{"ref":"BotArmy.IntegrationTest.html#add_test/2","title":"BotArmy.IntegrationTest.add_test/2","type":"function","doc":""},{"ref":"BotArmy.IntegrationTest.html#child_spec/1","title":"BotArmy.IntegrationTest.child_spec/1","type":"function","doc":"Returns a specification to start this module under a supervisor. See Supervisor."},{"ref":"BotArmy.IntegrationTest.html#find_failed_tests/1","title":"BotArmy.IntegrationTest.find_failed_tests/1","type":"function","doc":""},{"ref":"BotArmy.IntegrationTest.html#init/1","title":"BotArmy.IntegrationTest.init/1","type":"function","doc":"Invoked when the server is started. start_link/3 or start/3 will block until it returns. init_arg is the argument term (second argument) passed to start_link/3. Returning {:ok, state} will cause start_link/3 to return {:ok, pid} and the process to enter its loop. Returning {:ok, state, timeout} is similar to {:ok, state} except handle_info(:timeout, state) will be called after timeout milliseconds if no messages are received within the timeout. Returning {:ok, state, :hibernate} is similar to {:ok, state} except the process is hibernated before entering the loop. See c:handle_call/3 for more information on hibernation. Returning {:ok, state, {:continue, continue}} is similar to {:ok, state} except that immediately after entering the loop the c:handle_continue/2 callback will be invoked with the value continue as first argument. Returning :ignore will cause start_link/3 to return :ignore and the process will exit normally without entering the loop or calling c:terminate/2. If used when part of a supervision tree the parent supervisor will not fail to start nor immediately try to restart the GenServer. The remainder of the supervision tree will be started and so the GenServer should not be required by other processes. It can be started later with Supervisor.restart_child/2 as the child specification is saved in the parent supervisor. The main use cases for this are: The GenServer is disabled by configuration but might be enabled later. An error occurred and it will be handled by a different mechanism than the Supervisor. Likely this approach involves calling Supervisor.restart_child/2 after a delay to attempt a restart. Returning {:stop, reason} will cause start_link/3 to return {:error, reason} and the process to exit with reason reason without entering the loop or calling c:terminate/2. Callback implementation for GenServer.init/1."},{"ref":"BotArmy.IntegrationTest.html#mark_test_failed/3","title":"BotArmy.IntegrationTest.mark_test_failed/3","type":"function","doc":""},{"ref":"BotArmy.IntegrationTest.html#mark_test_passed/2","title":"BotArmy.IntegrationTest.mark_test_passed/2","type":"function","doc":""},{"ref":"BotArmy.IntegrationTest.html#run/1","title":"BotArmy.IntegrationTest.run/1","type":"function","doc":"Starts the integration test. This supports parallel trees, and a pre and post step. Opts map: workflow - [required] the module defining the work to be done. Must implement BotArmy.IntegrationTest.Workflow. bot - [optional] a custom callback module implementing BotArmy.Bot, otherwise uses BotArmy.Bot.Default callback - [required] a function that will be called with the result of the test, which will either be :passed or {:failed, &lt;failed tests&gt;} where &quot;failed tests&quot; is a list of tuples with test keys and failure reasons. Returns :ok or {:error, reason}."},{"ref":"BotArmy.IntegrationTest.html#run_passed?/1","title":"BotArmy.IntegrationTest.run_passed?/1","type":"function","doc":""},{"ref":"BotArmy.IntegrationTest.html#start_bot/3","title":"BotArmy.IntegrationTest.start_bot/3","type":"function","doc":""},{"ref":"BotArmy.IntegrationTest.html#start_link/1","title":"BotArmy.IntegrationTest.start_link/1","type":"function","doc":""},{"ref":"BotArmy.IntegrationTest.html#stop/0","title":"BotArmy.IntegrationTest.stop/0","type":"function","doc":""},{"ref":"BotArmy.IntegrationTest.html#test_failed/2","title":"BotArmy.IntegrationTest.test_failed/2","type":"function","doc":"Report montitored bots upon failing."},{"ref":"BotArmy.IntegrationTest.html#test_succeeded/1","title":"BotArmy.IntegrationTest.test_succeeded/1","type":"function","doc":"Report montitored bots upon succeeding."},{"ref":"BotArmy.IntegrationTest.html#tests_complete?/1","title":"BotArmy.IntegrationTest.tests_complete?/1","type":"function","doc":""},{"ref":"BotArmy.IntegrationTest.html#tree_with_done/1","title":"BotArmy.IntegrationTest.tree_with_done/1","type":"function","doc":""},{"ref":"BotArmy.IntegrationTest.BotMonitor.html","title":"BotArmy.IntegrationTest.BotMonitor","type":"module","doc":"watches the bots for the runner, reporting any succeeding or failing tests."},{"ref":"BotArmy.IntegrationTest.BotMonitor.html#child_spec/1","title":"BotArmy.IntegrationTest.BotMonitor.child_spec/1","type":"function","doc":"Returns a specification to start this module under a supervisor. See Supervisor."},{"ref":"BotArmy.IntegrationTest.BotMonitor.html#init/1","title":"BotArmy.IntegrationTest.BotMonitor.init/1","type":"function","doc":"Invoked when the server is started. start_link/3 or start/3 will block until it returns. init_arg is the argument term (second argument) passed to start_link/3. Returning {:ok, state} will cause start_link/3 to return {:ok, pid} and the process to enter its loop. Returning {:ok, state, timeout} is similar to {:ok, state} except handle_info(:timeout, state) will be called after timeout milliseconds if no messages are received within the timeout. Returning {:ok, state, :hibernate} is similar to {:ok, state} except the process is hibernated before entering the loop. See c:handle_call/3 for more information on hibernation. Returning {:ok, state, {:continue, continue}} is similar to {:ok, state} except that immediately after entering the loop the c:handle_continue/2 callback will be invoked with the value continue as first argument. Returning :ignore will cause start_link/3 to return :ignore and the process will exit normally without entering the loop or calling c:terminate/2. If used when part of a supervision tree the parent supervisor will not fail to start nor immediately try to restart the GenServer. The remainder of the supervision tree will be started and so the GenServer should not be required by other processes. It can be started later with Supervisor.restart_child/2 as the child specification is saved in the parent supervisor. The main use cases for this are: The GenServer is disabled by configuration but might be enabled later. An error occurred and it will be handled by a different mechanism than the Supervisor. Likely this approach involves calling Supervisor.restart_child/2 after a delay to attempt a restart. Returning {:stop, reason} will cause start_link/3 to return {:error, reason} and the process to exit with reason reason without entering the loop or calling c:terminate/2. Callback implementation for GenServer.init/1."},{"ref":"BotArmy.IntegrationTest.BotMonitor.html#monitor/1","title":"BotArmy.IntegrationTest.BotMonitor.monitor/1","type":"function","doc":"Pass a pid to monitor, returns the ref"},{"ref":"BotArmy.IntegrationTest.BotMonitor.html#start_link/1","title":"BotArmy.IntegrationTest.BotMonitor.start_link/1","type":"function","doc":""},{"ref":"BotArmy.IntegrationTest.FSMState.html","title":"BotArmy.IntegrationTest.FSMState","type":"protocol","doc":""},{"ref":"BotArmy.IntegrationTest.FSMState.html#on_enter/2","title":"BotArmy.IntegrationTest.FSMState.on_enter/2","type":"function","doc":"work to do upon entering a state"},{"ref":"BotArmy.IntegrationTest.FSMState.html#run/3","title":"BotArmy.IntegrationTest.FSMState.run/3","type":"function","doc":"start a new test run"},{"ref":"BotArmy.IntegrationTest.FSMState.html#test_failed/4","title":"BotArmy.IntegrationTest.FSMState.test_failed/4","type":"function","doc":"test failed"},{"ref":"BotArmy.IntegrationTest.FSMState.html#test_succeeded/3","title":"BotArmy.IntegrationTest.FSMState.test_succeeded/3","type":"function","doc":"test passed"},{"ref":"BotArmy.IntegrationTest.FSMState.html#t:t/0","title":"BotArmy.IntegrationTest.FSMState.t/0","type":"type","doc":""},{"ref":"BotArmy.IntegrationTest.FSMState.html#t:transition_response/0","title":"BotArmy.IntegrationTest.FSMState.transition_response/0","type":"type","doc":"Response from a state specifying which state to transition to (or to keep the current state), and the response to send to the caller, and the new state."},{"ref":"BotArmy.IntegrationTest.Workflow.html","title":"BotArmy.IntegrationTest.Workflow","type":"behaviour","doc":"A behaviour to implement when defining an integration test run. This behaviour allows defining multiple trees to run in parallel, as well as a &quot;pre&quot; and &quot;post&quot; tree. For example, a &quot;pre&quot; tree might check the server health and obtain a log in token to store in BotArmy.SharedData. Then multiple trees could use the same token to run various tests in parallel. Finally, a &quot;post&quot; tree could do a final check or cleanup. Note that each parallel tree will be run by a new bot instance. Keep race conditions in mind if your tests make use of the same resource. If any tree fails (including the pre and post trees), the entire run will fail. The post tree will always run, even if prior trees fail"},{"ref":"BotArmy.IntegrationTest.Workflow.html#c:parallel/0","title":"BotArmy.IntegrationTest.Workflow.parallel/0","type":"callback","doc":"Required. A map of trees which will each be run in parallel with their own bot.The key is used for reporting."},{"ref":"BotArmy.IntegrationTest.Workflow.html#c:post/0","title":"BotArmy.IntegrationTest.Workflow.post/0","type":"callback","doc":"Optional. A tree to run after all other trees in this run have completed, or if any tree fails. This is useful for tear down or testing postconditions."},{"ref":"BotArmy.IntegrationTest.Workflow.html#c:pre/0","title":"BotArmy.IntegrationTest.Workflow.pre/0","type":"callback","doc":"Optional. A tree to run before doing anything else in this run. This is useful for set up or testing preconditions."},{"ref":"BotArmy.LoadTest.html","title":"BotArmy.LoadTest","type":"module","doc":"Manages a load test run. Don&#39;t use this directly, call from mix bots.load_test. See the documentation for the available params. This will start up the target number of bots. If bots die off, this will restart them in batches to return to the target number. Bots run until calling stop."},{"ref":"BotArmy.LoadTest.html#child_spec/1","title":"BotArmy.LoadTest.child_spec/1","type":"function","doc":"Returns a specification to start this module under a supervisor. See Supervisor."},{"ref":"BotArmy.LoadTest.html#get_bot_count/0","title":"BotArmy.LoadTest.get_bot_count/0","type":"function","doc":""},{"ref":"BotArmy.LoadTest.html#init/1","title":"BotArmy.LoadTest.init/1","type":"function","doc":"Invoked when the server is started. start_link/3 or start/3 will block until it returns. init_arg is the argument term (second argument) passed to start_link/3. Returning {:ok, state} will cause start_link/3 to return {:ok, pid} and the process to enter its loop. Returning {:ok, state, timeout} is similar to {:ok, state} except handle_info(:timeout, state) will be called after timeout milliseconds if no messages are received within the timeout. Returning {:ok, state, :hibernate} is similar to {:ok, state} except the process is hibernated before entering the loop. See c:handle_call/3 for more information on hibernation. Returning {:ok, state, {:continue, continue}} is similar to {:ok, state} except that immediately after entering the loop the c:handle_continue/2 callback will be invoked with the value continue as first argument. Returning :ignore will cause start_link/3 to return :ignore and the process will exit normally without entering the loop or calling c:terminate/2. If used when part of a supervision tree the parent supervisor will not fail to start nor immediately try to restart the GenServer. The remainder of the supervision tree will be started and so the GenServer should not be required by other processes. It can be started later with Supervisor.restart_child/2 as the child specification is saved in the parent supervisor. The main use cases for this are: The GenServer is disabled by configuration but might be enabled later. An error occurred and it will be handled by a different mechanism than the Supervisor. Likely this approach involves calling Supervisor.restart_child/2 after a delay to attempt a restart. Returning {:stop, reason} will cause start_link/3 to return {:error, reason} and the process to exit with reason reason without entering the loop or calling c:terminate/2. Callback implementation for GenServer.init/1."},{"ref":"BotArmy.LoadTest.html#one_off/1","title":"BotArmy.LoadTest.one_off/1","type":"function","doc":"Run just one bot and stop when finished. Useful for testing a bot out, or running a bot as a &quot;task.&quot; Opts map: tree - [required] the tree defining the work to be done. bot - [optional] a custom callback module implementing BotArmy.Bot, otherwise uses BotArmy.Bot.Default This wraps the provided tree so that it either errors if it fails, or performs BotArmy.Actions.done if it succeeds. This guarantees the tree won&#39;t run more than once (unless you intentionally create a loop using one of the repeat nodes)."},{"ref":"BotArmy.LoadTest.html#run/1","title":"BotArmy.LoadTest.run/1","type":"function","doc":"Starts up the bots. Opts map: n - [optional] the number of bots to start up (defaults to 1) tree - [required] the behavior tree for the bots to use bot - [optional] a custom callback module implementing BotArmy.Bot, otherwise uses BotArmy.Bot.Default Note that you cannot call this if bots are already running (call BotArmy.LoadTest.stop first)."},{"ref":"BotArmy.LoadTest.html#start_link/1","title":"BotArmy.LoadTest.start_link/1","type":"function","doc":""},{"ref":"BotArmy.LoadTest.html#stop/0","title":"BotArmy.LoadTest.stop/0","type":"function","doc":""},{"ref":"BotArmy.Metrics.html","title":"BotArmy.Metrics","type":"module","doc":"Stores information during the but run for metrics gathering."},{"ref":"BotArmy.Metrics.html#child_spec/1","title":"BotArmy.Metrics.child_spec/1","type":"function","doc":"Returns a specification to start this module under a supervisor. See Supervisor."},{"ref":"BotArmy.Metrics.html#get_state/0","title":"BotArmy.Metrics.get_state/0","type":"function","doc":""},{"ref":"BotArmy.Metrics.html#init/1","title":"BotArmy.Metrics.init/1","type":"function","doc":"Invoked when the server is started. start_link/3 or start/3 will block until it returns. init_arg is the argument term (second argument) passed to start_link/3. Returning {:ok, state} will cause start_link/3 to return {:ok, pid} and the process to enter its loop. Returning {:ok, state, timeout} is similar to {:ok, state} except handle_info(:timeout, state) will be called after timeout milliseconds if no messages are received within the timeout. Returning {:ok, state, :hibernate} is similar to {:ok, state} except the process is hibernated before entering the loop. See c:handle_call/3 for more information on hibernation. Returning {:ok, state, {:continue, continue}} is similar to {:ok, state} except that immediately after entering the loop the c:handle_continue/2 callback will be invoked with the value continue as first argument. Returning :ignore will cause start_link/3 to return :ignore and the process will exit normally without entering the loop or calling c:terminate/2. If used when part of a supervision tree the parent supervisor will not fail to start nor immediately try to restart the GenServer. The remainder of the supervision tree will be started and so the GenServer should not be required by other processes. It can be started later with Supervisor.restart_child/2 as the child specification is saved in the parent supervisor. The main use cases for this are: The GenServer is disabled by configuration but might be enabled later. An error occurred and it will be handled by a different mechanism than the Supervisor. Likely this approach involves calling Supervisor.restart_child/2 after a delay to attempt a restart. Returning {:stop, reason} will cause start_link/3 to return {:error, reason} and the process to exit with reason reason without entering the loop or calling c:terminate/2. Callback implementation for GenServer.init/1."},{"ref":"BotArmy.Metrics.html#run/1","title":"BotArmy.Metrics.run/1","type":"function","doc":""},{"ref":"BotArmy.Metrics.html#start_link/1","title":"BotArmy.Metrics.start_link/1","type":"function","doc":""},{"ref":"BotArmy.Metrics.Export.html","title":"BotArmy.Metrics.Export","type":"module","doc":"Formats metrics data for export (via the /metrics http endpoint)"},{"ref":"BotArmy.Metrics.Export.html#generate_report/0","title":"BotArmy.Metrics.Export.generate_report/0","type":"function","doc":""},{"ref":"BotArmy.Metrics.SummaryReport.html","title":"BotArmy.Metrics.SummaryReport","type":"module","doc":"Prints out a helpful summary about a bot run"},{"ref":"BotArmy.Metrics.SummaryReport.html#build_report/0","title":"BotArmy.Metrics.SummaryReport.build_report/0","type":"function","doc":""},{"ref":"BotArmy.Router.html","title":"BotArmy.Router","type":"module","doc":"The exposed HTTP routes for communiating with the bots. The parameters are similar to the docs in the mix tasks under mix/tasks."},{"ref":"BotArmy.Router.html#call/2","title":"BotArmy.Router.call/2","type":"function","doc":"Callback implementation for Plug.call/2."},{"ref":"BotArmy.Router.html#init/1","title":"BotArmy.Router.init/1","type":"function","doc":"Callback implementation for Plug.init/1."},{"ref":"BotArmy.SharedData.html","title":"BotArmy.SharedData","type":"module","doc":"While the &quot;context&quot; lets you share state between actions, SharedData lets you share state between bots. In addition, it is a central place to hold global data, like runtime config data. This module is a simple wrapper around a basic ETS table. As noted above, the runner tasks/router will store runtime config here as well. Note that this does not supply any kind of locking mechanism, so be aware of race conditions. This is by design for two reasons. First, config is a read-only use case. Second, for data-sharing, bots represent users, which operate independently of each other in real life with async data sharing patterns (email, slack)."},{"ref":"BotArmy.SharedData.html#child_spec/1","title":"BotArmy.SharedData.child_spec/1","type":"function","doc":"Returns a specification to start this module under a supervisor. See Supervisor."},{"ref":"BotArmy.SharedData.html#get/1","title":"BotArmy.SharedData.get/1","type":"function","doc":"Get a value by key (returns nil if not found)"},{"ref":"BotArmy.SharedData.html#put/2","title":"BotArmy.SharedData.put/2","type":"function","doc":"Put a value by key."},{"ref":"BotArmy.SharedData.html#update/2","title":"BotArmy.SharedData.update/2","type":"function","doc":"Update a value by key. update_fn is val -&gt; val."},{"ref":"Mix.Tasks.Bots.IntegrationTest.html","title":"Mix.Tasks.Bots.IntegrationTest","type":"task","doc":"Runs integration tests in an iex context, logging the result and returning an appropriate exit code. Parameters: v - [optional] &quot;Verbose&quot;, this will log more and print out all bot actions to the console (in addition to the log file). Recommended on CI to help debug. workflow - [required] The full name of the module defining the integration workflow (must be in scope). Must implement BotArmy.IntegrationTest.Workflow. Ex: &quot;MyService.Workflow.Simple&quot; bot - [optional] A custom callback module implementing BotArmy.Bot, otherwise uses BotArmy.Bot.Default custom - [optional] Configs for your custom domain. You must specify these in quotes as an Elixir map or keyword list (ex: --custom &#39;[host: &quot;dev&quot;]&#39;). Each key/value pair will be placed into BotArmy.SharedDAta for access in your actions, and other custom code."},{"ref":"Mix.Tasks.Bots.IntegrationTest.html#run/1","title":"Mix.Tasks.Bots.IntegrationTest.run/1","type":"function","doc":"A task needs to implement run which receives a list of command line args. Callback implementation for Mix.Task.run/1."},{"ref":"Mix.Tasks.Bots.LoadTest.html","title":"Mix.Tasks.Bots.LoadTest","type":"task","doc":"Task to run the bots. Can call with various flags. Opens an interactive window to control the bots, and prints a nice summary at the end. Supported arguments: n number of bots, defaults to 10 tree - [required] The full name of the module defining the integration test tree (must be in scope). Must expose the function tree/0. Ex: &quot;MyService.Workflow.Simple&quot; bot - [optional] A custom callback module implementing BotArmy.Bot, otherwise uses BotArmy.Bot.Default custom - [optional] Configs for your custom domain. You must specify these in quotes as an Elixir map or keyword list (ex: --custom &#39;[host: &quot;dev&quot;]&#39;). Each key/value pair will be placed into BotArmy.SharedDAta for access in your actions, and other custom code."},{"ref":"Mix.Tasks.Bots.LoadTest.html#run/1","title":"Mix.Tasks.Bots.LoadTest.run/1","type":"function","doc":"A task needs to implement run which receives a list of command line args. Callback implementation for Mix.Task.run/1."},{"ref":"Mix.Tasks.LoadTestRelease.html","title":"Mix.Tasks.LoadTestRelease","type":"task","doc":"Intended to be used with Distillery releases, not invoked directly, see Mix.Tasks.LoadTest to run locally and for docs. There is also an http route option."},{"ref":"Mix.Tasks.LoadTestRelease.html#run/1","title":"Mix.Tasks.LoadTestRelease.run/1","type":"function","doc":"A task needs to implement run which receives a list of command line args. Callback implementation for Mix.Task.run/1."},{"ref":"TermParser.html","title":"TermParser","type":"module","doc":"Taken verbatim from https://gist.github.com/mmmries/b657c77845b07ee8cd34."},{"ref":"TermParser.html#parse/1","title":"TermParser.parse/1","type":"function","doc":""},{"ref":"readme.html","title":"Bot Army","type":"extras","doc":"Bot Army A framework for building and running &quot;bots&quot; for load testing and integration testing. Bots are defined by Behavior Trees to replicate different user sequences. This package is a generic runner. It works in conjunction with domain specific bots that you define in the service you want to test."},{"ref":"readme.html#behavior-what","title":"Bot Army - Behavior what?","type":"extras","doc":"Behavior trees. It&#39;s a nifty way to declaratively express complex and variable sequences of actions. Most importantly, they are composable, which makes them easy to work with, and easy to scale. Read up on the docs or Watch a video. Bots look like this: # in MyService.Workflow.Simple def tree do BehaviorTree.Node.sequence([ BotArmy.Actions.action(MyService.Actions, :get_ready), BotArmy.Actions.action(BotArmy.Actions, :wait, [5]), BehaviorTree.Node.select([ BotArmy.Actions.action(MyService.Actions, :try_something, [42]), BotArmy.Actions.action(MyService.Actions, :try_something_else), BotArmy.Actions.action(BotArmy.Actions, :error, [&quot;Darn, didn&#39;t work!&quot;]) ]), MyService.Workflow.DifficultWork.tree(), BotArmy.Actions.action(BotArmy.Actions, :done) ]) end # in MyService.Actions def get_ready(context) do {id: id} = set_up() {:succeed, id: id} # adds `id` to the context for future actions to use end def try_something(context, magic_number) do case do_it(context.id, magic_number) do {:ok, _} -&gt; :succeed {:error, _} -&gt; :fail end end def try_something_else(context), do: ... See BotArmy.Bot and BotArmy.BotManager and BotArmy.Actions for more details."},{"ref":"readme.html#release-the-bots","title":"Bot Army - Release the bots!","type":"extras","doc":"Run the bots with mix bots.load_test: mix bots.load_test --n 100 --tree MyService.Workflow.Simple"},{"ref":"readme.html#integration-testing","title":"Bot Army - Integration testing","type":"extras","doc":"The bots can double as an integration testing system, which you can integrate into your CI pipeline. You can run the integration tests directly by running mix bots.integration_test. You can also use the integration/start endpoint (see below). The supplied callback_url will be POSTed to with the results as :ok or {:error, reason}."},{"ref":"readme.html#logging","title":"Bot Army - Logging","type":"extras","doc":"Logs are shunted to the ./bot_run.log file. It&#39;s hard to keep up with thousands of bots. The logs help, but need to be analyzed in meaningful ways. Using lnav to view the bot_run.log file is extremely useful. One useful approach is simply to find where errors occurred, but making use of the SQL feature can give very useful metrics. Try these queries for example (note that the key words are auto-derived from the log format): # list how many times each action ran ;select count(action_0), action_0 from logline group by action_0 #see how long actions took on aggregate ;select min(duration), mode(duration), max(duration), avg(duration), action_0 from logline group by action_0 order by avg(duration) desc # Show count and duration for each distinct action attempted by the bots, grouped by success or failure. ;select count(action_0), avg(duration), outcome, action_0, outcome from logline group by outcome, action_0 # list actions with their num of failures and errors and success rate ;SELECT action_0,count(*) as runs,count(CASE outcome WHEN &quot;fail&quot; then 1 end) as fails,count(CASE WHEN outcome LIKE &quot;error%&quot; then 1 end) as errors,round(100 * (count(CASE outcome WHEN &quot;succeed&quot; then 1 end)) / count(*)) as success_rate FROM logline group by action_0 order by success_rate desc # list average number of times bots perform each action (for the duration of the logs queried) ;select action_0, avg(runs) from (select bot_id, action_0, count(*) runs from logline group by bot_id, action_0) group by action_0 order by avg(runs) desc lnav also offers some nice filtering options. For example: # Show only log lines where with a duration value of 1000ms or larger. :filter-in duration=\\d{4,}ms"},{"ref":"readme.html#metrics-schema","title":"Bot Army - Metrics schema","type":"extras","doc":"During the course of a run a Bot will generate information pertaining to their activity in a system. In order to communicate this information with the outside world a BotManager will retain information about an ongoing attack which conforms to the following schema. { bot_count: ..., total_error_count: ..., actions: { &lt;action_name&gt;: { duration (running average): ..., success_count: ..., error_count: ... } } } Where bot_count is expected to change over the course of a run and represents a point in time count of the number of bots currently alive. actions is a map whose keys are the name of the action and whose value is a map containing key value pairs with the following information: The running average duration the given action has taken to complete, the number of successful invocations of the given action, and the number of errors encountered when running the given action. total_error_count is the aggregate of all errors reported by the bots. This can be used to catch any lurking problems not directly reported via the actions error counts."},{"ref":"readme.html#communicating-with-the-bots-from-outside","title":"Bot Army - Communicating with the bots from outside","type":"extras","doc":"The bots expose a simple HTTP api on port 8124. You can use the following routes: POST [host]:8124/load_test/start (same params as mix bots.load_test) POST [host]:8124/integration_test/start (same params as mix bots.integration_test, plus id and callback_url) DELETE [host]:8124/load_test/stop DELETE [host]:8124/integration_test/stop GET [host]:8124/metrics GET [host]:8124/logs"},{"ref":"readme.html#are-there-tests","title":"Bot Army - Are there tests?","type":"extras","doc":"Who tests the tests? Some. Run make test. Releasing for AWS EC2 If you want to make a release for another OS system, you can use docker. There is a Dockerfile set up for running elixir on Linux (for EC2). Build the Docker image if needed with docker build . -t amazon-elixir-bot-army. Run docker run -v $(pwd):/opt/build --rm -it amazon-elixir-bot-army:latest /opt/build/scripts/build_for_docker. This will put the tarball release file in rel/artifacts/amazonlinux/bot_army-0.1.0.tar.gz, which you can copy to EC2."}]