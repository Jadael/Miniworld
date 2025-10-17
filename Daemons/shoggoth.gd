# A COMPUTER CAN NEVER BE HELD ACCOUNTABLE
# THEREFORE A COMPUTER MUST NEVER MAKE A MANAGEMENT DECISION
# shoggoth.gd
extends Node

## Shoggoth: Daemon of AI Management and Abstraction
##
## Shoggoth serves as the central coordinator for AI-related tasks.
## It provides a clean, transparent API abstraction for LLM compute, handling all backend
## complexity so that users, daemons, and code can access "raw LLM compute" without worrying
## about implementation details.
##
## Responsibilities:
## 1. Managing and queueing AI task execution for orderly processing
## 2. Providing a simplified interface for other daemons to request AI services
## 3. Handling HTTP communication with Ollama API (localhost:11434)
## 4. Managing configuration (model selection, host, temperature, etc.)
## 5. Emitting signals to inform other entities about the status of AI operations
##
## Current Backend: Ollama API via ollama_client.gd
## Default Model: gemma3:27b
##
## Shoggoth is the guardian between mortal code and eldritch machine learning,
## ensuring that the cosmic energies of AI are channeled safely and efficiently.

## Emitted when a queued task completes successfully
## task_id: Unique identifier for the completed task
## result: The generated text response from the LLM
signal task_completed(task_id: String, result: String)

## Emitted when a task fails after all retries exhausted
## task_id: Unique identifier for the failed task
## error: Human-readable error message describing the failure
signal task_failed(task_id: String, error: String)

## Emitted after initialization completes
## llm_success: True if LLM backend is available and responding, false otherwise
signal models_initialized(llm_success: bool)

## Path to the configuration file storing Ollama settings
const CONFIG_FILE = "user://shoggoth_config.cfg"

## Simple prompt used to test LLM connectivity during initialization
const INIT_TEST_PROMPT = "Please say only `test`."

## Maximum number of retry attempts for failed tasks before giving up
const MAX_RETRIES = 3

## Delay in seconds between retry attempts
const RETRY_DELAY = 1.0


## Reference to the OllamaClient node that handles HTTP communication with Ollama API
var ollama_client: Node  # Type: OllamaClient (loaded dynamically)

## Queue of pending tasks waiting to be processed
## Each task is a Dictionary containing:
## - id: String - Unique task identifier
## - mode: String - Either "generate" or "chat"
## - prompt: String (for generate mode) - The text prompt
## - messages: Array (for chat mode) - Array of message dictionaries
## - parameters: Dictionary - Optional parameters (temperature, max_tokens, etc.)
var task_queue: Array[Dictionary] = []

## The task currently being processed (empty Dictionary when idle)
var current_task: Dictionary = {}

## True when actively processing a task
var is_processing_task: bool = false

## True during the initialization phase (testing LLM connectivity)
var is_initializing: bool = false

## Configuration manager for persistent Ollama settings
var config: ConfigFile

## Current retry attempt for the active task (0 = first attempt)
var retry_count: int = 0

## Dictionary mapping task_id to callback functions for async operations
## task_id (String) → callback (Callable)
var pending_callbacks: Dictionary = {}

func _ready() -> void:
	"""Initialize Shoggoth daemon on scene load.

	Loads configuration, sets up the Ollama client, and begins model initialization.
	Initialization is deferred to ensure all autoloads are ready.
	"""
	#Chronicler.log_event(self, "initialization_started", {})
	_load_or_create_config()
	_setup_ollama_client()
	call_deferred("_initialize_models")
	#Chronicler.log_event(self, "initialization_completed", {})

func _load_or_create_config() -> void:
	"""Load existing configuration or create default if none exists.

	Attempts to load the config file from user:// directory. If the file doesn't
	exist or fails to load, creates a new config with sensible defaults.
	"""
	config = ConfigFile.new()
	var err = config.load(CONFIG_FILE)
	if err != OK:
		#Chronicler.log_event(self, "config_load_failed", {"error": err})
		_create_default_config()

