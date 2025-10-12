## MarkdownVault: Daemon for Obsidian-Compatible Markdown Persistence
##
## Manages all file I/O for the markdown vault, providing a centralized interface
## for reading, writing, and managing markdown files. This daemon ensures all world
## state, agent memories, and configuration are stored in a human-readable,
## Obsidian-compatible format.
##
## Responsibilities:
## - Reading and writing markdown files with YAML frontmatter
## - Managing vault directory structure
## - Parsing and serializing markdown documents
## - Template system for consistent file formats
## - Auto-save and periodic snapshots
##
## Vault Structure:
## - vault/world/locations/ - Location markdown files
## - vault/agents/<name>/memories/ - Agent memory files
## - vault/agents/<name>/notes/ - Agent notes
## - vault/config/ - System configuration
## - vault/templates/ - Markdown templates
##
## Dependencies:
## - DirAccess for file system operations
## - Time for timestamps
##
## Notes:
## - All paths are relative to user:// for portability
## - YAML frontmatter uses `---` delimiters
## - Wiki-style links use [[Target]] format
## - Timestamps are ISO 8601 format

extends Node


## Path to the vault root directory (relative to user://)
const VAULT_PATH = "vault"

## Subdirectory paths within the vault
const WORLD_PATH = "vault/world"
const LOCATIONS_PATH = "vault/world/locations"
const OBJECTS_PATH = "vault/world/objects"
const AGENTS_PATH = "vault/agents"
const TEMPLATES_PATH = "vault/templates"
const CONFIG_PATH = "vault/config"


## Dictionary of loaded templates {template_name: template_content}
var templates: Dictionary = {}

## Cache of recently accessed files {file_path: {content, timestamp}}
var file_cache: Dictionary = {}

## Maximum cache size before pruning
const MAX_CACHE_SIZE = 50


func _ready() -> void:
	"""Initialize the MarkdownVault and ensure directory structure exists.

	Creates all necessary vault directories and loads templates on startup.
	"""
	_ensure_vault_structure()
	_load_templates()
	print("[MarkdownVault] Initialized - vault at: ", ProjectSettings.globalize_path("user://" + VAULT_PATH))


func _ensure_vault_structure() -> void:
	"""Create vault directory structure if it doesn't exist.

	Creates all necessary subdirectories for the vault, ensuring the file
	system is ready for read/write operations.
	"""
	var dirs_to_create = [
		VAULT_PATH,
		WORLD_PATH,
		LOCATIONS_PATH,
		OBJECTS_PATH + "/characters",
		OBJECTS_PATH + "/items",
		AGENTS_PATH,
		TEMPLATES_PATH,
		CONFIG_PATH
	]

	for dir_path in dirs_to_create:
		var dir = DirAccess.open("user://")
		if dir:
			if not dir.dir_exists(dir_path):
				var err = dir.make_dir_recursive(dir_path)
				if err != OK:
					push_error("Failed to create directory: %s (error %d)" % [dir_path, err])
				else:
					print("[MarkdownVault] Created directory: %s" % dir_path)


func _load_templates() -> void:
	"""Load all markdown templates from the templates directory.

	Scans the templates directory and loads all .md files into the templates
	dictionary for use in creating new files.
	"""
	var template_dir = DirAccess.open("user://" + TEMPLATES_PATH)
	if not template_dir:
		push_warning("[MarkdownVault] Templates directory not accessible, creating defaults")
		_create_default_templates()
		return

	template_dir.list_dir_begin()
	var file_name = template_dir.get_next()

	while file_name != "":
		if file_name.ends_with(".md") and not template_dir.current_is_dir():
			var template_name = file_name.get_basename()
			var content = read_file(TEMPLATES_PATH + "/" + file_name)
			if content != "":
				templates[template_name] = content
				print("[MarkdownVault] Loaded template: %s" % template_name)
		file_name = template_dir.get_next()

	template_dir.list_dir_end()


func _create_default_templates() -> void:
	"""Create default markdown templates for locations, characters, and objects.

	If templates don't exist, this creates sensible defaults that follow
	the vault structure conventions.
	"""
	# Location template
	var location_template = """---
object_id: {object_id}
type: location
created: {created}
modified: {modified}
---

# {name}

## Description
{description}

## Connections
{connections}

## Properties
{properties}

## Objects
{objects}

## Current Occupants
{occupants}
"""
	write_file(TEMPLATES_PATH + "/location_template.md", location_template)
	templates["location_template"] = location_template

	# Character template
	var character_template = """---
object_id: {object_id}
type: character
class: {class}
created: {created}
location: {location}
---

# {name}

## Description
{description}

## Properties
{properties}

## Components
{components}

## Configuration
{configuration}

## System Prompt
{system_prompt}
"""
	write_file(TEMPLATES_PATH + "/character_template.md", character_template)
	templates["character_template"] = character_template

	print("[MarkdownVault] Created default templates")


func read_file(file_path: String) -> String:
	"""Read a markdown file from the vault.

	Args:
		file_path: Path relative to user:// (e.g., "vault/world/locations/Lobby.md")

	Returns:
		File contents as string, or empty string if file doesn't exist

	Notes:
		Checks cache first before reading from disk
	"""
	# Check cache first
	if file_cache.has(file_path):
		return file_cache[file_path].content

	var full_path = "user://" + file_path
	var file = FileAccess.open(full_path, FileAccess.READ)

	if not file:
		return ""

	var content = file.get_as_text()
	file.close()

	# Cache the content
	_cache_file(file_path, content)

	return content


