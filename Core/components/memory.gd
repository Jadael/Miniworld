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
	"""Record a new memory entry.

	Memories are automatically pruned when max_memories limit is exceeded.

	Args:
		memory_type: Type of memory ("observed", "action", "thought", etc.)
		content: The memory content text
		metadata: Optional additional data (event_type, location, etc.)
	"""
	var memory = {
		"type": memory_type,
		"content": content,
		"timestamp": Time.get_unix_time_from_system(),
		"metadata": metadata
	}

	memories.append(memory)

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