func _create_default_config() -> void:
	"""Create and save a new configuration file with default Ollama settings.

	Default configuration:
	- host: http://localhost:11434 (standard Ollama port)
	- model: gemma3:4b (faster model for testing)
	- temperature: 0.9 (high temperature, which hopefully blends with the caffolding for long-term behaviors)
	- max_tokens: 32765 (generous response length for local inference)
	- stop_tokens: [] (no custom stop sequences)

	Notes:
		max_tokens set to 32765 since we're running local inference and can afford
		longer responses. This prevents AI agents from getting cut off mid-thought.
		Using gemma3:4b for faster inference during development/testing.
	"""
	config.set_value("ollama", "host", "http://localhost:11434")
	config.set_value("ollama", "model", "gemma3:4b")
	config.set_value("ollama", "temperature", 0.9)
	config.set_value("ollama", "max_tokens", 32765)
	config.set_value("ollama", "stop_tokens", [])
	config.save(CONFIG_FILE)
	#Chronicler.log_event(self, "default_config_created", {})

func _setup_ollama_client() -> void:
	"""Dynamically load and initialize the OllamaClient node.

	Creates an instance of ollama_client.gd, adds it as a child node, and connects
	its signals to our handlers. If the script can't be loaded, LLM features are
	gracefully disabled.
	"""
	# Load and initialize ollama_client
	var ollama_script = load("res://Daemons/ollama_client.gd")
	if ollama_script == null:
		push_warning("Shoggoth: ollama_client.gd not found - LLM features disabled")
		return

	ollama_client = ollama_script.new()
	add_child(ollama_client)
	ollama_client.generate_finished.connect(_on_generate_text_finished)
	ollama_client.generate_failed.connect(_on_generate_failed)
	ollama_client.embed_finished.connect(_on_embed_finished)
	ollama_client.embed_failed.connect(_on_embed_failed)
	print("Shoggoth: Ollama client initialized")

func _initialize_models() -> void:
	"""Test LLM connectivity by sending a simple prompt.

	Configures the Ollama client with settings from config file, then sends a test
	prompt to verify the LLM is responding. This prevents silent failures and ensures
	the system is ready before accepting real tasks.

	Notes:
		Emits models_initialized signal with success/failure status when complete.
		Sets is_initializing flag to prevent duplicate initialization attempts.
	"""
	if is_initializing:
		return

	is_initializing = true

	# Skip if ollama_client not available
	if ollama_client == null:
		push_warning("Shoggoth: Skipping LLM initialization - ollama_client not available")
		is_initializing = false
		models_initialized.emit(false)
		return

	var ollama_host = config.get_value("ollama", "host", "http://localhost:11434")
	var model_name = config.get_value("ollama", "model", "gemma3:4b")

	_configure_ollama_client(ollama_host, model_name)
	_run_initialization_test()

func _configure_ollama_client(ollama_host: String, model_name: String) -> void:
	"""Apply configuration settings to the Ollama client.

	Args:
		ollama_host: URL of the Ollama server (e.g., "http://localhost:11434")
		model_name: Name of the model to use (e.g., "gemma3:4b")
	"""
	if ollama_client == null:
		return
	ollama_client.set_host(ollama_host)
	ollama_client.set_model(model_name)
	var temperature = config.get_value("ollama", "temperature", 0.9)
	ollama_client.set_temperature(temperature)
	#Chronicler.log_event(self, "ollama_client_configured", {
	#	"host": ollama_host,
	#	"model": model_name,
	#	"temperature": temperature
	#})

func _run_initialization_test() -> void:
	"""Send a simple test prompt to verify LLM connectivity.

	Bypasses the task queue to avoid circular dependency during initialization.
	Uses a short token limit and zero temperature for deterministic results.

	Notes:
		The response is handled by _on_generate_text_finished which detects
		initialization mode and routes to _on_init_test_completed instead of
		normal task completion handling.
	"""
	print("[Shoggoth] Starting initialization test with prompt: '%s'" % INIT_TEST_PROMPT)

	if ollama_client == null:
		print("[Shoggoth] ERROR: ollama_client is null, cannot run init test")
		return

	print("[Shoggoth] Sending init test to Ollama...")
	# Run init test directly without queuing to avoid circular dependency
	ollama_client.generate(INIT_TEST_PROMPT, {"num_predict": 32, "temperature": 0.0})

