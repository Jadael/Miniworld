## NarrativeLog: Silent observer logging system
## Records all narrative events from a third-person perspective for review.
## Maintains both global chronicle and per-location logs in human-readable markdown.
##
## Dependencies: EventWeaver (for world_event signal)
## Storage: user://vault/narrative/ (chronicle.md and locations/*.md)

extends Node

## Maximum entries to keep in memory before pruning older entries
const MAX_ENTRIES_PER_LOG: int = 1000

## Maximum entries to show when viewing logs
const DEFAULT_VIEW_LIMIT: int = 50

## In-memory storage: location_id -> Array[String] (formatted lines)
var _location_logs: Dictionary = {}

## In-memory storage: Array[String] (formatted lines for global chronicle)
var _chronicle: Array[String] = []

## Vault paths
const NARRATIVE_DIR: String = "user://vault/narrative"
const CHRONICLE_PATH: String = "user://vault/narrative/chronicle.md"
const LOCATIONS_DIR: String = "user://vault/narrative/locations"


func _ready() -> void:
	name = "NarrativeLog"
	_ensure_directories()
	_load_existing_logs()
	_connect_to_events()
	print("[NarrativeLog] Ready - silent observer active")


## Ensure vault directories exist
func _ensure_directories() -> void:
	DirAccess.make_dir_recursive_absolute(NARRATIVE_DIR)
	DirAccess.make_dir_recursive_absolute(LOCATIONS_DIR)


