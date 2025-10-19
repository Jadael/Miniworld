## TrainingDataCollector: Daemon for collecting LLM training data from gameplay
##
## This daemon automatically captures command executions and their context to build
## a training dataset for fine-tuning base models (e.g., Comma-v0.1) to improve
## Miniworld command generation.
##
## Responsibilities:
## 1. Capture full LLM prompts and generated commands from ThinkerComponent
## 2. Track command success/failure from ActorComponent execution
## 3. Sort examples into successful vs unsuccessful buckets
## 4. Save training data in llama.cpp-compatible format
## 5. Provide admin commands for managing the dataset
##
## Data Format (llama.cpp plain text):
## - Each example: Full prompt ending with "Your next command:\n> " + actual command
## - Successful commands → training_data/successful/*.txt
## - Failed commands → training_data/unsuccessful/*.txt
##
## Use Cases:
## - Fine-tune base models to reduce invalid command generation
## - Collect real gameplay examples for semi-synthetic training data
## - Analyze common failure patterns for prompt engineering
##
## Admin Commands (via ActorComponent):
## - @training-status - Show collection statistics
## - @training-export - Export consolidated training files
## - @training-clear - Clear collected data (with confirmation)
## - @training-toggle - Enable/disable collection

extends Node

## Emitted when a training example is saved
## example_type: "successful" or "unsuccessful"
## command: The command that was captured
signal example_saved(example_type: String, command: String)

## Emitted when training data is exported
## successful_count: Number of successful examples exported
## unsuccessful_count: Number of unsuccessful examples exported
signal data_exported(successful_count: int, unsuccessful_count: int)


## Base directory for training data storage
const DATA_DIR = "user://training_data"

## Directory for successful command examples
const SUCCESSFUL_DIR = "user://training_data/successful"

## Directory for unsuccessful command examples
const UNSUCCESSFUL_DIR = "user://training_data/unsuccessful"

## Configuration file for collector settings
const CONFIG_FILE = "user://training_collector_config.cfg"


## Whether collection is currently enabled
var is_collecting: bool = true

## Count of successful examples collected this session
var successful_count: int = 0

## Count of unsuccessful examples collected this session
var unsuccessful_count: int = 0

## Pending examples waiting for command execution results
## Maps task_id → {prompt: String, command: String, timestamp: float, actor_name: String}
var pending_examples: Dictionary = {}

## Configuration manager
var config: ConfigFile


func _ready() -> void:
	"""Initialize training data collector on scene load.

	Creates necessary directories, loads configuration, and connects
	to relevant signals for capturing training examples.
	"""
	print("[TrainingDataCollector] Initializing...")

	_ensure_directories_exist()
	_load_config()

	print("[TrainingDataCollector] Collection %s" % ("ENABLED" if is_collecting else "DISABLED"))
	print("[TrainingDataCollector] Data directory: %s" % DATA_DIR)


func _ensure_directories_exist() -> void:
	"""Create training data directories if they don't exist.

	Sets up the directory structure for organizing successful and
	unsuccessful training examples.
	"""
	var dir := DirAccess.open("user://")

	if not dir.dir_exists("training_data"):
		dir.make_dir("training_data")

	if not dir.dir_exists("training_data/successful"):
		dir.make_dir("training_data/successful")

	if not dir.dir_exists("training_data/unsuccessful"):
		dir.make_dir("training_data/unsuccessful")


func _load_config() -> void:
	"""Load collector configuration from disk.

	Loads settings like whether collection is enabled, which commands
	to filter, etc. Creates default config if none exists.
	"""
	config = ConfigFile.new()
	var err := config.load(CONFIG_FILE)

	if err == OK:
		is_collecting = config.get_value("collector", "enabled", true)
	else:
		# Create default config
		config.set_value("collector", "enabled", true)
		config.set_value("collector", "collect_player_commands", false)  # Only AI by default
		config.set_value("collector", "collect_admin_commands", false)   # Skip admin commands
		config.save(CONFIG_FILE)


func _save_config() -> void:
	"""Persist current configuration to disk."""
	config.set_value("collector", "enabled", is_collecting)
	config.save(CONFIG_FILE)


