## MemoryComponent: Gives a WorldObject memory capabilities
##
## Objects with this component can:
## - Automatically record own commands and results
## - Automatically record observations of others
## - Retrieve recent or relevant memories
## - Store notes
##
## This component automatically connects to ActorComponent signals when both
## are present on the same WorldObject, enabling seamless memory recording
## for both AI agents and players.
##
## Memory Format:
## - Command echoes: "> command args | reason\nresult"
## - Observations: Formatted event text (no > prefix)
##
## Memory Limits:
## - Uses MemoryBudget daemon for dynamic sizing based on system resources
## - Vault files persist indefinitely (only in-RAM cache is limited)
## - Limit recalculates automatically as agents are added/removed
##
## Dependencies:
## - ActorComponent: Auto-connects for memory recording (optional but recommended)
## - MarkdownVault: For persistence to disk
## - MemoryBudget: Dynamic memory allocation based on system resources
##
## Related: ThinkerComponent (uses memories for AI decisions)

extends ComponentBase
class_name MemoryComponent


## Chronological list of memory entries
## Each entry is a Dictionary with: type, content, timestamp, metadata
var memories: Array[Dictionary] = []

## Persistent notes indexed by title (in-memory cache)
## Format: {title: {content: String, filepath: String, created: int}}
var notes: Dictionary = {}

## Maximum memories to retain before oldest are pruned (dynamically calculated)
var max_memories: int = 65536  # Default fallback if MemoryBudget unavailable

## VectorStore component for semantic search
var vector_store: VectorStoreComponent = null


func _on_added(obj: WorldObject) -> void:
	"""Initialize memory component and connect to actor events if present.

	Args:
		obj: The WorldObject this component is being added to
	"""
	super._on_added(obj)

	# Create VectorStore component
	vector_store = VectorStoreComponent.new()
	vector_store.owner = obj
	vector_store._on_added(obj)

	# Load notes from vault
	load_notes_from_vault(obj.name)

	# Connect to actor events for automatic memory recording
	if obj.has_component("actor"):
		var actor_comp: ActorComponent = obj.get_component("actor") as ActorComponent

		# Record own commands and their results
		if actor_comp.command_executed.connect(_on_command_executed) != OK:
			push_warning("MemoryComponent: Failed to connect to command_executed")

		# Record observations of others
		if actor_comp.event_observed.connect(_on_event_observed) != OK:
			push_warning("MemoryComponent: Failed to connect to event_observed")


func _on_removed(obj: WorldObject) -> void:
	"""Clean up memory component and disconnect from actor events.

	Args:
		obj: The WorldObject this component is being removed from
	"""
	# Disconnect from actor component
	if owner.has_component("actor"):
		var actor_comp: ActorComponent = owner.get_component("actor") as ActorComponent

		if actor_comp.command_executed.is_connected(_on_command_executed):
			actor_comp.command_executed.disconnect(_on_command_executed)

		if actor_comp.event_observed.is_connected(_on_event_observed):
			actor_comp.event_observed.disconnect(_on_event_observed)

	super._on_removed(obj)


func add_memory(content: String, metadata: Dictionary = {}) -> void:
	"""Record a new memory entry and save it to vault immediately.

	Memories are automatically pruned when max_memories limit is exceeded.
	Each memory is also saved as an individual markdown file in real-time.

	Args:
		content: The memory content text (self-documenting format)
		metadata: Optional contextual data for frontmatter:
			- location: Current location name/ID
			- occupants: Array of other actors present
			- event_type: Type of event observed (speech, movement, etc.)
			- Any other contextual information

	Notes:
		Saves to vault in real-time for immediate persistence.
		Content format is self-documenting:
		- Lines starting with ">" are command echoes
		- Other lines are observations or results
	"""
	# DEBUG: Print what's being stored
	print("[Memory DEBUG] %s storing: %s" % [owner.name if owner else "unknown", content])

	# Build metadata with current context if owner exists
	var full_metadata: Dictionary = metadata.duplicate()
	if owner:
		var location: WorldObject = owner.get_location()
		if location:
			full_metadata["location"] = location.name
			full_metadata["location_id"] = location.id

			# Capture other actors present
			if location.has_component("location"):
				var occupants: Array[String] = []
				for obj in location.get_contents():
					if obj != owner and obj.has_component("actor"):
						occupants.append(obj.name)
				if occupants.size() > 0:
					full_metadata["occupants"] = occupants

	var memory = {
		"type": "memory",  # Simplified: all memories are just "memory"
		"content": content,
		"timestamp": Time.get_unix_time_from_system(),
		"metadata": full_metadata
	}

	memories.append(memory)

	# Save to vault immediately if owner exists
	if owner:
		save_memory_to_vault(owner.name, content, full_metadata)

	# Update limit from MemoryBudget (recalculates dynamically)
	if MemoryBudget:
		max_memories = MemoryBudget.get_memory_limit_for_agent(owner)

	# Trim old memories if we exceed the limit
	if memories.size() > max_memories:
		memories = memories.slice(memories.size() - max_memories, memories.size())