func _on_init_test_completed(result: String) -> void:
	"""Handle completion of the initialization test.

	Args:
		result: The text response from the LLM (expected to be a greeting)

	Notes:
		Considers initialization successful if we receive any non-empty response.
		Emits models_initialized signal to notify other systems. If tasks were
		queued during initialization, begins processing them now.
	"""
	print("[Shoggoth] Init test completed with result: '%s'" % result)
	var llm_success = result.strip_edges() != ""
	print("[Shoggoth] LLM success: %s" % llm_success)
	models_initialized.emit(llm_success)

	#Chronicler.log_event(self, "models_initialized", {
	#	"llm_success": llm_success,
	#	"model": config.get_value("ollama", "model", "unknown") if config else "unknown",
	#	"init_test_prompt": INIT_TEST_PROMPT,
	#	"init_test_result": result
	#})

	is_initializing = false
	print("[Shoggoth] is_initializing set to false")

	# Now that initialization is complete, start processing any queued tasks
	print("[Shoggoth] Checking task queue: %d tasks, is_processing_task: %s" % [task_queue.size(), is_processing_task])
	if not task_queue.is_empty() and not is_processing_task:
		print("[Shoggoth] Starting to process queued tasks...")
		#Chronicler.log_event(self, "processing_queued_tasks_after_init", {
		#	"queue_length": task_queue.size()
		#})
		_process_next_task()

func set_model(model_name: String) -> void:
	"""Change the active LLM model and re-initialize.

	Args:
		model_name: Name of the Ollama model to use (e.g., "llama3:8b")

	Notes:
		Saves the new model to config and triggers re-initialization to test
		connectivity with the new model.
	"""
	config.set_value("ollama", "model", model_name)
	config.save(CONFIG_FILE)
	call_deferred("_initialize_models")
	#Chronicler.log_event(self, "model_updated", {"new_model": model_name})


func set_stop_tokens(tokens: Array) -> void:
	"""Set custom stop sequences that will halt generation.

	Args:
		tokens: Array of strings that should stop generation when encountered

	Notes:
		Stop tokens are saved to config and applied to all subsequent tasks.
		Useful for enforcing structured output formats.
	"""
	config.set_value("ollama", "stop_tokens", tokens)
	config.save(CONFIG_FILE)
	#Chronicler.log_event(self, "stop_tokens_updated", {"tokens": tokens})

func submit_task(prompt: String, parameters: Dictionary = {}) -> String:
	"""Submit a text completion task using Ollama's /api/generate endpoint.

	Args:
		prompt: The text prompt to send to the LLM
		parameters: Optional generation parameters
			- temperature: float (creativity level, 0.0-1.0)
			- max_length: int (maximum tokens to generate)
			- stop_tokens: Array[String] (sequences that halt generation)

	Returns:
		A unique task ID string that can be used to track completion via signals

	Notes:
		Tasks are queued and processed sequentially. Connect to task_completed
		or task_failed signals to receive results. If the queue is idle, processing
		begins immediately.
	"""
	var task_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	var task = {
		"id": task_id,
		"prompt": prompt,
		"parameters": parameters,
		"mode": "generate"
	}
	task_queue.append(task)

	#Chronicler.log_event(self, "task_submitted", {
	#	"task_id": task_id,
	#	"prompt_length": prompt.length(),
	#	"prompt": prompt,
	#	"parameters": parameters,
	#	"mode": "generate"
	#})

	if not is_processing_task:
		_process_next_task()

	return task_id

func submit_chat(messages: Array, parameters: Dictionary = {}) -> String:
	"""Submit a chat task with conversation history using Ollama's /api/chat endpoint.

	Args:
		messages: Array of message dictionaries, each containing:
			- role: String - Either "system", "user", or "assistant"
			- content: String - The message text
		parameters: Optional generation parameters (same as submit_task)

	Returns:
		A unique task ID string that can be used to track completion via signals

	Notes:
		The chat endpoint supports multi-turn conversations and system prompts.
		System messages are typically used to define personality or behavior.
		Message history helps maintain context across multiple exchanges.
	"""
	var task_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	var task = {
		"id": task_id,
		"messages": messages,
		"parameters": parameters,
		"mode": "chat"
	}
	task_queue.append(task)
	print("[Shoggoth] Chat task queued: %s (queue length: %d, is_processing: %s, is_initializing: %s)" % [task_id, task_queue.size(), is_processing_task, is_initializing])

	#Chronicler.log_event(self, "chat_submitted", {
	#	"task_id": task_id,
	#	"message_count": messages.size(),
	#	"parameters": parameters,
	#	"mode": "chat"
	#})

	if not is_processing_task:
		print("[Shoggoth] Attempting to process task immediately...")
		_process_next_task()

	return task_id