func write_file(file_path: String, content: String) -> bool:
	"""Write a markdown file to the vault.

	Args:
		file_path: Path relative to user:// (e.g., "vault/world/locations/Lobby.md")
		content: Full markdown content including frontmatter

	Returns:
		True if write succeeded, false otherwise

	Notes:
		Automatically updates cache and creates parent directories
	"""
	var full_path = "user://" + file_path

	# Ensure parent directory exists
	var dir_path = full_path.get_base_dir()
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists(dir_path.replace("user://", "")):
		dir.make_dir_recursive(dir_path.replace("user://", ""))

	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if not file:
		push_error("[MarkdownVault] Failed to open file for writing: %s" % full_path)
		return false

	file.store_string(content)
	file.close()

	# Update cache
	_cache_file(file_path, content)

	return true


func parse_frontmatter(content: String) -> Dictionary:
	"""Parse YAML frontmatter from markdown content.

	Args:
		content: Full markdown file content

	Returns:
		Dictionary containing:
		- frontmatter: Dictionary of parsed YAML key-value pairs
		- body: Markdown content after frontmatter

	Notes:
		Frontmatter must be at start of file between `---` delimiters
	"""
	var result = {"frontmatter": {}, "body": content}

	if not content.begins_with("---\n"):
		return result

	# Find end of frontmatter
	var end_pos = content.find("\n---\n", 4)
	if end_pos == -1:
		return result

	var frontmatter_text = content.substr(4, end_pos - 4)
	var body = content.substr(end_pos + 5)

	# Parse frontmatter (simple key: value format)
	var frontmatter = {}
	for line in frontmatter_text.split("\n"):
		if line.strip_edges().is_empty() or not line.contains(":"):
			continue

		var parts = line.split(":", true, 1)
		if parts.size() == 2:
			var key = parts[0].strip_edges()
			var value = parts[1].strip_edges()
			frontmatter[key] = value

	result.frontmatter = frontmatter
	result.body = body

	return result


func create_frontmatter(data: Dictionary) -> String:
	"""Create YAML frontmatter string from dictionary.

	Args:
		data: Dictionary of key-value pairs for frontmatter

	Returns:
		Formatted YAML frontmatter block with delimiters

	Notes:
		Outputs in format:
		---
		key: value
		---
	"""
	var lines = ["---"]

	for key in data.keys():
		lines.append("%s: %s" % [key, str(data[key])])

	lines.append("---")
	lines.append("")  # Blank line after frontmatter

	return "\n".join(lines)


func fill_template(template_name: String, data: Dictionary) -> String:
	"""Fill a template with provided data.

	Args:
		template_name: Name of template (without .md extension)
		data: Dictionary of replacement values {placeholder: value}

	Returns:
		Template with all {placeholder} tokens replaced

	Notes:
		Missing values are replaced with empty string
	"""
	if not templates.has(template_name):
		push_error("[MarkdownVault] Template not found: %s" % template_name)
		return ""

	var content = templates[template_name]

	# Replace all {key} with values from data
	for key in data.keys():
		var placeholder = "{%s}" % key
		content = content.replace(placeholder, str(data[key]))

	# Replace any remaining placeholders with empty string
	var regex = RegEx.new()
	regex.compile("\\{[^}]+\\}")
	content = regex.sub(content, "", true)

	return content


func get_timestamp() -> String:
	"""Get current timestamp in ISO 8601 format.

	Returns:
		Timestamp string like "2025-03-12T14:30:22Z"
	"""
	var time = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		time.year, time.month, time.day,
		time.hour, time.minute, time.second
	]


func get_filename_timestamp() -> String:
	"""Get current timestamp formatted for filenames.

	Returns:
		Timestamp string like "20250312-143022"
	"""
	var time = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d-%02d%02d%02d" % [
		time.year, time.month, time.day,
		time.hour, time.minute, time.second
	]


func sanitize_filename(name: String) -> String:
	"""Sanitize a string for use as a filename.

	Args:
		name: Raw string to sanitize

	Returns:
		Safe filename with spaces replaced by underscores, special chars removed
	"""
	var safe = name.strip_edges()
	safe = safe.replace(" ", "_")

	# Remove special characters
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9_-]")
	safe = regex.sub(safe, "", true)

	return safe


func list_files(directory: String, extension: String = "") -> Array[String]:
	"""List all files in a vault directory.

	Args:
		directory: Path relative to user:// (e.g., "vault/agents/Eliza/memories")
		extension: Optional file extension filter (e.g., ".md")

	Returns:
		Array of filenames (not full paths)
	"""
	var files: Array[String] = []
	var dir = DirAccess.open("user://" + directory)

	if not dir:
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			if extension.is_empty() or file_name.ends_with(extension):
				files.append(file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	return files


func _cache_file(file_path: String, content: String) -> void:
	"""Add a file to the cache.

	Args:
		file_path: Path relative to user://
		content: File contents

	Notes:
		Prunes oldest entries if cache exceeds MAX_CACHE_SIZE
	"""
	file_cache[file_path] = {
		"content": content,
		"timestamp": Time.get_ticks_msec()
	}

	# Prune cache if too large
	if file_cache.size() > MAX_CACHE_SIZE:
		_prune_cache()


func _prune_cache() -> void:
	"""Remove oldest entries from cache to keep size manageable."""
	var entries = []
	for path in file_cache.keys():
		entries.append({
			"path": path,
			"timestamp": file_cache[path].timestamp
		})

	# Sort by timestamp (oldest first)
	entries.sort_custom(func(a, b): return a.timestamp < b.timestamp)

	# Remove oldest 25%
	var to_remove = max(1, entries.size() / 4)
	for i in range(to_remove):
		file_cache.erase(entries[i].path)


func get_vault_path() -> String:
	"""Get the absolute filesystem path to the vault.

	Returns:
		Full path to vault directory for external access (e.g., Obsidian)
	"""
	return ProjectSettings.globalize_path("user://" + VAULT_PATH)