func add_memory_from_vault(content: String, metadata: Dictionary, timestamp: int) -> void:
	"""Add a memory loaded from vault WITHOUT triggering re-save.

	This is used when loading memories from disk to avoid creating
	duplicate vault entries.

	Args:
		content: The memory content text
		metadata: Metadata dictionary from vault frontmatter
		timestamp: Unix timestamp from vault

	Notes:
		Does NOT save to vault. Use this only for loading existing memories.
	"""
	var memory = {
		"type": "memory",
		"content": content,
		"timestamp": timestamp,
		"metadata": metadata
	}

	memories.append(memory)

	# Update limit from MemoryBudget (recalculates dynamically)
	if MemoryBudget:
		max_memories = MemoryBudget.get_memory_limit_for_agent(owner)

	# Trim old memories if we exceed the limit
	if memories.size() > max_memories:
		memories = memories.slice(memories.size() - max_memories, memories.size())


func get_recent_memories(count: int = 64) -> Array[Dictionary]:
	"""Get the most recent N memories in chronological order.

	Args:
		count: Number of recent memories to retrieve

	Returns:
		Array of memory Dictionaries in narrative order (oldest first, newest last)

	Notes:
		This is the correct order for AI agent prompts - events appear
		in the order they occurred.
	"""
	var start_idx = max(0, memories.size() - count)
	return memories.slice(start_idx, memories.size())


func get_all_memories() -> Array[Dictionary]:
	"""Get all stored memories.

	Returns:
		Complete chronological array of memory Dictionaries
	"""
	return memories


func get_random_memories(count: int = 5) -> Array[Dictionary]:
	"""Get a random sample of memories from the entire history.

	Args:
		count: Number of random memories to retrieve

	Returns:
		Array of randomly selected memory Dictionaries

	Notes:
		Used by DREAM command to surface older memories
		Returns fewer than count if not enough memories exist
	"""
	if memories.size() == 0:
		return []

	var result: Array[Dictionary] = []
	var available: Array[Dictionary] = memories.duplicate()

	# Shuffle and take up to count items
	available.shuffle()
	var take_count: int = min(count, available.size())

	for i in range(take_count):
		result.append(available[i])

	return result


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


func _on_command_executed(_cmd: String, result: Dictionary, reason: String) -> void:
	"""Automatically create memories from executed commands.

	Connected to ActorComponent.command_executed signal.

	Args:
		_cmd: The command verb (unused, we use last_command for full string)
		result: Command result Dictionary
		reason: Optional reasoning provided with command

	Notes:
		Records BOTH successful and failed commands so agents learn from mistakes
	"""
	# Get actor component to access full command string
	if not owner.has_component("actor"):
		return

	var actor_comp: ActorComponent = owner.get_component("actor") as ActorComponent
	var full_command: String = actor_comp.last_command

	# Format as MOO transcript: "> command | reason\nresult"
	var command_line: String = "> %s" % full_command
	if reason != "":
		command_line += " | %s" % reason

	# Prefix failures with "❌" for visibility
	var message: String = result.message
	if not result.success:
		message = "❌ " + message

	var transcript: String = "%s\n%s" % [command_line, message]

	add_memory(transcript)