func _process_next_task() -> void:
	"""Process the next task in the queue.

	Retrieves the next task from the front of the queue, applies its parameters,
	and executes it via the Ollama client. Tasks are only processed if initialization
	is complete and the client is ready.

	Notes:
		Tasks are processed sequentially (one at a time) to avoid overwhelming the
		LLM backend. Processing begins automatically when tasks are submitted to an
		idle queue, or when the current task completes.
	"""
	print("[Shoggoth] _process_next_task called (queue: %d, is_processing: %s, is_initializing: %s)" % [task_queue.size(), is_processing_task, is_initializing])

	if task_queue.is_empty():
		is_processing_task = false
		current_task = {}
		print("[Shoggoth] Task queue empty, returning")
		return

	# Don't process tasks while still initializing or if client isn't ready
	if is_initializing or not ollama_client:
		print("[Shoggoth] Deferring task processing (is_initializing: %s, client_ready: %s)" % [is_initializing, ollama_client != null])
		#Chronicler.log_event(self, "task_processing_deferred", {
		#	"is_initializing": is_initializing,
		#	"client_ready": ollama_client != null,
		#	"queue_length": task_queue.size()
		#})
		is_processing_task = false
		return

	is_processing_task = true
	current_task = task_queue.pop_front()
	retry_count = 0
	print("[Shoggoth] Starting task: %s" % current_task.get("id", "unknown"))

	var options = _apply_task_parameters()
	_execute_current_task(options)

func _apply_task_parameters() -> Dictionary:
	"""Convert task parameters into Ollama API options format.

	Merges task-specific parameters with config defaults, translating from our
	generic parameter names to Ollama's specific option names. For example,
	"max_length" becomes "num_predict".

	Returns:
		Dictionary of options formatted for Ollama API (num_predict, temperature, stop, etc.)

	Notes:
		Task-specific parameters override config defaults. Unknown parameters are
		passed through unchanged in case Ollama supports them.
		Config defaults are applied first, then task parameters override them.
	"""
	var options = {}

	# Apply config defaults first
	if config:
		# Apply max_tokens from config as num_predict
		var max_tokens: int = config.get_value("ollama", "max_tokens", 32765)
		options["num_predict"] = max_tokens

		# Apply temperature from config
		var temperature: float = config.get_value("ollama", "temperature", 0.9)
		options["temperature"] = temperature

		# Get default stop tokens from config
		var stop_tokens: Array = config.get_value("ollama", "stop_tokens", [])
		if stop_tokens.size() > 0:
			options["stop"] = stop_tokens
	else:
		push_error("Shoggoth: Config is null in _apply_task_parameters - this should not happen!")
		#Chronicler.log_event(self, "config_null_error", {"function": "_apply_task_parameters"})

	# Safety check for parameters key
	if not current_task.has("parameters"):
		return options

	# Task-specific parameters override config defaults
	var parameters = current_task["parameters"] as Dictionary
	for key in parameters:
		match key:
			"stop_tokens":
				options["stop"] = parameters[key]
			"max_length":
				options["num_predict"] = parameters[key]
			"temperature":
				options["temperature"] = parameters[key]
			"num_predict":  # Allow direct override
				options["num_predict"] = parameters[key]
			_:
				# Pass through other options to Ollama
				options[key] = parameters[key]

	#Chronicler.log_event(self, "task_parameters_applied", {
	#	"task_id": current_task["id"],
	#	"options": options
	#})

	return options

