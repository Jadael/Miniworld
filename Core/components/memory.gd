## Memory Component: Gives a WorldObject memory capabilities
##
## Objects with this component can:
## - Record observations and actions
## - Retrieve recent or relevant memories
## - Store notes
##
## This maps to the Python prototype's memory system.

extends ComponentBase
class_name MemoryComponent

## Memory storage
var memories: Array[Dictionary] = []  # List of memory entries
var notes: Dictionary = {}  # title -> note_content
var max_memories: int = 100  # Limit on memory storage

func _on_added(obj: WorldObject) -> void:
	super._on_added(obj)

	# Connect to the actor component's event observation if present
	if obj.has_component("actor"):
		var actor_comp = obj.get_component("actor")
		if actor_comp.event_observed.connect(_on_event_observed) != OK:
			push_warning("MemoryComponent: Failed to connect to actor events")

func _on_removed(obj: WorldObject) -> void:
	# Disconnect from actor component
	if owner.has_component("actor"):
		var actor_comp = owner.get_component("actor")
		if actor_comp.event_observed.is_connected(_on_event_observed):
			actor_comp.event_observed.disconnect(_on_event_observed)

	super._on_removed(obj)

## Record a memory
func add_memory(memory_type: String, content: String, metadata: Dictionary = {}) -> void:
	"""Add a new memory entry"""
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

## Get recent memories
func get_recent_memories(count: int = 10) -> Array[Dictionary]:
	"""Get the most recent N memories"""
	var start_idx = max(0, memories.size() - count)
	return memories.slice(start_idx, memories.size())

## Get all memories
func get_all_memories() -> Array[Dictionary]:
	return memories

## Clear all memories
func clear_memories() -> void:
	memories.clear()

## Add a note
func add_note(title: String, content: String) -> void:
	"""Create or update a note"""
	notes[title] = {
		"content": content,
		"created": Time.get_unix_time_from_system()
	}

## Get a note
func get_note(title: String) -> Dictionary:
	return notes.get(title, {})

## Get all note titles
func get_note_titles() -> Array[String]:
	var titles: Array[String] = []
	for title in notes.keys():
		titles.append(title)
	return titles

## Remove a note
func remove_note(title: String) -> void:
	notes.erase(title)

## Event handler: automatically record observed events as memories
func _on_event_observed(event: Dictionary) -> void:
	"""Automatically create memories from observed events"""
	var memory_content = EventWeaver.format_event(event)

	if memory_content != "":
		add_memory("observed", memory_content, {
			"event_type": event.get("type", "unknown"),
			"location": event.get("location")
		})

## Format memories as text
func format_memories_as_text(count: int = 10) -> String:
	"""Get recent memories formatted as readable text"""
	var recent = get_recent_memories(count)

	if recent.size() == 0:
		return "No memories."

	var text = "Recent memories:\n"
	for memory in recent:
		var timestamp = Time.get_datetime_string_from_unix_time(memory["timestamp"])
		text += "  [%s] %s\n" % [timestamp, memory["content"]]

	return text

## Format notes as text
func format_notes_as_text() -> String:
	"""Get all notes formatted as readable text"""
	if notes.size() == 0:
		return "No notes."

	var text = "Notes:\n"
	for title in notes.keys():
		var note = notes[title]
		text += "  - %s: %s\n" % [title, note["content"]]

	return text
