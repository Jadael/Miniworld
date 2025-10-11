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
## Default Model: mistral-small:24b
##
## Shoggoth is the guardian between mortal code and eldritch machine learning,
## ensuring that the cosmic energies of AI are channeled safely and efficiently.

signal task_completed(task_id: String, result: String)
signal task_failed(task_id: String, error: String)
signal models_initialized(llm_success: bool)

const CONFIG_FILE = "user://shoggoth_config.cfg"
const INIT_TEST_PROMPT = "Say hello!"
const MAX_RETRIES = 3
const RETRY_DELAY = 1.0  # seconds

var ollama_client: Node  # OllamaClient
var task_queue: Array[Dictionary] = []
var current_task: Dictionary = {}
var is_processing_task: bool = false
var is_initializing: bool = false
var config: ConfigFile
var retry_count: int = 0

func _ready() -> void:
	#Chronicler.log_event(self, "initialization_started", {})
	_load_or_create_config()
	_setup_ollama_client()
	call_deferred("_initialize_models")
	#Chronicler.log_event(self, "initialization_completed", {})

func _load_or_create_config() -> void:
	config = ConfigFile.new()
	var err = config.load(CONFIG_FILE)
	if err != OK:
		#Chronicler.log_event(self, "config_load_failed", {"error": err})
		_create_default_config()

func _create_default_config() -> void:
	config.set_value("ollama", "host", "http://localhost:11434")
	config.set_value("ollama", "model", "mistral-small:24b")
	config.set_value("ollama", "temperature", 0.7)
	config.set_value("ollama", "max_tokens", 2048)
	config.set_value("ollama", "stop_tokens", [])
	config.save(CONFIG_FILE)
	#Chronicler.log_event(self, "default_config_created", {})

func _setup_ollama_client() -> void:
	# Load and initialize ollama_client
	var ollama_script = load("res://Daemons/ollama_client.gd")
	if ollama_script == null:
		push_warning("Shoggoth: ollama_client.gd not found - LLM features disabled")
		return

	ollama_client = ollama_script.new()
	add_child(ollama_client)
	ollama_client.generate_finished.connect(_on_generate_text_finished)
	ollama_client.generate_failed.connect(_on_generate_failed)
	print("Shoggoth: Ollama client initialized")

func _initialize_models() -> void:
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
	var model_name = config.get_value("ollama", "model", "mistral-small:24b")

	_configure_ollama_client(ollama_host, model_name)
	_run_initialization_test()

func _configure_ollama_client(ollama_host: String, model_name: String) -> void:
	if ollama_client == null:
		return
	ollama_client.set_host(ollama_host)
	ollama_client.set_model(model_name)
	var temperature = config.get_value("ollama", "temperature", 0.7)
	ollama_client.set_temperature(temperature)
	#Chronicler.log_event(self, "ollama_client_configured", {
	#	"host": ollama_host,
	#	"model": model_name,
	#	"temperature": temperature
	#})

func _run_initialization_test() -> void:
	#Chronicler.log_event(self, "initialization_test_started", {})

	if ollama_client == null:
		return
	# Run init test directly without queuing to avoid circular dependency
	ollama_client.generate(INIT_TEST_PROMPT, {"num_predict": 32, "temperature": 0.0})

func _on_init_test_completed(result: String) -> void:
	var llm_success = result.strip_edges() != ""
	models_initialized.emit(llm_success)

	#Chronicler.log_event(self, "models_initialized", {
	#	"llm_success": llm_success,
	#	"model": config.get_value("ollama", "model", "unknown") if config else "unknown",
	#	"init_test_prompt": INIT_TEST_PROMPT,
	#	"init_test_result": result
	#})

	is_initializing = false

	# Now that initialization is complete, start processing any queued tasks
	if not task_queue.is_empty() and not is_processing_task:
		#Chronicler.log_event(self, "processing_queued_tasks_after_init", {
		#	"queue_length": task_queue.size()
		#})
		_process_next_task()

func set_model(model_name: String) -> void:
	config.set_value("ollama", "model", model_name)
	config.save(CONFIG_FILE)
	call_deferred("_initialize_models")
	#Chronicler.log_event(self, "model_updated", {"new_model": model_name})

func set_stop_tokens(tokens: Array) -> void:
	config.set_value("ollama", "stop_tokens", tokens)
	config.save(CONFIG_FILE)
	#Chronicler.log_event(self, "stop_tokens_updated", {"tokens": tokens})

## Submit a text completion task (uses /api/generate)
func submit_task(prompt: String, parameters: Dictionary = {}) -> String:
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

## Submit a chat task with message history (uses /api/chat)
## messages: Array of {role: "user"|"assistant"|"system", content: "text"}
func submit_chat(messages: Array, parameters: Dictionary = {}) -> String:
	var task_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	var task = {
		"id": task_id,
		"messages": messages,
		"parameters": parameters,
		"mode": "chat"
	}
	task_queue.append(task)

	#Chronicler.log_event(self, "chat_submitted", {
	#	"task_id": task_id,
	#	"message_count": messages.size(),
	#	"parameters": parameters,
	#	"mode": "chat"
	#})

	if not is_processing_task:
		_process_next_task()

	return task_id

