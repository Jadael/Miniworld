## MemoryComponent: Gives a WorldObject memory capabilities
##
## Objects with this component can:
## - Record observations and actions
## - Retrieve recent or relevant memories
## - Store notes
##
## This maps to the Python prototype's memory system, enabling both
## AI agents and players to maintain persistent memory of events and experiences.
##
## Related: ActorComponent (source of observed events), ThinkerComponent (uses memories for AI decisions)

extends ComponentBase
class_name MemoryComponent


## Chronological list of memory entries
## Each entry is a Dictionary with: type, content, timestamp, metadata
var memories: Array[Dictionary] = []

## Persistent notes indexed by title
## Format: {title: {content: String, created: int}}
var notes: Dictionary = {}

## Maximum memories to retain before oldest are pruned
var max_memories: int = 100


func _on_added(obj: WorldObject) -> void:
	"""Initialize memory component and connect to actor events if present.

	Args:
		obj: The WorldObject this component is being added to
	"""
	super._on_added(obj)

	# Connect to actor events for automatic memory recording
	if obj.has_component("actor"):
		var actor_comp = obj.get_component("actor")
		if actor_comp.event_observed.connect(_on_event_observed) != OK:
			push_warning("MemoryComponent: Failed to connect to actor events")


func _on_removed(obj: WorldObject) -> void:
	"""Clean up memory component and disconnect from actor events.

	Args:
		obj: The WorldObject this component is being removed from
	"""
	# Disconnect from actor component
	if owner.has_component("actor"):
		var actor_comp = owner.get_component("actor")
		if actor_comp.event_observed.is_connected(_on_event_observed):
			actor_comp.event_observed.disconnect(_on_event_observed)

	super._on_removed(obj)


func add_memory(memory_type: String, content: String, metadata: Dictionary = {}) -> void:
	"""Record a new memory entry and save it to vault immediately.

	Memories are automatically pruned when max_memories limit is exceeded.
	Each memory is also saved as an individual markdown file in real-time.

	Args:
		memory_type: Type of memory ("observed", "action", "thought", etc.)
		content: The memory content text
		metadata: Optional additional data (event_type, location, etc.)

	Notes:
		Saves to vault in real-time for immediate persistence
	"""
	var memory = {
		"type": memory_type,
		"content": content,
		"timestamp": Time.get_unix_time_from_system(),
		"metadata": metadata
	}

	memories.append(memory)

	# Save to vault immediately if owner exists
	if owner:
		save_memory_to_vault(owner.name, content, memory_type)

	# Trim old memories if we exceed the limit
	if memories.size() > max_memories:
		memories = memories.slice(memories.size() - max_memories, memories.size())


func get_recent_memories(count: int = 10) -> Array[Dictionary]:
	"""Get the most recent N memories.

	Args:
		count: Number of recent memories to retrieve

	Returns:
		Array of memory Dictionaries, newest last
	"""
	var start_idx = max(0, memories.size() - count)
	return memories.slice(start_idx, memories.size())


func get_all_memories() -> Array[Dictionary]:
	"""Get all stored memories.

	Returns:
		Complete chronological array of memory Dictionaries
	"""
	return memories


func clear_memories() -> void:
	"""Erase all stored memories.

	Notes:
		Does not affect notes, only memories
	"""
	memories.clear()


func add_note(title: String, content: String) -> void:
	"""Create or update a persistent note.

	Args:
		title: Unique identifier for the note
		content: The note text content
	"""
	notes[title] = {
		"content": content,
		"created": Time.get_unix_time_from_system()
	}


func get_note(title: String) -> Dictionary:
	"""Retrieve a note by title.

	Args:
		title: The note's unique identifier

	Returns:
		Note Dictionary with 'content' and 'created' keys, or empty Dictionary if not found
	"""
	return notes.get(title, {})


func get_note_titles() -> Array[String]:
	"""Get all note titles.

	Returns:
		Array of note title strings
	"""
	var titles: Array[String] = []
	for title in notes.keys():
		titles.append(title)
	return titles


func remove_note(title: String) -> void:
	"""Delete a note.

	Args:
		title: The note's unique identifier
	"""
	notes.erase(title)


func _on_event_observed(event: Dictionary) -> void:
	"""Automatically create memories from observed events.

	Connected to ActorComponent.event_observed signal.

	Args:
		event: Event Dictionary from EventWeaver
	"""
	var memory_content = EventWeaver.format_event(event)

	if memory_content != "":
		add_memory("observed", memory_content, {
			"event_type": event.get("type", "unknown"),
			"location": event.get("location")
		})


func format_memories_as_text(count: int = 10) -> String:
	"""Format recent memories as human-readable text.

	Args:
		count: Number of recent memories to include

	Returns:
		Formatted multi-line string of memories
	"""
	var recent = get_recent_memories(count)

	if recent.size() == 0:
		return "No memories."

	var text = "Recent memories:\n"
	for memory in recent:
		var timestamp = Time.get_datetime_string_from_unix_time(memory["timestamp"])
		text += "  [%s] %s\n" % [timestamp, memory["content"]]

	return text


