## TextManager: Central registry for vault-based text and configuration
##
## Loads all text strings and configuration from user vault markdown files on startup.
## Provides simple lookup API for all game systems with variable substitution.
##
## Vault Structure:
##   - user://vault/text/commands/*.md - Command messages (social, movement, memory, etc.)
##   - user://vault/text/behaviors/*.md - Observable action templates
##   - user://vault/text/defaults/*.md - Default world strings
##   - user://vault/config/*.md - System configuration (AI, LLM, memory settings)
##
## On first run, copies default files from res://vault/ to user://vault/
## This allows users to customize text in their vault while keeping project defaults intact.
##
## Usage:
##   var msg = TextManager.get_text("commands.social.say.success", {"text": "Hello"})
##   var interval = TextManager.get_config("ai_defaults.think_interval", 6.0)
##
## Dependencies:
##   - Runs after autoload initialization
##   - Uses DirAccess and FileAccess for vault reading
##
## Notes:
##   - Falls back to inline defaults if vault files missing
##   - Supports hot-reloading via reload() method
##   - Markdown format for Obsidian compatibility
##   - User vault files are never overwritten (preserves customizations)

extends Node

# Singleton access
static var instance: TextManager

# Loaded data storage
var _text_data: Dictionary = {}      ## Nested: category.subcategory.key → string
var _config_data: Dictionary = {}    ## Flat: category.key → value

# Vault paths (user:// for user-editable vault)
const TEXT_PATH := "user://vault/text"
const CONFIG_PATH := "user://vault/config"

# Inline fallback defaults (used if vault files missing or incomplete)
const FALLBACK_TEXT := {
	"commands.social.look.success": "You look around.",
	"commands.social.look.behavior": "{actor} looks around.",
	"commands.social.look.no_location": "You are nowhere.",
	"commands.social.say.success": "You say, \"{text}\"",
	"commands.social.say.missing_arg": "Say what?",
	"commands.social.say.behavior": "{actor} says, \"{text}\"",
	"commands.social.emote.missing_arg": "Emote what?",
	"commands.social.emote.behavior": "{actor} {text}",
	"commands.social.examine.missing_arg": "Examine what?",
	"commands.social.examine.not_found": "You don't see '{target}' here.",
	"commands.social.examine.behavior": "{actor} examines {target}.",
	"behaviors.actions.look": "{actor} looks around.",
	"behaviors.actions.think": "{actor} pauses in thought.",
}

const FALLBACK_CONFIG := {
	"ai_defaults.think_interval": 6.0,
	"ai_defaults.min_think_interval": 1.0,
	"ai_defaults.prompt_memory_limit": 64,
	"ai_defaults.context_notes_max": 3,
	"ai_defaults.dream_recent_count": 5,
	"ai_defaults.dream_random_count": 5,
	"shoggoth.max_retries": 3,
	"shoggoth.retry_delay": 1.0,
	"shoggoth.embedding_model": "embeddinggemma",
	"memory_defaults.max_memories_per_agent": 100,
	"memory_defaults.load_memories_limit": 50,
	"memory_defaults.recent_memories_default": 64,
	"memory_defaults.min_similarity_threshold": 0.0,
}


func _ready() -> void:
	"""Initialize singleton and load all vault text/config."""
	instance = self
	_ensure_vault_structure()
	reload()
	print("[TextManager] Initialized with %d text entries, %d config entries" % [_text_data.size(), _config_data.size()])


## === Public API ===


func get_text(key: String, vars: Dictionary = {}) -> String:
	"""Get text string with optional variable substitution.

	Args:
		key: Dot-notation path like "commands.social.say.success"
		vars: Variables for substitution like {"actor": "Alice", "text": "Hello"}

	Returns:
		Formatted text string, or fallback if not found

	Example:
		var msg = TextManager.get_text("commands.social.say.behavior", {
			"actor": "Alice",
			"text": "Hello world!"
		})
		# Returns: "Alice says, \"Hello world!\""
	"""
	var template: String = _text_data.get(key, FALLBACK_TEXT.get(key, ""))

	if template.is_empty():
		push_warning("[TextManager] Missing text key: %s" % key)
		return ""

	return format_text(template, vars)