func _on_event_observed(event: Dictionary) -> void:
	"""Automatically create memories from observed events.

	Connected to ActorComponent.event_observed signal.

	Args:
		event: Event Dictionary from EventWeaver

	Notes:
		Filters out "ambient" events (like thinking indicators) that are
		visible to players but don't provide useful context for AI agents.
	"""
	# Skip ambient events (visible to players but not useful for AI memory)
	var event_type: String = event.get("type", "unknown")
	if event_type == "ambient":
		return

	var memory_content = EventWeaver.format_event(event)

	if memory_content != "":
		add_memory(memory_content, {
			"event_type": event_type
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

func save_memory_to_vault(owner_name: String, memory_text: String, metadata: Dictionary) -> void:
	"""Save a memory as a markdown file in the agent's vault.

	Args:
		owner_name: Name of the agent (for directory path)
		memory_text: The memory content (self-documenting format)
		metadata: Dictionary of contextual information for frontmatter

	Notes:
		Creates individual timestamped markdown files for each memory.
		Frontmatter includes location, occupants, and other contextual data.
	"""
	var timestamp: String = MarkdownVault.get_filename_timestamp()
	var filename: String = "%s-memory.md" % timestamp
	var agent_path: String = MarkdownVault.AGENTS_PATH + "/" + MarkdownVault.sanitize_filename(owner_name)
	var mem_path: String = agent_path + "/memories/" + filename

	# Create frontmatter with contextual metadata
	var frontmatter: Dictionary = {
		"timestamp": MarkdownVault.get_timestamp(),
		"type": "memory"
	}

	# Add contextual metadata from the memory
	if metadata.has("location"):
		frontmatter["location"] = metadata.location
	if metadata.has("location_id"):
		frontmatter["location_id"] = metadata.location_id
	if metadata.has("occupants"):
		frontmatter["occupants"] = metadata.occupants
	if metadata.has("event_type"):
		frontmatter["event_type"] = metadata.event_type

	var content: String = MarkdownVault.create_frontmatter(frontmatter)
	content += "# Memory\n\n"
	content += memory_text + "\n"

	MarkdownVault.write_file(mem_path, content)


func load_memories_from_vault(owner_name: String, max_count: int = 50) -> Array[Dictionary]:
	"""Load recent memories from the vault in chronological order.

	Args:
		owner_name: Name of the agent (for directory path)
		max_count: Maximum number of memories to load

	Returns:
		Array of memory Dictionaries loaded from vault in narrative order (oldest to newest)

	Notes:
		Loads most recent memories up to max_count.
		Memories are sorted chronologically (oldest to newest) for narrative order.
		If there are more than max_count files, skips the oldest ones.
	"""
	var agent_path: String = MarkdownVault.AGENTS_PATH + "/" + MarkdownVault.sanitize_filename(owner_name)
	var mem_path: String = agent_path + "/memories"

	var files: Array[String] = MarkdownVault.list_files(mem_path, ".md")
	files.sort()  # Sort by timestamp (filename) - oldest to newest

	# Load all files (up to max_count) in chronological order
	var loaded_memories: Array[Dictionary] = []

	# If there are more files than max_count, skip the oldest ones
	var start_index: int = max(0, files.size() - max_count)
	for i in range(start_index, files.size()):
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
		var memory_content: String = memory.get("content", "")
		var memory_metadata: Dictionary = memory.get("metadata", {})

		save_memory_to_vault(owner_name, memory_content, memory_metadata)


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


## Note Management

func add_note_async(title: String, content: String, reason: String, callback: Callable, append_mode: bool = true) -> void:
	"""Create or update note with embedding generation.

	Args:
		title: Note title (unique key)
		content: Note body to write or append
		reason: Why this note was created
		callback: Called when embedding completes
		append_mode: If true (default), append to existing note; if false, overwrite
	"""
	# Save markdown file
	var sanitized_title: String = MarkdownVault.sanitize_filename(title)
	var agent_path: String = MarkdownVault.AGENTS_PATH + "/" + MarkdownVault.sanitize_filename(owner.name)
	var note_path: String = agent_path + "/notes/" + sanitized_title + ".md"

	var final_content: String = content
	var created_timestamp: String = MarkdownVault.get_timestamp()

	# If appending and note exists, combine with existing content
	if append_mode:
		var existing_file: String = MarkdownVault.read_file(note_path)
		if not existing_file.is_empty():
			var parsed: Dictionary = MarkdownVault.parse_frontmatter(existing_file)
			var existing_body: String = parsed.body.strip_edges()

			# Remove "# Title\n\n" header if present
			var header_pattern = "# " + title + "\n\n"
			if existing_body.begins_with(header_pattern):
				existing_body = existing_body.substr(header_pattern.length())

			# Preserve original creation timestamp
			created_timestamp = parsed.frontmatter.get("created", MarkdownVault.get_timestamp())

			# Append new content with separator
			final_content = existing_body + "\n\n---\n\n" + content

	var frontmatter: Dictionary = {
		"title": title,
		"created": created_timestamp,
		"updated": MarkdownVault.get_timestamp(),
		"reason": reason
	}
	if owner:
		var location: WorldObject = owner.get_location()
		if location:
			frontmatter["location"] = location.name

	var full_content: String = MarkdownVault.create_frontmatter(frontmatter)
	full_content += "# %s\n\n%s\n" % [title, final_content]

	MarkdownVault.write_file(note_path, full_content)

	# Cache note with combined content
	notes[title] = {"content": final_content, "filepath": note_path, "created": Time.get_unix_time_from_system()}

	# Generate embeddings asynchronously
	if Shoggoth and Shoggoth.ollama_client:
		Shoggoth.generate_embeddings_async([title, content], func(embeddings: Array):
			if embeddings.size() >= 2:
				var title_vec: Array = embeddings[0]
				var content_vec: Array = embeddings[1]
				var combined_vec: Array = _combine_vectors(title_vec, content_vec, 0.3, 0.7)

				vector_store.upsert_vector(sanitized_title, title_vec, content_vec, combined_vec, {
					"title": title,
					"updated_at": MarkdownVault.get_timestamp()
				})
			callback.call()
		)
	else:
		callback.call()


func recall_notes_async(query: String, callback: Callable) -> void:
	"""Search notes by semantic query.

	Args:
		query: Search phrase
		callback: Callable(result_text: String) - formatted results
	"""
	if not Shoggoth or not Shoggoth.ollama_client:
		callback.call("Semantic search unavailable.")
		return

	# Generate query embedding
	Shoggoth.generate_embeddings_async(query, func(embeddings: Array):
		if embeddings.size() == 0:
			callback.call("Failed to generate query embedding.")
			return

		var query_vec: Array = embeddings[0]

		# Find similar notes (top 10)
		var similar: Array[Dictionary] = vector_store.find_similar(query_vec, "combined_vector", 10, 0.0)

		# Load and format results
		var results: String = "Notes matching '%s':\n\n" % query
		if similar.size() == 0:
			results += "No notes found."
		else:
			for item in similar:
				var note_id: String = item.note_id
				var similarity: float = item.similarity
				var note_data: Dictionary = notes.get(note_id, {})
				if note_data.has("content"):
					var title: String = vector_store.vectors.get(note_id, {}).get("metadata", {}).get("title", note_id)
					results += "## %s (%d%% match)\n%s\n\n" % [title, int(similarity * 100), note_data.content]

		callback.call(results)
	)


func get_relevant_notes_for_context(location_name: String, occupants: Array[String], max_notes: int = 3) -> Array[Dictionary]:
	"""Find notes relevant to the current context (location, occupants, recent activity).

	Uses simple keyword matching to find notes that mention:
	- Current location name
	- Names of other actors present

	This is optimized for Thinker prompts - cheap, instant, and contextual.

	Args:
		location_name: Name of current location
		occupants: Array of actor names in the location
		max_notes: Maximum number of relevant notes to return (default 3)

	Returns:
		Array of Dictionaries with keys: title (String), content (String)
		Sorted by relevance (most relevant first)

	Notes:
		Returns empty array if no notes exist or no matches found.
		Performs case-insensitive matching.
	"""
	if notes.size() == 0:
		return []

	# Build search terms from context
	var search_terms: Array[String] = []
	if location_name != "" and location_name != "nowhere":
		search_terms.append(location_name.to_lower())
	for occupant in occupants:
		search_terms.append(occupant.to_lower())

	if search_terms.size() == 0:
		return []

	# Score each note by relevance
	var scored_notes: Array[Dictionary] = []
	for title in notes.keys():
		var note_data: Dictionary = notes[title]
		var title_lower: String = title.to_lower()
		var content_lower: String = note_data.content.to_lower()
		var combined_text: String = title_lower + " " + content_lower

		var score: int = 0
		for term in search_terms:
			# Count occurrences of each search term
			var pos: int = 0
			while true:
				pos = combined_text.find(term, pos)
				if pos == -1:
					break
				score += 1
				pos += term.length()

		if score > 0:
			scored_notes.append({
				"title": title,
				"content": note_data.content,
				"score": score
			})

	# Sort by score (highest first)
	scored_notes.sort_custom(func(a, b): return a.score > b.score)

	# Return top N results
	var results: Array[Dictionary] = []
	for i in range(min(max_notes, scored_notes.size())):
		results.append({
			"title": scored_notes[i].title,
			"content": scored_notes[i].content
		})

	return results


func recall_notes_instant(query: String) -> String:
	"""Search notes instantly using cached embeddings only (no async generation).

	This is optimized for AI agents who need immediate results without waiting
	for embedding generation. Uses simple keyword matching and returns:
	- Most recently edited note (for convenience)
	- All note titles (for reference)
	- Basic keyword search results (if query matches)

	Args:
		query: Search phrase (used for keyword matching)

	Returns:
		Formatted string with instant recall results

	Notes:
		Does not require Shoggoth or embedding generation.
		Falls back gracefully if no notes exist.
	"""
	if notes.size() == 0:
		return "You have no notes yet. Use 'note <title> -> <content>' to create one."

	var results: String = ""

	# Find most recently edited note
	var most_recent_title: String = ""
	var most_recent_timestamp: int = 0
	for title in notes.keys():
		var note_data: Dictionary = notes[title]
		var created: int = note_data.get("created", 0)
		if created > most_recent_timestamp:
			most_recent_timestamp = created
			most_recent_title = title

	# Show most recent note first (convenience)
	if most_recent_title != "":
		var recent_note: Dictionary = notes[most_recent_title]
		results += "## Most Recently Edited Note\n\n"
		results += "**%s**\n%s\n\n" % [most_recent_title, recent_note.content]

	# Show all note titles for reference
	results += "## All Notes (%d total)\n\n" % notes.size()
	var titles: Array[String] = []
	for title in notes.keys():
		titles.append(title)
	titles.sort()
	for title in titles:
		results += "- %s\n" % title
	results += "\n"

	# Keyword search (simple case-insensitive matching)
	var query_lower: String = query.to_lower()
	var matches: Array[String] = []

	for title in notes.keys():
		var note_data: Dictionary = notes[title]
		var title_lower: String = title.to_lower()
		var content_lower: String = note_data.content.to_lower()

		# Check if query matches title or content
		if query_lower in title_lower or query_lower in content_lower:
			matches.append(title)

	# Show keyword matches if any
	if matches.size() > 0:
		results += "## Notes Matching '%s' (%d found)\n\n" % [query, matches.size()]
		for title in matches:
			var note_data: Dictionary = notes[title]
			results += "**%s**\n%s\n\n" % [title, note_data.content]
	elif query != "":
		results += "## Keyword Search\n\nNo notes contain '%s'. Check the list above for available notes.\n" % query

	return results


func load_notes_from_vault(agent_name: String) -> void:
	"""Load notes from markdown files."""
	var agent_path: String = MarkdownVault.AGENTS_PATH + "/" + MarkdownVault.sanitize_filename(agent_name)
	var notes_path: String = agent_path + "/notes"

	var files: Array[String] = MarkdownVault.list_files(notes_path, ".md")

	for filename in files:
		var content: String = MarkdownVault.read_file(notes_path + "/" + filename)
		if content.is_empty():
			continue

		var parsed: Dictionary = MarkdownVault.parse_frontmatter(content)
		var title: String = parsed.frontmatter.get("title", filename.replace(".md", ""))
		var body: String = parsed.body.strip_edges()

		# Remove "# Title\n\n" header if present
		var header_pattern = "# " + title + "\n\n"
		if body.begins_with(header_pattern):
			body = body.substr(header_pattern.length())

		notes[title] = {
			"content": body,
			"filepath": notes_path + "/" + filename,
			"created": _parse_iso_timestamp(parsed.frontmatter.get("created", ""))
		}


func _combine_vectors(vec_a: Array, vec_b: Array, weight_a: float, weight_b: float) -> Array:
	"""Combine two vectors with weights and normalize."""
	var combined: Array = []
	var norm: float = 0.0

	for i in range(vec_a.size()):
		var val: float = weight_a * float(vec_a[i]) + weight_b * float(vec_b[i])
		combined.append(val)
		norm += val * val

	norm = sqrt(norm)
	if norm > 0.0:
		for i in range(combined.size()):
			combined[i] = float(combined[i]) / norm

	return combined