func capture_prompt_and_command(actor: WorldObject, prompt: String, command: String, task_id: String) -> void:
	"""Capture a prompt-command pair when an AI agent decides on an action.

	Called by ThinkerComponent after LLM generates a command but before
	it's executed. We store it temporarily and wait for execution results
	to determine if this is a successful or unsuccessful example.

	Args:
		actor: The AI agent who generated this command
		prompt: The full LLM prompt (context + situation)
		command: The command the LLM generated (e.g., "say Hello")
		task_id: Unique identifier for this generation task

	Notes:
		The example will be categorized as successful/unsuccessful after
		ActorComponent executes the command and reports results.
	"""
	if not is_collecting:
		return

	# Skip player commands if configured
	if actor.has_flag("is_player") and not config.get_value("collector", "collect_player_commands", false):
		return

	# Skip admin commands if configured
	if command.begins_with("@") and not config.get_value("collector", "collect_admin_commands", false):
		return

	# Store pending example
	pending_examples[task_id] = {
		"prompt": prompt,
		"command": command,
		"timestamp": Time.get_unix_time_from_system(),
		"actor_name": actor.name
	}

	print("[TrainingDataCollector] Captured pending example from %s: %s" % [actor.name, command])


func record_command_result(actor: WorldObject, command: String, result: Dictionary, task_id: String = "") -> void:
	"""Record the success/failure of a command execution.

	Called by ActorComponent after executing a command. If we have a pending
	example for this command, we categorize it based on success and save it.

	Args:
		actor: The actor who executed the command
		command: The full command string that was executed
		result: Dictionary with at least {"success": bool, "message": String}
		task_id: Optional task_id to match against pending examples

	Notes:
		If task_id is provided and matches a pending example, we save the
		full prompt+command pair. Otherwise, we can still collect just the
		command result for analysis.
	"""
	if not is_collecting:
		return

	# Check if we have a pending example for this task
	if task_id != "" and pending_examples.has(task_id):
		var example: Dictionary = pending_examples[task_id]
		var was_successful: bool = result.get("success", false)

		_save_training_example(
			example.prompt,
			example.command,
			was_successful,
			example.actor_name
		)

		pending_examples.erase(task_id)


func _save_training_example(prompt: String, command: String, successful: bool, actor_name: String) -> void:
	"""Save a complete training example to disk with metadata.

	Format:
	```
	# METADATA
	agent: <actor_name>
	timestamp: <iso_timestamp>
	success: <true|false>
	# PROMPT
	<full_prompt_as_seen_by_agent>
	# RESPONSE (last line is desired output)
	<actual_command_generated>
	```

	Args:
		prompt: The full LLM prompt (exactly as the agent saw it)
		command: The command that was generated
		successful: Whether the command executed successfully
		actor_name: Name of the actor for metadata

	Notes:
		- Last line is ALWAYS the desired/correct command
		- For successful commands: last line = actual command
		- For failed commands: last line = corrected command (if available) or actual command
		- Files are named with timestamp and actor name for easy filtering
		- Metadata allows post-processing filters (by agent, success, date range, etc.)
	"""
	var example_type: String = "successful" if successful else "unsuccessful"
	var base_dir: String = SUCCESSFUL_DIR if successful else UNSUCCESSFUL_DIR

	# Generate filename with timestamp and actor name
	var timestamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-")
	var filename: String = "%s/%s_%s.txt" % [base_dir, timestamp, actor_name.to_lower().replace(" ", "_")]

	# Build training file with metadata header
	var training_text: String = ""

	# Metadata section
	training_text += "# METADATA\n"
	training_text += "agent: %s\n" % actor_name
	training_text += "timestamp: %s\n" % Time.get_datetime_string_from_system(true, false)
	training_text += "success: %s\n" % str(successful).to_lower()
	training_text += "\n"

	# Prompt section (exactly as agent saw it)
	training_text += "# PROMPT\n"
	training_text += "%s\n" % prompt
	training_text += "\n"

	# Response section (last line is desired output)
	training_text += "# RESPONSE\n"
	training_text += "%s\n" % command

	# Save to file
	var file := FileAccess.open(filename, FileAccess.WRITE)
	if file:
		file.store_string(training_text)
		file.close()

		# Update counters
		if successful:
			successful_count += 1
		else:
			unsuccessful_count += 1

		print("[TrainingDataCollector] Saved %s example: %s" % [example_type, filename])
		example_saved.emit(example_type, command)
	else:
		push_error("[TrainingDataCollector] Failed to save training example: %s" % filename)