func get_config(key: String, default: Variant = null) -> Variant:
	"""Get configuration value.

	Args:
		key: Dot-notation path like "ai_defaults.think_interval"
		default: Value to return if key not found

	Returns:
		Config value, or fallback, or default parameter

	Example:
		var interval = TextManager.get_config("ai_defaults.think_interval", 6.0)
		# Returns: 6.0 (from vault or fallback)
	"""
	if _config_data.has(key):
		return _config_data[key]

	if FALLBACK_CONFIG.has(key):
		return FALLBACK_CONFIG[key]

	if default != null:
		return default

	push_warning("[TextManager] Missing config key: %s" % key)
	return null


func format_text(template: String, vars: Dictionary) -> String:
	"""Format template string with variable substitution.

	Replaces {var_name} with vars["var_name"].

	Args:
		template: String with {placeholders}
		vars: Dictionary of placeholder values

	Returns:
		Formatted string with variables replaced

	Example:
		format_text("{actor} says, \"{text}\"", {"actor": "Bob", "text": "Hi"})
		# Returns: "Bob says, \"Hi\""
	"""
	var result := template

	for var_name in vars:
		var placeholder := "{%s}" % var_name
		var value := str(vars[var_name])
		result = result.replace(placeholder, value)

	return result


func reload() -> void:
	"""Hot-reload all text and config from vault files.

	Clears existing data and re-parses all markdown files.
	Useful for testing changes without restarting the game.
	"""
	_text_data.clear()
	_config_data.clear()

	_load_text_files()
	_load_config_files()

	print("[TextManager] Reloaded: %d text entries, %d config entries" % [_text_data.size(), _config_data.size()])


## === Internal Loading ===


func _load_text_files() -> void:
	"""Load all text markdown files from vault/text/."""
	_load_directory_recursive(TEXT_PATH, _parse_text_file)


func _load_config_files() -> void:
	"""Load all config markdown files from vault/config/."""
	_load_directory_recursive(CONFIG_PATH, _parse_config_file)


