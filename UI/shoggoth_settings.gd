## ShoggothSettings: Admin UI for Ollama/LLM Configuration
##
## Provides a visual interface for configuring Shoggoth's LLM backend settings.
## This is "outside the world" - it's infrastructure/admin tooling for the
## Miniworld operator, not part of the in-world text interface.
##
## Features:
## - Model selection dropdown (populated from Ollama)
## - Host URL configuration
## - Temperature slider
## - Connection testing
## - Real-time status display
##
## Dependencies:
## - Shoggoth: The AI daemon being configured
## - OllamaClient: For fetching available models
##
## Notes:
## - This is separate from in-world @config commands
## - Changes are saved immediately to Shoggoth's config file
## - Uses HTTPRequest to fetch model list from Ollama API

extends Window


## UI Elements - populated via @onready when scene is ready
@onready var model_dropdown: OptionButton = %ModelDropdown
@onready var host_input: LineEdit = %HostInput
@onready var temperature_slider: HSlider = %TemperatureSlider
@onready var temperature_label: Label = %TemperatureLabel
@onready var refresh_button: Button = %RefreshButton
@onready var test_button: Button = %TestButton
@onready var apply_button: Button = %ApplyButton
@onready var status_label: Label = %StatusLabel


## HTTPRequest for fetching available models from Ollama
var http_request: HTTPRequest

## Currently available models from Ollama
var available_models: Array[String] = []


func _ready() -> void:
	"""Initialize the settings window.

	Sets up HTTP request handler, populates current settings,
	and connects UI signals.
	"""
	# Setup HTTP request for fetching models
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_models_request_completed)

	# Connect UI signals
	refresh_button.pressed.connect(_on_refresh_pressed)
	test_button.pressed.connect(_on_test_pressed)
	apply_button.pressed.connect(_on_apply_pressed)
	temperature_slider.value_changed.connect(_on_temperature_changed)
	close_requested.connect(_on_close_requested)

	# Load current settings
	_load_current_settings()

	# Fetch available models
	_fetch_available_models()


func _load_current_settings() -> void:
	"""Load current Shoggoth configuration into UI fields.

	Reads from Shoggoth's config and populates the form fields
	with current values.
	"""
	if not Shoggoth or not Shoggoth.config:
		_set_status("Error: Shoggoth not initialized", Color.RED)
		return

	var config = Shoggoth.config

	# Load host
	var host = config.get_value("ollama", "host", "http://localhost:11434")
	host_input.text = host

	# Load temperature
	var temp = config.get_value("ollama", "temperature", 0.9)
	temperature_slider.value = temp
	_on_temperature_changed(temp)

	# Load current model
	var current_model = config.get_value("ollama", "model", "gemma3:27b")

	# If we already have models, select the current one
	if available_models.size() > 0:
		_select_model(current_model)


func _fetch_available_models() -> void:
	"""Fetch list of available models from Ollama API.

	Sends GET request to /api/tags endpoint to retrieve
	all locally available Ollama models.
	"""
	_set_status("Fetching models...", Color.YELLOW)

	var host = host_input.text
	var url = host + "/api/tags"

	var err = http_request.request(url, [], HTTPClient.METHOD_GET)

	if err != OK:
		_set_status("Failed to connect to Ollama", Color.RED)