func _process_next_task() -> void:
	if task_queue.is_empty():
		is_processing_task = false
		current_task = {}
		return

	# Don't process tasks while still initializing or if client isn't ready
	if is_initializing or not ollama_client:
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

	var options = _apply_task_parameters()
	_execute_current_task(options)

func _apply_task_parameters() -> Dictionary:
	var options = {}

	# Get default stop tokens from config
	var stop_tokens = []
	if config:
		stop_tokens = config.get_value("ollama", "stop_tokens", [])
	else:
		push_error("Shoggoth: Config is null in _apply_task_parameters - this should not happen!")
		#Chronicler.log_event(self, "config_null_error", {"function": "_apply_task_parameters"})

	# Safety check for parameters key
	if not current_task.has("parameters"):
		return options

	var parameters = current_task["parameters"] as Dictionary
	for key in parameters:
		match key:
			"stop_tokens":
				stop_tokens = parameters[key]
			"max_length":
				options["num_predict"] = parameters[key]
			"temperature":
				options["temperature"] = parameters[key]
			_:
				# Pass through other options to Ollama
				options[key] = parameters[key]

	if stop_tokens.size() > 0:
		options["stop"] = stop_tokens

	#Chronicler.log_event(self, "task_parameters_applied", {
	#	"task_id": current_task["id"],
	#	"options": options
	#})

	return options

func _execute_current_task(options: Dictionary) -> void:
	# Safety check: ensure ollama_client is initialized
	if ollama_client == null:
		var error_msg = "Ollama client not initialized - cannot execute task"
		#Chronicler.log_event(self, "ollama_client_not_ready", {
		#	"task_id": current_task.get("id", "unknown")
		#})
		_handle_task_error(error_msg)
		return

	var mode = current_task.get("mode", "generate")

	if mode == "chat":
		if not current_task.has("messages"):
			_handle_task_error("Chat task missing 'messages' key")
			return
		var messages = current_task["messages"] as Array
		ollama_client.chat(messages, options)
	else:
		if not current_task.has("prompt"):
			_handle_task_error("Generate task missing 'prompt' key")
			return
		var prompt = current_task["prompt"] as String
		ollama_client.generate(prompt, options)

func _handle_task_error(error_message: String) -> void:
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
	#Chronicler.log_event(self, "task_retry_started", {
	#	"task_id": current_task.get("id", "unknown"),
	#	"retry_count": retry_count
	#})
	var options = _apply_task_parameters()
	_execute_current_task(options)

func _on_generate_failed(error: String) -> void:
	_handle_task_error("Ollama generation failed: " + error)

func _on_generate_text_finished(result: String) -> void:
	# If we're still initializing, this is the init test response
	if is_initializing:
		result = _process_result(result)
		_on_init_test_completed(result)
		return

	# Normal task completion
	if current_task.is_empty():
		#Chronicler.log_event(self, "unexpected_task_completion", {
		#	"result_length": result.length(),
		#	"result": result
		#})
		return

	result = _process_result(result)
	_emit_task_completion(result)

	current_task = {}
	_process_next_task()

func _process_result(result: String) -> String:
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

func _emit_task_completion(result: String) -> void:
	var task_id = current_task.get("id", "unknown")
	#Chronicler.log_event(self, "task_completed", {
	#	"task_id": task_id,
	#	"result_length": result.length(),
	#	"result": result
	#})
	task_completed.emit(task_id, result)

func cancel_task(task_id: String) -> bool:
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
	return task_queue.size() + (1 if not current_task.is_empty() else 0)

func is_busy() -> bool:
	return is_processing_task or not task_queue.is_empty()

## Generate text asynchronously with callback
## prompt: The text prompt
## system_prompt: System instruction (profile/personality)
## callback: Callable to call with result
func generate_async(prompt: String, system_prompt: String, callback: Callable) -> String:
	"""Submit an async generation task and call the callback when done"""
	if ollama_client == null:
		# No LLM available, call callback with empty string
		callback.call("")
		return ""

	# Use chat mode to include system prompt
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": prompt}
	]

	var task_id = submit_chat(messages)

	# Connect to task completion with a wrapper that auto-disconnects
	var on_complete: Callable
	on_complete = func(completed_task_id: String, result: String):
		if completed_task_id == task_id:
			# Call the callback
			callback.call(result)
			# Disconnect
			task_completed.disconnect(on_complete)

	task_completed.connect(on_complete)

	return task_id

# TODO: Add support for streaming responses from Ollama
# TODO: Add support for different types of AI tasks (e.g., embeddings, or text continuation with base models)
# TODO: More sophisticated prioritization system - local GPUs can usually only run one inference at a time, and most responses take 6-12 seconds.
# TODO: Consider implementing backend switching (Ollama, OpenAI-compatible APIs, etc.)