func _load_directory_recursive(dir_path: String, parse_func: Callable) -> void:
	"""Recursively load all .md files in directory.

	Args:
		dir_path: Directory to scan
		parse_func: Function to call for each file, signature: func(file_path: String, category: String)
	"""
	var dir := DirAccess.open(dir_path)

	if not dir:
		push_warning("[TextManager] Directory not found: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		var file_path := dir_path + "/" + file_name

		if dir.current_is_dir():
			# Recurse into subdirectory
			_load_directory_recursive(file_path, parse_func)
		elif file_name.ends_with(".md"):
			# Parse markdown file
			var category := _extract_category_from_path(file_path)
			parse_func.call(file_path, category)

		file_name = dir.get_next()

	dir.list_dir_end()


func _extract_category_from_path(file_path: String) -> String:
	"""Extract category from file path.

	Examples:
		vault/text/commands/social.md → commands.social
		vault/config/ai_defaults.md → ai_defaults
	"""
	# Remove base paths
	var path := file_path.replace(TEXT_PATH + "/", "").replace(CONFIG_PATH + "/", "")

	# Remove .md extension
	path = path.replace(".md", "")

	# Replace slashes with dots
	path = path.replace("/", ".")

	return path


func _parse_text_file(file_path: String, category: String) -> void:
	"""Parse a text markdown file.

	Format:
		## section_name
		**key**: value text
		**other_key**: other value

	Result:
		_text_data["category.section_name.key"] = "value text"
	"""
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("[TextManager] Cannot open text file: %s" % file_path)
		return

	var current_section := ""
	var line_num := 0

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		line_num += 1

		# Skip empty lines and markdown headers (# title)
		if line.is_empty() or line.begins_with("# "):
			continue

		# Section header (## section_name)
		if line.begins_with("## "):
			current_section = line.substr(3).strip_edges().to_lower().replace(" ", "_")
			continue

		# Key-value pair (**key**: value)
		if line.begins_with("**") and "**:" in line:
			var parts := line.split("**:", true, 1)
			if parts.size() == 2:
				var key := parts[0].replace("**", "").strip_edges()
				var value := parts[1].strip_edges()

				if current_section.is_empty():
					push_warning("[TextManager] Key outside section at %s:%d" % [file_path, line_num])
					continue

				var full_key := "%s.%s.%s" % [category, current_section, key]
				_text_data[full_key] = value


func _parse_config_file(file_path: String, category: String) -> void:
	"""Parse a config markdown file.

	Format:
		**key**: value
		_description text (ignored)_

	Result:
		_config_data["category.key"] = value (auto-typed)
	"""
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("[TextManager] Cannot open config file: %s" % file_path)
		return

	var line_num := 0

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		line_num += 1

		# Skip empty lines, headers, descriptions, and horizontal rules
		if line.is_empty() or line.begins_with("#") or line.begins_with("_") or line.begins_with("---"):
			continue

		# Key-value pair (**key**: value)
		if line.begins_with("**") and "**:" in line:
			var parts := line.split("**:", true, 1)
			if parts.size() == 2:
				var key := parts[0].replace("**", "").strip_edges()
				var value_str := parts[1].strip_edges()

				var full_key := "%s.%s" % [category, key]
				_config_data[full_key] = _auto_type_value(value_str)


func _auto_type_value(value_str: String) -> Variant:
	"""Convert string value to appropriate type (float, int, bool, or string).

	Args:
		value_str: String representation of value

	Returns:
		Typed value (float, int, bool, or string)
	"""
	# Boolean
	if value_str.to_lower() in ["true", "yes"]:
		return true
	if value_str.to_lower() in ["false", "no"]:
		return false

	# Float (has decimal point)
	if "." in value_str and value_str.is_valid_float():
		return float(value_str)

	# Integer
	if value_str.is_valid_int():
		return int(value_str)

	# String (default)
	return value_str


func _ensure_vault_structure() -> void:
	"""Ensure vault directories exist and copy default files if missing.

	Creates user://vault/text/ and user://vault/config/ directories.
	Copies default text/config files from res://vault/ if they don't exist in user vault.
	This allows users to edit text in their vault while keeping defaults in the project.
	"""
	# Create directories
	DirAccess.make_dir_recursive_absolute("user://vault/text/commands")
	DirAccess.make_dir_recursive_absolute("user://vault/text/behaviors")
	DirAccess.make_dir_recursive_absolute("user://vault/config")

	# Copy default files from project to user vault if they don't exist
	_copy_default_file_if_missing("res://vault/text/commands/social.md", "user://vault/text/commands/social.md")
	_copy_default_file_if_missing("res://vault/text/commands/movement.md", "user://vault/text/commands/movement.md")
	_copy_default_file_if_missing("res://vault/text/commands/memory.md", "user://vault/text/commands/memory.md")
	_copy_default_file_if_missing("res://vault/text/behaviors/actions.md", "user://vault/text/behaviors/actions.md")
	_copy_default_file_if_missing("res://vault/config/ai_defaults.md", "user://vault/config/ai_defaults.md")
	_copy_default_file_if_missing("res://vault/config/shoggoth.md", "user://vault/config/shoggoth.md")
	_copy_default_file_if_missing("res://vault/config/memory_defaults.md", "user://vault/config/memory_defaults.md")
	_copy_default_file_if_missing("res://vault/text/defaults/world.md", "user://vault/text/defaults/world.md")


func _copy_default_file_if_missing(source_path: String, dest_path: String) -> void:
	"""Copy a default file from project to user vault if it doesn't exist.

	Args:
		source_path: Path to source file in res://
		dest_path: Path to destination file in user://
	"""
	# Check if destination already exists
	if FileAccess.file_exists(dest_path):
		return  # User has customized this file, don't overwrite

	# Check if source exists
	if not FileAccess.file_exists(source_path):
		push_warning("[TextManager] Default file not found: %s" % source_path)
		return

	# Create parent directory if needed
	var dest_dir := dest_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dest_dir)

	# Copy file
	var source := FileAccess.open(source_path, FileAccess.READ)
	if not source:
		push_warning("[TextManager] Cannot read source: %s" % source_path)
		return

	var dest := FileAccess.open(dest_path, FileAccess.WRITE)
	if not dest:
		push_warning("[TextManager] Cannot write dest: %s" % dest_path)
		return

	dest.store_string(source.get_as_text())
	source.close()
	dest.close()

	print("[TextManager] Copied default: %s -> %s" % [source_path, dest_path])