func _on_models_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Handle response from Ollama /api/tags endpoint.

	Args:
		result: HTTPRequest result code
		response_code: HTTP status code
		_headers: Response headers (unused)
		body: Response body containing model list JSON
	"""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_set_status("Failed to fetch models (HTTP %d)" % response_code, Color.RED)
		return

	# Parse JSON response
	var json_str = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(json_str)

	if parse_result != OK:
		_set_status("Failed to parse model list", Color.RED)
		return

	var data = json.data

	if not data.has("models"):
		_set_status("No models found in response", Color.RED)
		return

	# Extract model names
	available_models.clear()
	model_dropdown.clear()

	for model_info in data.models:
		if model_info.has("name"):
			var model_name: String = model_info.name
			available_models.append(model_name)
			model_dropdown.add_item(model_name)

	if available_models.size() == 0:
		_set_status("No models installed in Ollama", Color.ORANGE)
	else:
		_set_status("Found %d models" % available_models.size(), Color.GREEN)

		# Select current model if it exists
		if Shoggoth and Shoggoth.config:
			var current_model = Shoggoth.config.get_value("ollama", "model", "gemma3:27b")
			_select_model(current_model)


func _select_model(model_name: String) -> void:
	"""Select a model in the dropdown by name.

	Args:
		model_name: The model name to select
	"""
	for i in range(model_dropdown.item_count):
		if model_dropdown.get_item_text(i) == model_name:
			model_dropdown.selected = i
			return


func _on_refresh_pressed() -> void:
	"""Handle Refresh button press - re-fetch model list."""
	_fetch_available_models()


func _on_test_pressed() -> void:
	"""Handle Test Connection button press.

	Applies current settings temporarily and triggers
	Shoggoth's initialization test.
	"""
	_set_status("Testing connection...", Color.YELLOW)

	# Apply settings temporarily
	var selected_idx = model_dropdown.selected
	if selected_idx < 0 or selected_idx >= available_models.size():
		_set_status("Please select a model", Color.ORANGE)
		return

	var model = available_models[selected_idx]
	var host = host_input.text
	var temp = temperature_slider.value

	# Configure Ollama client temporarily
	if Shoggoth.ollama_client:
		Shoggoth.ollama_client.set_host(host)
		Shoggoth.ollama_client.set_model(model)
		Shoggoth.ollama_client.set_temperature(temp)

	# Connect to test completion
	if not Shoggoth.models_initialized.is_connected(_on_test_completed):
		Shoggoth.models_initialized.connect(_on_test_completed, CONNECT_ONE_SHOT)

	# Run initialization test
	Shoggoth.test_connection()


func _on_test_completed(success: bool) -> void:
	"""Handle test connection completion.

	Args:
		success: True if LLM responded, false otherwise
	"""
	if success:
		_set_status("Connection successful!", Color.GREEN)
	else:
		_set_status("Connection failed - check host and model", Color.RED)


func _on_apply_pressed() -> void:
	"""Handle Apply button press - save settings to config.

	Validates inputs, saves to Shoggoth's config file,
	and triggers re-initialization.
	"""
	var selected_idx = model_dropdown.selected
	if selected_idx < 0 or selected_idx >= available_models.size():
		_set_status("Please select a model", Color.ORANGE)
		return

	var model = available_models[selected_idx]
	var host = host_input.text
	var temp = temperature_slider.value

	if not Shoggoth or not Shoggoth.config:
		_set_status("Error: Shoggoth not available", Color.RED)
		return

	# Save to config
	Shoggoth.config.set_value("ollama", "host", host)
	Shoggoth.config.set_value("ollama", "model", model)
	Shoggoth.config.set_value("ollama", "temperature", temp)
	Shoggoth.config.save(Shoggoth.CONFIG_FILE)

	_set_status("Settings saved - reinitializing...", Color.YELLOW)

	# Re-initialize Shoggoth with new settings
	Shoggoth.call_deferred("_initialize_models")

	# Close window after brief delay
	await get_tree().create_timer(1.0).timeout
	hide()


func _on_temperature_changed(value: float) -> void:
	"""Handle temperature slider change.

	Args:
		value: New temperature value (0.0 - 1.0)
	"""
	temperature_label.text = "Temperature: %.2f" % value


func _on_close_requested() -> void:
	"""Handle window close button - hide window."""
	hide()


func _set_status(message: String, color: Color) -> void:
	"""Update status label with colored message.

	Args:
		message: Status message to display
		color: Color for the message text
	"""
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)
