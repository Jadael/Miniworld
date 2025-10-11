## OllamaClient: HTTP interface to Ollama API
##
## Handles communication with Ollama running on localhost:11434
## Supports both /api/generate and /api/chat endpoints

extends Node

signal generate_finished(result: String)
signal generate_failed(error: String)

var host: String = "http://localhost:11434"
var model: String = "mistral-small:24b"
var temperature: float = 0.7

var http_request: HTTPRequest
var current_response: String = ""
var is_generating: bool = false

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func set_host(new_host: String) -> void:
	host = new_host

func set_model(new_model: String) -> void:
	model = new_model

func set_temperature(new_temp: float) -> void:
	temperature = new_temp

func stop_generation() -> void:
	"""Cancel the current generation"""
	if http_request:
		http_request.cancel_request()
	is_generating = false

## Generate text using /api/generate endpoint
func generate(prompt: String, options: Dictionary = {}) -> void:
	if is_generating:
		push_warning("OllamaClient: Already generating, request queued")
		return

	is_generating = true
	current_response = ""

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
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

	if err != OK:
		is_generating = false
		generate_failed.emit("Failed to send request: %s" % err)

## Chat using /api/chat endpoint (supports message history)
func chat(messages: Array, options: Dictionary = {}) -> void:
	if is_generating:
		push_warning("OllamaClient: Already generating, request queued")
		return

	is_generating = true
	current_response = ""

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
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

	if err != OK:
		is_generating = false
		generate_failed.emit("Failed to send request: %s" % err)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_generating = false

	# Check for errors
	if result != HTTPRequest.RESULT_SUCCESS:
		generate_failed.emit("Request failed: %s" % result)
		return

	if response_code != 200:
		generate_failed.emit("HTTP error: %s" % response_code)
		return

	# Parse response
	var json_str = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(json_str)

	if parse_result != OK:
		generate_failed.emit("JSON parse error: %s" % json.get_error_message())
		return

	var data = json.data

	# Extract response text
	var response_text = ""

	# Check for /api/generate response format
	if data.has("response"):
		response_text = data.response

	# Check for /api/chat response format
	elif data.has("message") and data.message.has("content"):
		response_text = data.message.content

	else:
		generate_failed.emit("Unexpected response format")
		return

	# Success!
	generate_finished.emit(response_text)