func export_consolidated_dataset(output_path: String = "user://miniworld_training.txt", filters: Dictionary = {}) -> Dictionary:
	"""Export training examples with optional filtering.

	Combines training examples into files suitable for fine-tuning, with
	flexible filtering by agent, success, and timestamp.

	Args:
		output_path: Where to save the consolidated training file
		filters: Optional filtering criteria:
			- agents (Array[String]): Only include these agents (empty = all)
			- success_only (bool): Only successful examples (default: true)
			- failed_only (bool): Only failed examples (default: false)
			- exclude_agents (Array[String]): Exclude these agents
			- from_timestamp (String): ISO timestamp, only include after this
			- to_timestamp (String): ISO timestamp, only include before this

	Returns:
		Dictionary with:
		- success (bool): Whether export succeeded
		- message (String): Result message
		- included_count (int): Number of examples included
		- excluded_count (int): Number of examples excluded by filters
	"""
	# Parse filter options with defaults
	var include_agents: Array = filters.get("agents", [])
	var exclude_agents: Array = filters.get("exclude_agents", [])
	var success_only: bool = filters.get("success_only", true)
	var failed_only: bool = filters.get("failed_only", false)
	var from_timestamp: String = filters.get("from_timestamp", "")
	var to_timestamp: String = filters.get("to_timestamp", "")

	var included_examples: Array[String] = []
	var excluded_count: int = 0

	# Determine which directories to scan
	var dirs_to_scan: Array[String] = []
	if not failed_only:
		dirs_to_scan.append(SUCCESSFUL_DIR)
	if not success_only or failed_only:
		dirs_to_scan.append(UNSUCCESSFUL_DIR)

	# Collect and filter examples
	for dir_path in dirs_to_scan:
		var files := _get_all_files_in_directory(dir_path)
		for file_path in files:
			var content := _read_file(file_path)
			if content == "":
				continue

			# Parse metadata for filtering
			var metadata := _parse_metadata(content)

			# Apply filters
			if include_agents.size() > 0 and not metadata.agent in include_agents:
				excluded_count += 1
				continue
			if exclude_agents.size() > 0 and metadata.agent in exclude_agents:
				excluded_count += 1
				continue
			if from_timestamp != "" and metadata.timestamp < from_timestamp:
				excluded_count += 1
				continue
			if to_timestamp != "" and metadata.timestamp > to_timestamp:
				excluded_count += 1
				continue

			# Extract prompt and response for training format
			var training_example := _extract_training_format(content)
			if training_example != "":
				included_examples.append(training_example)

	# Write consolidated training file
	var train_file := FileAccess.open(output_path, FileAccess.WRITE)
	if train_file:
		for example in included_examples:
			train_file.store_string(example)
			train_file.store_string("\n")  # Blank line between examples
		train_file.close()
	else:
		return {
			"success": false,
			"message": "Failed to create output file: %s" % output_path
		}

	data_exported.emit(included_examples.size(), excluded_count)

	return {
		"success": true,
		"message": "Exported training data to %s" % output_path,
		"included_count": included_examples.size(),
		"excluded_count": excluded_count
	}


func get_status() -> Dictionary:
	"""Get current collection statistics.

	Returns:
		Dictionary with:
		- enabled (bool): Whether collection is active
		- successful_count (int): Successful examples this session
		- unsuccessful_count (int): Unsuccessful examples this session
		- total_successful (int): Total successful examples on disk
		- total_unsuccessful (int): Total unsuccessful examples on disk
		- pending_count (int): Examples waiting for execution results
	"""
	var total_successful := _count_files_in_directory(SUCCESSFUL_DIR)
	var total_unsuccessful := _count_files_in_directory(UNSUCCESSFUL_DIR)

	return {
		"enabled": is_collecting,
		"successful_count": successful_count,
		"unsuccessful_count": unsuccessful_count,
		"total_successful": total_successful,
		"total_unsuccessful": total_unsuccessful,
		"pending_count": pending_examples.size()
	}