func format_notes_as_text() -> String:
	"""Format all notes as human-readable text.

	Returns:
		Formatted multi-line string of notes
	"""
	if notes.size() == 0:
		return "No notes."

	var text = "Notes:\n"
	for title in notes.keys():
		var note = notes[title]
		text += "  - %s: %s\n" % [title, note["content"]]

	return text


## Markdown Vault Persistence

func save_memory_to_vault(owner_name: String, memory_text: String, memory_type: String) -> void:
	"""Save a memory as a markdown file in the agent's vault.

	Args:
		owner_name: Name of the agent (for directory path)
		memory_text: The memory content
		memory_type: "observed", "action", "response", or "thought"

	Notes:
		Creates individual timestamped markdown files for each memory
	"""
	var timestamp: String = MarkdownVault.get_filename_timestamp()
	var filename: String = "%s-%s.md" % [timestamp, memory_type]
	var agent_path: String = MarkdownVault.AGENTS_PATH + "/" + MarkdownVault.sanitize_filename(owner_name)
	var mem_path: String = agent_path + "/memories/" + filename

	# Create frontmatter
	var frontmatter: Dictionary = {
		"timestamp": MarkdownVault.get_timestamp(),
		"type": memory_type,
		"importance": 5  # Default importance (could be calculated later)
	}

	var content: String = MarkdownVault.create_frontmatter(frontmatter)
	content += "# Memory\n\n"
	content += memory_text + "\n"

	MarkdownVault.write_file(mem_path, content)


func load_memories_from_vault(owner_name: String, max_count: int = 50) -> Array[Dictionary]:
	"""Load recent memories from the vault.

	Args:
		owner_name: Name of the agent (for directory path)
		max_count: Maximum number of memories to load

	Returns:
		Array of memory Dictionaries loaded from vault

	Notes:
		Loads most recent memories up to max_count
		Memories are sorted by timestamp (filename)
	"""
	var agent_path: String = MarkdownVault.AGENTS_PATH + "/" + MarkdownVault.sanitize_filename(owner_name)
	var mem_path: String = agent_path + "/memories"

	var files: Array[String] = MarkdownVault.list_files(mem_path, ".md")
	files.sort()  # Sort by timestamp (filename)
	files.reverse()  # Most recent first

	var loaded_memories: Array[Dictionary] = []
	for i in range(min(max_count, files.size())):
		var content: String = MarkdownVault.read_file(mem_path + "/" + files[i])
		if content.is_empty():
			continue

		var parsed: Dictionary = MarkdownVault.parse_frontmatter(content)

		loaded_memories.append({
			"type": parsed.frontmatter.get("type", "unknown"),
			"content": parsed.body.strip_edges().replace("# Memory\n\n", ""),
			"timestamp": _parse_iso_timestamp(parsed.frontmatter.get("timestamp", "")),
			"metadata": {}
		})

	return loaded_memories


func save_all_memories_to_vault(owner_name: String) -> void:
	"""Save all current memories to the vault.

	Args:
		owner_name: Name of the agent (for directory path)

	Notes:
		Saves each memory as an individual markdown file
		Used during world save operations
	"""
	for memory in memories:
		var memory_type: String = memory.get("type", "unknown")
		var memory_content: String = memory.get("content", "")

		save_memory_to_vault(owner_name, memory_content, memory_type)


func _parse_iso_timestamp(iso_string: String) -> int:
	"""Parse ISO 8601 timestamp to Unix timestamp.

	Args:
		iso_string: ISO 8601 format timestamp (e.g., "2025-03-12T14:30:22Z")

	Returns:
		Unix timestamp as integer, or current time if parsing fails

	Notes:
		Simplified parser for ISO 8601 format used by MarkdownVault
	"""
	if iso_string.is_empty():
		return int(Time.get_unix_time_from_system())

	# Parse format: YYYY-MM-DDTHH:MM:SSZ
	var parts: Array = iso_string.replace("Z", "").split("T")
	if parts.size() != 2:
		return int(Time.get_unix_time_from_system())

	var date_parts: Array = parts[0].split("-")
	var time_parts: Array = parts[1].split(":")

	if date_parts.size() != 3 or time_parts.size() != 3:
		return int(Time.get_unix_time_from_system())

	var datetime: Dictionary = {
		"year": int(date_parts[0]),
		"month": int(date_parts[1]),
		"day": int(date_parts[2]),
		"hour": int(time_parts[0]),
		"minute": int(time_parts[1]),
		"second": int(time_parts[2])
	}

	return int(Time.get_unix_time_from_datetime_dict(datetime))