func _execute_current_task(options: Dictionary) -> void:
	"""Execute the current task by calling the appropriate Ollama client method.

	Args:
		options: Dictionary of Ollama API options (from _apply_task_parameters)

	Notes:
		Routes to either ollama_client.generate() or ollama_client.chat() depending
		on the task mode. Validates that required keys (prompt/messages) are present
		before execution.

		For chat_async mode, resolves the prompt generator just-in-time to ensure
		maximum freshness of context and memories.
	"""
	# Safety check: ensure ollama_client is initialized
	if ollama_client == null:
		var error_msg = "Ollama client not initialized - cannot execute task"
		#Chronicler.log_event(self, "ollama_client_not_ready", {
		#	"task_id": current_task.get("id", "unknown")
		#})
		_handle_task_error(error_msg)
		return

	var mode = current_task.get("mode", "generate")

	if mode == "chat_async":
		# Just-in-time prompt generation for async tasks
		if not current_task.has("prompt_generator"):
			_handle_task_error("Async chat task missing 'prompt_generator' key")
			return

		var prompt_generator = current_task["prompt_generator"]
		var prompt_text: String = ""

		# Resolve prompt: either invoke Callable or use String directly
		if prompt_generator is Callable:
			print("[Shoggoth] Invoking prompt generator just-in-time for task: %s" % current_task.get("id", "unknown"))
			prompt_text = prompt_generator.call()
		elif prompt_generator is String:
			prompt_text = prompt_generator
		else:
			_handle_task_error("Async chat task prompt_generator must be String or Callable")
			return

		var system_prompt: String = current_task.get("system_prompt", "")

		# Build messages with fresh prompt
		var messages = [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": prompt_text}
		]

		ollama_client.chat(messages, options)

	elif mode == "chat":
		if not current_task.has("messages"):
			_handle_task_error("Chat task missing 'messages' key")
			return
		var messages = current_task["messages"] as Array
		ollama_client.chat(messages, options)
	elif mode == "embed":
		if not current_task.has("texts"):
			_handle_task_error("Embed task missing 'texts' key")
			return
		var texts = current_task["texts"]
		ollama_client.embed(texts)
	else:
		if not current_task.has("prompt"):
			_handle_task_error("Generate task missing 'prompt' key")
			return
		var prompt = current_task["prompt"] as String
		ollama_client.generate(prompt, options)

func _handle_task_error(error_message: String) -> void:
	"""Handle task execution failures with automatic retry logic.

	Args:
		error_message: Human-readable description of what went wrong

	Notes:
		Retries the task up to MAX_RETRIES times with RETRY_DELAY between attempts.
		If all retries are exhausted, emits task_failed signal and moves to next task.
	"""
	var task_id = current_task.get("id", "unknown")
	#Chronicler.log_event(self, "task_execution_failed", {
	#	"task_id": task_id,
	#	"error": error_message,
	#	"retry_count": retry_count
	#})

	if retry_count < MAX_RETRIES:
		retry_count += 1
		#Chronicler.log_event(self, "task_retry_scheduled", {
		#	"task_id": task_id,
		#	"retry_count": retry_count
		#})
		get_tree().create_timer(RETRY_DELAY).timeout.connect(_retry_current_task)
	else:
		task_failed.emit(task_id, error_message)
		current_task = {}
		_process_next_task()

func _retry_current_task() -> void:
	"""Retry the current task after a failure.

	Re-applies task parameters and re-executes. Called automatically after
	RETRY_DELAY when a task fails and retries remain.
	"""
	#Chronicler.log_event(self, "task_retry_started", {
	#	"task_id": current_task.get("id", "unknown"),
	#	"retry_count": retry_count
	#})
	var options = _apply_task_parameters()
	_execute_current_task(options)


func _on_generate_failed(error: String) -> void:
	"""Signal handler for ollama_client.generate_failed.

	Args:
		error: Error message from the Ollama client
	"""
	print("[Shoggoth] _on_generate_failed called with error: %s" % error)
	_handle_task_error("Ollama generation failed: " + error)