func toggle_collection() -> bool:
	"""Toggle collection on/off.

	Returns:
		New collection state (true = enabled)
	"""
	is_collecting = not is_collecting
	_save_config()
	print("[TrainingDataCollector] Collection %s" % ("ENABLED" if is_collecting else "DISABLED"))
	return is_collecting


func clear_all_data() -> Dictionary:
	"""Delete all collected training data.

	Removes all files from successful and unsuccessful directories.
	Use with caution - this cannot be undone!

	Returns:
		Dictionary with:
		- success (bool): Whether clear succeeded
		- message (String): Result message
		- deleted_count (int): Number of files deleted
	"""
	var deleted_count := 0

	# Clear successful examples
	var success_files := _get_all_files_in_directory(SUCCESSFUL_DIR)
	for file_path in success_files:
		if DirAccess.remove_absolute(file_path) == OK:
			deleted_count += 1

	# Clear unsuccessful examples
	var unsuccess_files := _get_all_files_in_directory(UNSUCCESSFUL_DIR)
	for file_path in unsuccess_files:
		if DirAccess.remove_absolute(file_path) == OK:
			deleted_count += 1

	# Reset session counters
	successful_count = 0
	unsuccessful_count = 0
	pending_examples.clear()

	return {
		"success": true,
		"message": "Deleted %d training examples" % deleted_count,
		"deleted_count": deleted_count
	}


func _get_all_files_in_directory(dir_path: String) -> Array[String]:
	"""Get list of all file paths in a directory.

	Args:
		dir_path: Directory to scan

	Returns:
		Array of absolute file paths
	"""
	var files: Array[String] = []
	var dir := DirAccess.open(dir_path)

	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()

		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".txt"):
				files.append(dir_path.path_join(file_name))
			file_name = dir.get_next()

		dir.list_dir_end()

	return files


func _count_files_in_directory(dir_path: String) -> int:
	"""Count number of .txt files in a directory.

	Args:
		dir_path: Directory to count

	Returns:
		Number of .txt files
	"""
	return _get_all_files_in_directory(dir_path).size()


func _read_file(file_path: String) -> String:
	"""Read entire file contents as string.

	Args:
		file_path: Path to file

	Returns:
		File contents, or empty string on error
	"""
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()
		return content
	return ""


func _parse_metadata(content: String) -> Dictionary:
	"""Parse metadata section from training example file.

	Args:
		content: Full file content with metadata header

	Returns:
		Dictionary with:
		- agent (String): Agent name
		- timestamp (String): ISO timestamp
		- success (bool): Whether command succeeded
	"""
	var metadata: Dictionary = {
		"agent": "",
		"timestamp": "",
		"success": false
	}

	var lines := content.split("\n")
	for line in lines:
		if line.begins_with("agent:"):
			metadata.agent = line.replace("agent:", "").strip_edges()
		elif line.begins_with("timestamp:"):
			metadata.timestamp = line.replace("timestamp:", "").strip_edges()
		elif line.begins_with("success:"):
			var success_str := line.replace("success:", "").strip_edges()
			metadata.success = success_str == "true"

	return metadata


func _extract_training_format(content: String) -> String:
	"""Extract prompt and response from metadata file into training format.

	Removes metadata headers and returns just the prompt + response
	in a format suitable for fine-tuning (last line = command).

	Args:
		content: Full file content with metadata

	Returns:
		Training format string: prompt + response (last line is command)
	"""
	var in_prompt_section: bool = false
	var in_response_section: bool = false
	var prompt_lines: Array[String] = []
	var response_lines: Array[String] = []

	var lines := content.split("\n")
	for line in lines:
		if line.begins_with("# PROMPT"):
			in_prompt_section = true
			in_response_section = false
			continue
		elif line.begins_with("# RESPONSE"):
			in_prompt_section = false
			in_response_section = true
			continue
		elif line.begins_with("#"):
			# Skip other header lines
			continue

		if in_prompt_section and line.strip_edges() != "":
			prompt_lines.append(line)
		elif in_response_section and line.strip_edges() != "":
			response_lines.append(line)

	# Combine prompt and response with last line being the command
	var result: String = ""
	for line in prompt_lines:
		result += line + "\n"
	for line in response_lines:
		result += line + "\n"

	return result