## Load existing logs from vault on startup
func _load_existing_logs() -> void:
	# Load global chronicle
	if FileAccess.file_exists(CHRONICLE_PATH):
		var file := FileAccess.open(CHRONICLE_PATH, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var lines: PackedStringArray = content.split("\n")
			_chronicle.assign(lines)
			print("[NarrativeLog] Loaded %d chronicle entries" % _chronicle.size())

	# Load per-location logs
	var dir := DirAccess.open(LOCATIONS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".md"):
				var location_id := file_name.trim_suffix(".md")
				var file_path := LOCATIONS_DIR.path_join(file_name)
				var file := FileAccess.open(file_path, FileAccess.READ)
				if file:
					var content := file.get_as_text()
					file.close()
					var lines: PackedStringArray = content.split("\n")
					var location_array: Array[String] = []
					location_array.assign(lines)
					_location_logs[location_id] = location_array
			file_name = dir.get_next()
		dir.list_dir_end()
		print("[NarrativeLog] Loaded %d location logs" % _location_logs.size())


## Connect to EventWeaver's world_event signal
func _connect_to_events() -> void:
	if EventWeaver.has_signal("world_event"):
		EventWeaver.world_event.connect(_on_world_event)
		print("[NarrativeLog] Connected to EventWeaver.world_event")
	else:
		push_error("[NarrativeLog] EventWeaver.world_event signal not found!")


## Handle world events from EventWeaver
func _on_world_event(event: Dictionary) -> void:
	# Filter out "ambient" events (thinking behaviors)
	if event.get("event_type") == "ambient":
		return

	# Get location info
	var location: WorldObject = event.get("location")
	if not location:
		return

	var location_id: String = _get_location_id(location)
	var location_name: String = location.name if location.name else "Unknown Location"

	# Format event text from observer perspective
	var event_text: String = EventWeaver.format_event(event)
	if event_text.is_empty():
		return

	# Append reasoning in parentheses if present (silent observer only, not shown to players/agents)
	var reason: String = event.get("reason", "")
	if reason and not reason.is_empty():
		event_text += " (" + reason + ")"

	# Create timestamp
	var time_dict: Dictionary = Time.get_datetime_dict_from_system()
	var timestamp: String = "%04d-%02d-%02d %02d:%02d:%02d" % [
		time_dict.year, time_dict.month, time_dict.day,
		time_dict.hour, time_dict.minute, time_dict.second
	]

	# Format chronicle entry (includes location)
	var chronicle_entry: String = "**[%s]** *%s* — %s" % [timestamp, location_name, event_text]

	# Format location log entry (no location name needed)
	var location_entry: String = "**[%s]** %s" % [timestamp, event_text]

	# Add to in-memory logs
	_chronicle.append(chronicle_entry)
	if not _location_logs.has(location_id):
		_location_logs[location_id] = []
	_location_logs[location_id].append(location_entry)

	# Prune if needed
	if _chronicle.size() > MAX_ENTRIES_PER_LOG:
		_chronicle = _chronicle.slice(-MAX_ENTRIES_PER_LOG)
	if _location_logs[location_id].size() > MAX_ENTRIES_PER_LOG:
		_location_logs[location_id] = _location_logs[location_id].slice(-MAX_ENTRIES_PER_LOG)

	# Save to vault immediately (async in real usage, but simple for now)
	_save_chronicle()
	_save_location_log(location_id)


## Get stable location ID (prefer object ID, fallback to name hash)
func _get_location_id(location: WorldObject) -> String:
	# Use the object's ID field if available
	if location.id and not location.id.is_empty():
		return location.id
	# Fallback: use name as ID
	var loc_name: String = location.name if location.name else "unknown"
	return loc_name.replace(" ", "_").to_lower()


## Save global chronicle to vault
func _save_chronicle() -> void:
	var file := FileAccess.open(CHRONICLE_PATH, FileAccess.WRITE)
	if file:
		file.store_string("# Miniworld Chronicle\n\n")
		file.store_string("*A silent observer's account of events across all locations.*\n\n")
		file.store_string("---\n\n")
		for line in _chronicle:
			file.store_string(line + "\n")
		file.close()


## Save per-location log to vault
func _save_location_log(location_id: String) -> void:
	if not _location_logs.has(location_id):
		return

	var file_path := LOCATIONS_DIR.path_join(location_id + ".md")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string("# Location: %s\n\n" % location_id)
		file.store_string("*Events observed at this location.*\n\n")
		file.store_string("---\n\n")
		for line in _location_logs[location_id]:
			file.store_string(line + "\n")
		file.close()


## Get recent chronicle entries (for @narrative command)
## Args:
##   limit: Maximum number of recent entries to return
## Returns: Array of formatted strings
func get_chronicle(limit: int = DEFAULT_VIEW_LIMIT) -> Array[String]:
	var result: Array[String] = []
	var start_idx: int = max(0, _chronicle.size() - limit)
	for i in range(start_idx, _chronicle.size()):
		result.append(_chronicle[i])
	return result


## Get recent entries for a specific location (for @narrative-here command)
## Args:
##   location_id: The location identifier
##   limit: Maximum number of recent entries to return
## Returns: Array of formatted strings
func get_location_log(location_id: String, limit: int = DEFAULT_VIEW_LIMIT) -> Array[String]:
	if not _location_logs.has(location_id):
		return []

	var result: Array[String] = []
	var entries: Array = _location_logs[location_id]
	var start_idx: int = max(0, entries.size() - limit)
	for i in range(start_idx, entries.size()):
		result.append(entries[i])
	return result


## Get all known location IDs
## Returns: Array of location ID strings
func get_known_locations() -> Array[String]:
	var result: Array[String] = []
	result.assign(_location_logs.keys())
	return result


## Clear all narrative logs (admin command)
func clear_all() -> void:
	_chronicle.clear()
	_location_logs.clear()

	# Clear vault files
	if FileAccess.file_exists(CHRONICLE_PATH):
		DirAccess.remove_absolute(CHRONICLE_PATH)

	var dir := DirAccess.open(LOCATIONS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".md"):
				DirAccess.remove_absolute(LOCATIONS_DIR.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()

	print("[NarrativeLog] All logs cleared")


## Clear log for specific location (admin command)
func clear_location(location_id: String) -> void:
	if _location_logs.has(location_id):
		_location_logs.erase(location_id)
		var file_path := LOCATIONS_DIR.path_join(location_id + ".md")
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
		print("[NarrativeLog] Cleared log for location: %s" % location_id)