func _on_generate_text_finished(result: Dictionary) -> void:
	"""Signal handler for ollama_client.generate_finished.

	Args:
		result: Dictionary with keys:
			- content: String - The final answer/output from the model
			- thinking: String - Chain-of-thought reasoning (empty if not a reasoning model)

	Notes:
		Routes to _on_init_test_completed if still initializing, otherwise
		processes as a normal task completion. Applies stop token post-processing
		before emitting results.

		For reasoning models, the thinking content is stored in the agent's memory
		as if it were a THINK event, making the agent's internal reasoning visible
		and allowing it to be used for debugging or learning.

		CRITICAL: Next task processing is deferred to allow EventWeaver broadcasts
		from callbacks to propagate before building the next agent's prompt. This
		ensures agents see completed actions from other agents before "zoning out".
	"""
	var content: String = result.get("content", "")
	var thinking: String = result.get("thinking", "")

	print("[Shoggoth] _on_generate_text_finished called with content length: %d, thinking length: %d, is_initializing: %s" % [content.length(), thinking.length(), is_initializing])

	# If we're still initializing, this is the init test response
	if is_initializing:
		content = _process_result(content)
		_on_init_test_completed(content)
		return

	# Normal task completion
	if current_task.is_empty():
		print("[Shoggoth] WARNING: Received result but current_task is empty!")
		return

	print("[Shoggoth] Processing task completion for task: %s" % current_task.get("id", "unknown"))
	content = _process_result(content)

	# Store thinking content for potential use by callbacks (agents can save it to memory)
	if thinking != "":
		print("[Shoggoth] Task included %d chars of chain-of-thought reasoning" % thinking.length())
		# Pass both content and thinking to callback/signal
		_emit_task_completion(content, thinking)
	else:
		_emit_task_completion(content, "")

	current_task = {}

	# Defer next task processing to give events time to propagate
	# This ensures other agents observe completed actions before building their prompts
	call_deferred("_process_next_task")

func _process_result(result: String) -> String:
	"""Post-process LLM result to trim at stop tokens.

	Args:
		result: Raw text response from the LLM

	Returns:
		Processed result with content after the first stop token removed

	Notes:
		This provides a fallback in case Ollama's internal stop token handling
		doesn't catch everything. Truncates at the first occurrence of any
		configured stop token.
	"""
	# Ollama handles stop tokens internally, but we can do post-processing here if needed
	var stop_tokens = []
	if config:
		stop_tokens = config.get_value("ollama", "stop_tokens", [])

	for token in stop_tokens:
		var split_result = result.split(token)
		if split_result.size() > 1:
			result = split_result[0]
			break
	return result


func _emit_task_completion(result: String, thinking: String = "") -> void:
	"""Emit the task_completed signal with the current task's result.

	Args:
		result: The processed text response from the LLM
		thinking: Optional chain-of-thought reasoning content (for reasoning models)

	Notes:
		Also checks for and invokes any registered callbacks for this task_id,
		then removes them from pending_callbacks.

		For reasoning models, the thinking content is passed to callbacks as a
		second parameter if the callback accepts it. This allows agents to save
		the chain-of-thought reasoning to their memory.
	"""
	var task_id = current_task.get("id", "unknown")

	# Invoke callback if one is registered
	if pending_callbacks.has(task_id):
		var callback: Callable = pending_callbacks[task_id]
		pending_callbacks.erase(task_id)

		# Pass thinking content if available (for reasoning models)
		# Most callbacks only expect result, but we can pass thinking as optional 2nd param
		# The callback can choose to use it or ignore it
		if thinking != "":
			callback.call(result, thinking)
		else:
			callback.call(result)

	# Emit signal for other listeners (signal still uses String for backward compat)
	task_completed.emit(task_id, result)

func cancel_task(task_id: String) -> bool:
	"""Attempt to cancel a task by its ID.

	Args:
		task_id: The unique identifier returned by submit_task or submit_chat

	Returns:
		True if the task was found and cancelled, false otherwise

	Notes:
		Can cancel queued tasks (removes from queue) or the currently executing
		task (stops generation and moves to next task). Tasks that have already
		completed cannot be cancelled.
	"""
	for i in range(task_queue.size()):
		if task_queue[i].get("id") == task_id:
			task_queue.remove_at(i)
			#Chronicler.log_event(self, "task_cancelled", {"task_id": task_id})
			return true

	if is_processing_task and current_task.get("id") == task_id:
		if ollama_client != null:
			ollama_client.stop_generation()
		current_task = {}
		is_processing_task = false
		#Chronicler.log_event(self, "running_task_stopped", {"task_id": task_id})
		_process_next_task()
		return true

	return false


func get_queue_length() -> int:
	"""Get the total number of pending tasks.

	Returns:
		Count of queued tasks plus 1 if a task is currently processing
	"""
	return task_queue.size() + (1 if not current_task.is_empty() else 0)


func is_busy() -> bool:
	"""Check if Shoggoth is currently working on tasks.

	Returns:
		True if processing a task or has tasks queued, false if idle
	"""
	return is_processing_task or not task_queue.is_empty()

