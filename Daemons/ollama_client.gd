## OllamaClient: HTTP interface to Ollama API
##
## Handles low-level HTTP communication with the Ollama API server.
## Provides methods for both text generation (/api/generate) and chat (/api/chat)
## endpoints, with automatic JSON serialization and response parsing.
##
## Responsibilities:
## - Managing HTTP requests to Ollama server
## - Serializing request payloads to JSON
## - Parsing JSON responses and extracting generated text
## - Emitting signals for success/failure cases
## - Handling request cancellation
##
## This is a lower-level daemon used by Shoggoth. Most code should interact
## with Shoggoth instead of calling OllamaClient directly.
##
## Dependencies:
## - Requires Ollama running at the configured host (default: http://localhost:11434)

extends Node

## Emitted when text generation completes successfully
## result: The generated text extracted from the API response
signal generate_finished(result: String)

## Emitted when generation fails due to network, HTTP, or parsing errors
## error: Human-readable error message describing the failure
signal generate_failed(error: String)

## Emitted when embedding generation completes successfully
## embeddings: Array of Arrays (each inner array is a float vector)
signal embed_finished(embeddings: Array)

## Emitted when embedding generation fails
## error: Human-readable error message
signal embed_failed(error: String)

## URL of the Ollama API server
var host: String = "http://localhost:11434"

## Name of the Ollama model to use for generation (e.g., "llama3:8b", "mistral:latest")
var model: String = "gemma3:27b"

## Name of the Ollama model to use for embeddings (e.g., "embeddinggemma", "all-minilm")
var embedding_model: String = "embeddinggemma"

## Default temperature for generation (0.0 = deterministic, 1.0 = creative)
var temperature: float = 0.9


## HTTPRequest node used for making API calls
var http_request: HTTPRequest

## Accumulated response text (currently unused, responses are non-streaming)
var current_response: String = ""

## True when a request is in flight, false when idle
var is_generating: bool = false

## Type of current request: "generate", "chat", or "embed"
var current_request_type: String = ""

func _ready() -> void:
	"""Initialize the HTTP request node and connect signals.

	Creates an HTTPRequest node as a child and connects its request_completed
	signal to our response handler.

	Notes:
		Sets body_size_limit to -1 (unlimited) and download_chunk_size to 65536
		to handle large LLM responses without truncation.
	"""
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

	# Configure for large LLM responses
	http_request.body_size_limit = -1  # Unlimited response size
	http_request.download_chunk_size = 65536  # 64KB chunks for better performance


func set_host(new_host: String) -> void:
	"""Set the Ollama API server URL.

	Args:
		new_host: URL including protocol and port (e.g., "http://localhost:11434")
	"""
	host = new_host


func set_model(new_model: String) -> void:
	"""Set the Ollama model to use for generation.

	Args:
		new_model: Model name as recognized by Ollama (e.g., "llama3:8b")
	"""
	model = new_model


func set_temperature(new_temp: float) -> void:
	"""Set the default temperature for generation.

	Args:
		new_temp: Temperature value, typically between 0.0 and 1.0
			- 0.0: Deterministic, always picks most likely token
			- 1.0: Maximum creativity, samples from full probability distribution
	"""
	temperature = new_temp


func stop_generation() -> void:
	"""Cancel the currently in-flight HTTP request.

	Cancels the active request and resets the is_generating flag. No signals
	are emitted when a request is cancelled.
	"""
	if http_request:
		http_request.cancel_request()
	is_generating = false

func generate(prompt: String, options: Dictionary = {}) -> void:
	"""Generate text using Ollama's /api/generate endpoint.

	Args:
		prompt: The text prompt to send to the model
		options: Optional generation parameters
			- temperature: float (overrides default temperature)
			- num_predict: int (max tokens to generate)
			- stop: Array[String] (stop sequences)

	Notes:
		This is a non-streaming request. The entire response is received at once.
		Result is emitted via generate_finished signal, errors via generate_failed.
		If already generating, logs a warning and ignores the new request.
	"""
	if is_generating:
		push_warning("OllamaClient: Already generating, request queued")
		return

	is_generating = true
	current_response = ""
	current_request_type = "generate"

	var body = {
		"model": model,
		"prompt": prompt,
		"stream": false,
		"options": {}
	}

	# Apply temperature
	body.options.temperature = options.get("temperature", temperature)

	# Apply other options
	if options.has("num_predict"):
		body.options.num_predict = options.num_predict
	if options.has("stop"):
		body.stop = options.stop

	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]

	var url = host + "/api/generate"
	print("[OllamaClient] Sending generate request to: %s" % url)
	print("[OllamaClient] Model: %s, Stream: %s" % [model, body.stream])
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

	if err != OK:
		is_generating = false
		print("[OllamaClient] Failed to send request: %s" % err)
		generate_failed.emit("Failed to send request: %s" % err)

func chat(messages: Array, options: Dictionary = {}) -> void:
	"""Generate a chat response using Ollama's /api/chat endpoint.

	Args:
		messages: Array of message dictionaries, each with:
			- role: String ("system", "user", or "assistant")
			- content: String (the message text)
		options: Optional generation parameters (same as generate())
			- temperature: float (overrides default temperature)
			- num_predict: int (max tokens to generate)
			- stop: Array[String] (stop sequences)

	Notes:
		The chat endpoint supports conversation history and system prompts.
		Messages should be ordered chronologically. System messages typically
		come first to define behavior. Non-streaming mode is used.
	"""
	if is_generating:
		push_warning("OllamaClient: Already generating, request queued")
		return

	is_generating = true
	current_response = ""
	current_request_type = "chat"

	var body = {
		"model": model,
		"messages": messages,
		"stream": false,
		"options": {}
	}

	# Apply temperature
	body.options.temperature = options.get("temperature", temperature)

	# Apply other options
	if options.has("num_predict"):
		body.options.num_predict = options.num_predict
	if options.has("stop"):
		body.stop = options.stop

	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]

	var url = host + "/api/chat"
	print("[OllamaClient] Sending chat request to: %s" % url)
	print("[OllamaClient] Model: %s, Messages: %d, Stream: %s" % [model, messages.size(), body.stream])
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

	if err != OK:
		is_generating = false
		print("[OllamaClient] Failed to send request: %s" % err)
		generate_failed.emit("Failed to send request: %s" % err)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Handle HTTP response from Ollama API.

	Args:
		result: HTTPRequest result code (RESULT_SUCCESS if HTTP completed)
		response_code: HTTP status code (200 for success)
		_headers: Response headers (unused)
		body: Response body as bytes

	Notes:
		Routes to appropriate handler based on current_request_type
	"""
	print("[OllamaClient] Request completed: result=%d, response_code=%d, body_size=%d, type=%s" % [result, response_code, body.size(), current_request_type])
	var request_type = current_request_type
	is_generating = false
	current_request_type = ""

	# Check for network/HTTP errors
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[OllamaClient] Request failed with result: %d" % result)
		if request_type == "embed":
			embed_failed.emit("Request failed: %s" % result)
		else:
			generate_failed.emit("Request failed: %s" % result)
		return

	if response_code != 200:
		print("[OllamaClient] HTTP error: %d" % response_code)
		if request_type == "embed":
			embed_failed.emit("HTTP error: %s" % response_code)
		else:
			generate_failed.emit("HTTP error: %s" % response_code)
		return

	# Parse JSON response
	var json_str = body.get_string_from_utf8()
	print("[OllamaClient] Received JSON: %s" % json_str.substr(0, 200))
	var json = JSON.new()
	var parse_result = json.parse(json_str)

	if parse_result != OK:
		print("[OllamaClient] JSON parse error: %s" % json.get_error_message())
		if request_type == "embed":
			embed_failed.emit("JSON parse error: %s" % json.get_error_message())
		else:
			generate_failed.emit("JSON parse error: %s" % json.get_error_message())
		return

	var data = json.data

	# Route based on request type
	if request_type == "embed":
		_on_embed_completed(data)
	elif request_type == "generate" or request_type == "chat":
		_on_generate_completed(data)
	else:
		print("[OllamaClient] Unknown request type: %s" % request_type)


func _on_generate_completed(data: Dictionary) -> void:
	"""Handle generate/chat endpoint response."""
	var response_text = ""

	# Check for /api/generate response format
	if data.has("response"):
		response_text = data.response
		print("[OllamaClient] Extracted response from /api/generate format")

	# Check for /api/chat response format
	elif data.has("message") and data.message.has("content"):
		response_text = data.message.content
		print("[OllamaClient] Extracted response from /api/chat format")

	else:
		print("[OllamaClient] Unexpected response format - keys: %s" % str(data.keys()))
		generate_failed.emit("Unexpected response format")
		return

	print("[OllamaClient] Emitting generate_finished with response length: %d" % response_text.length())
	generate_finished.emit(response_text)


func embed(texts: Variant) -> void:
	"""Generate embeddings using Ollama's /api/embed endpoint.

	Args:
		texts: String or Array[String] - text(s) to embed

	Notes:
		Result emitted via embed_finished signal (Array of embedding vectors)
	"""
	if is_generating:
		push_warning("OllamaClient: Already generating, embed request ignored")
		return

	is_generating = true
	current_request_type = "embed"

	# Convert single string to array
	var input: Array = [texts] if texts is String else texts

	var body = {
		"model": embedding_model,
		"input": input
	}

	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]

	var url = host + "/api/embed"
	print("[OllamaClient] Sending embed request to: %s (model: %s, count: %d)" % [url, embedding_model, input.size()])
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

	if err != OK:
		is_generating = false
		print("[OllamaClient] Failed to send embed request: %s" % err)
		embed_failed.emit("Failed to send request: %s" % err)


func _on_embed_completed(data: Dictionary) -> void:
	"""Handle embed endpoint response."""
	if not data.has("embeddings"):
		print("[OllamaClient] Embed response missing 'embeddings' key")
		embed_failed.emit("Missing embeddings in response")
		return

	var embeddings: Array = data.embeddings
	print("[OllamaClient] Emitting embed_finished with %d embeddings" % embeddings.size())
	embed_finished.emit(embeddings)