func generate_async(prompt: Variant, system_prompt: String, callback: Callable) -> String:
	"""Submit an async generation task with a callback function.

	Args:
		prompt: Either a String (prompt text) or a Callable that returns a String.
				If a Callable is provided, it will be invoked just-in-time when
				Shoggoth is ready to execute the task, ensuring maximum freshness.
		system_prompt: System instruction defining personality or behavior
		callback: A Callable that will be invoked with the result string

	Returns:
		The task ID, or empty string if LLM is unavailable

	Notes:
		Uses chat mode internally to support system prompts. The callback is
		stored in pending_callbacks and invoked by Shoggoth when the task completes.
		If LLM is unavailable, the callback is immediately called with an empty string.

		Passing a Callable for prompt is useful for AI agents that need the most
		up-to-date memories and observations when their task finally executes.
	"""
	if ollama_client == null:
		# No LLM available, call callback with empty string
		callback.call("")
		return ""

	# Store prompt as-is (String or Callable) - it will be resolved just-in-time
	var task_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	var task = {
		"id": task_id,
		"prompt_generator": prompt,  # Can be String or Callable
		"system_prompt": system_prompt,
		"mode": "chat_async",  # Special mode for just-in-time prompt generation
		"parameters": {}
	}
	task_queue.append(task)
	print("[Shoggoth] Async chat task queued: %s (queue length: %d, is_processing: %s, is_initializing: %s)" % [task_id, task_queue.size(), is_processing_task, is_initializing])

	# Register callback - Shoggoth will invoke it when task completes
	pending_callbacks[task_id] = callback

	if not is_processing_task:
		print("[Shoggoth] Attempting to process task immediately...")
		_process_next_task()

	return task_id


func generate_embeddings_async(texts: Variant, callback: Callable) -> String:
	"""Generate embeddings asynchronously with callback.

	Args:
		texts: String or Array[String] to embed
		callback: Callable(embeddings: Array) - receives Array of float arrays

	Returns:
		Task ID or empty string if unavailable
	"""
	if ollama_client == null:
		callback.call([])
		return ""

	var task_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	var task = {
		"id": task_id,
		"texts": texts,
		"mode": "embed",
		"parameters": {}
	}
	task_queue.append(task)
	pending_callbacks[task_id] = callback

	if not is_processing_task:
		_process_next_task()

	return task_id


func _on_embed_finished(embeddings: Array) -> void:
	"""Handle embedding completion from ollama_client."""
	if current_task.is_empty():
		return

	var task_id = current_task.get("id", "unknown")

	# Invoke callback
	if pending_callbacks.has(task_id):
		var callback: Callable = pending_callbacks[task_id]
		pending_callbacks.erase(task_id)
		callback.call(embeddings)

	current_task = {}

	# Defer next task processing to give events time to propagate
	call_deferred("_process_next_task")


func _on_embed_failed(error: String) -> void:
	"""Handle embedding failure."""
	print("[Shoggoth] Embedding failed: %s" % error)
	_handle_task_error("Embedding failed: " + error)


func test_connection() -> void:
	"""Public method to test LLM connectivity.

	Triggers a test prompt to verify Ollama is responding with current
	configuration. Results are emitted via models_initialized signal.

	Notes:
		This is exposed for UI/admin tooling to test configuration changes.
	"""
	_run_initialization_test()


func reset_config() -> void:
	"""Delete the config file and recreate with defaults.

	Useful for recovering from corrupted config or resetting to known state.
	After resetting, triggers re-initialization with new default settings.
	"""
	var dir = DirAccess.open("user://")
	if dir:
		dir.remove("shoggoth_config.cfg")

	_create_default_config()
	call_deferred("_initialize_models")
	print("[Shoggoth] Config reset to defaults: gemma3:27b")


func get_config_file_path() -> String:
	"""Get the absolute filesystem path to the config file.

	Returns:
		Full path to shoggoth_config.cfg for manual editing

	Notes:
		Useful for debugging or providing users with config file location
	"""
	return ProjectSettings.globalize_path(CONFIG_FILE)


# TODO: Add support for streaming responses from Ollama
# TODO: Add support for different types of AI tasks (e.g., embeddings, or text continuation with base models)
# TODO: More sophisticated prioritization system - local GPUs can usually only run one inference at a time, and most responses take 6-12 seconds.
# TODO: Consider implementing backend switching (Ollama, OpenAI-compatible APIs, etc.)
