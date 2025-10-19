## MemoryComponent: Gives a WorldObject memory capabilities
##
## Objects with this component can:
## - Automatically record own commands and results
## - Automatically record observations of others
## - Retrieve recent or relevant memories with multi-scale context
## - Store notes with semantic search
##
## Memory Compaction (Progressive Summarization):
## - Uses cascading temporal summaries (Anthropic context engineering pattern)
## - Three-tier system:
##   1. Immediate window (64 memories) - full detail, used as few-shot examples
##   2. Mid-term summary (prior 64 memories) - paragraph summary when compacted
##   3. Long-term summary (all older) - progressively compacted via waterfall
## - Compaction triggers at 256 total memories (not aggressive cutoff)
## - Waterfall pattern: old mid-term → long-term, fresh mid-term generated
## - Provides historical context without overwhelming LLM attention budget
## - Manual compaction via @compact-memories command
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
## - Shoggoth: For LLM-powered summarization (optional)
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

## Memory compaction summaries (multi-scale context retention)
## Recent summary: LLM-generated summary of memories that aged out of immediate window
var recent_summary: String = ""
## Long-term summary: Progressively compacted summary of all older memories
var longterm_summary: String = ""
## Last compaction timestamp (for tracking when summaries were generated)
var last_compaction_time: int = 0
## Bootstrap flag to prevent duplicate initialization
var _bootstrap_attempted: bool = false


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
		# Prevent duplicate connections (can happen during save/load cycles)
		if not actor_comp.command_executed.is_connected(_on_command_executed):
			if actor_comp.command_executed.connect(_on_command_executed) != OK:
				push_warning("MemoryComponent: Failed to connect to command_executed")

		# Record observations of others
		if not actor_comp.event_observed.is_connected(_on_event_observed):
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

	# Check if we should compact (threshold-based, async)
	# Note: Compaction is already async, so we just call it directly
	# The LLM calls within compact_memories_async() handle async execution
	if should_compact():
		compact_memories_async()

	# Bootstrap summaries if we have enough memories but no summaries yet
	_check_and_bootstrap_summaries()


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


func get_recent_context(count: int = 20) -> Dictionary:
	"""Get recent memories with multi-scale context summaries.

	This returns the most recent memories along with cascading temporal
	summaries for context retention beyond the immediate window.

	Args:
		count: Number of recent memories to retrieve (immediate window)

	Returns:
		Dictionary with keys:
		- immediate: Array[Dictionary] - Most recent N memories in full detail
		- recent_summary: String - Summary of memories that aged out
		- longterm_summary: String - Summary of all older memories
		- has_summaries: bool - True if any summaries exist

	Notes:
		Use this instead of get_recent_memories() for AI agent prompts
		to get the full multi-scale context.
	"""
	return {
		"immediate": get_recent_memories(count),
		"recent_summary": recent_summary,
		"longterm_summary": longterm_summary,
		"has_summaries": recent_summary != "" or longterm_summary != ""
	}


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


## Memory Compaction (Multi-scale Context Retention)

func _get_compaction_config(key: String, default: Variant) -> Variant:
	"""Get compaction configuration from vault.

	Args:
		key: Config key under "memory_compaction"
		default: Default value if not found

	Returns:
		Value from vault config or default
	"""
	if TextManager:
		return TextManager.get_config("memory_compaction." + key, default)
	return default


func compact_memories_async(callback: Callable = Callable()) -> void:
	"""Compact memories using waterfall pattern with LLM summaries.

	This implements cascading temporal summaries as described in Anthropic's
	context engineering article:

	1. Long-term summary = LLM(recent summary + long-term summary)
	2. Recent summary = LLM(memories outside immediate window)
	3. Immediate context = N newest memories (unchanged)

	The waterfall preserves historical context while keeping the most
	recent details in full fidelity.

	Args:
		callback: Optional callback when compaction completes

	Notes:
		- Uses /api/generate endpoint (optimized for base models)
		- Summaries stored in component properties
		- Called automatically when memories exceed threshold
		- Can be manually triggered via @compact-memories command
	"""
	if not Shoggoth or not Shoggoth.ollama_client:
		print("[Memory] %s: Compaction skipped (no LLM available)" % (owner.name if owner else "unknown"))
		if callback.is_valid():
			callback.call()
		return

	# Get config values
	var immediate_window: int = _get_compaction_config("immediate_window", 64)
	var recent_window: int = _get_compaction_config("recent_window", 64)

	# Nothing to compact if we have fewer memories than immediate window
	if memories.size() <= immediate_window:
		if callback.is_valid():
			callback.call()
		return

	print("[Memory] %s: Starting compaction (%d memories, %d immediate, %d recent)" % [
		owner.name if owner else "unknown",
		memories.size(),
		immediate_window,
		recent_window
	])

	# Step 1: Update long-term summary (combine recent + longterm)
	# Only if we have a recent summary to waterfall
	if recent_summary != "":
		_compact_longterm_async(func():
			# Step 2: Generate new recent summary from aged-out memories
			_compact_recent_async(immediate_window, recent_window, func():
				last_compaction_time = int(Time.get_unix_time_from_system())
				print("[Memory] %s: Compaction complete" % (owner.name if owner else "unknown"))
				if callback.is_valid():
					callback.call()
			)
		)
	else:
		# First compaction: just create recent summary
		_compact_recent_async(immediate_window, recent_window, func():
			last_compaction_time = int(Time.get_unix_time_from_system())
			print("[Memory] %s: Compaction complete (first run)" % (owner.name if owner else "unknown"))
			if callback.is_valid():
				callback.call()
		)


func _compact_longterm_async(callback: Callable) -> void:
	"""Update long-term summary by combining recent + longterm summaries.

	Args:
		callback: Called when summary generation completes
	"""
	# Build prompt for waterfall compaction (pure structural, no instructions)
	var prompt: String = "# Recent Summary:\n%s\n\n" % recent_summary
	if longterm_summary != "":
		prompt += "# Older Summary:\n%s\n\n" % longterm_summary
	prompt += "# Combined Summary:\n> "

	# Use generate mode with stop tokens
	Shoggoth.generate_async(
		prompt,
		_get_compaction_config("profile", "summarizer"),
		func(result: String):
			var summary: String = result.strip_edges()
			if summary != "":
				longterm_summary = summary
				print("[Memory] %s: Long-term summary updated (%d chars)" % [
					owner.name if owner else "unknown",
					longterm_summary.length()
				])
			callback.call()
	)


func _compact_recent_async(immediate_window: int, recent_window: int, callback: Callable) -> void:
	"""Generate recent summary from memories that aged out of immediate window.

	Args:
		immediate_window: Number of newest memories to keep in full detail
		recent_window: Number of memories before immediate to summarize
		callback: Called when summary generation completes
	"""
	# Calculate which memories to summarize
	var total: int = memories.size()
	var recent_start: int = max(0, total - immediate_window - recent_window)
	var recent_end: int = max(0, total - immediate_window)

	# Nothing to summarize if recent window is empty
	if recent_start >= recent_end:
		callback.call()
		return

	# Extract memories to summarize
	var memories_to_summarize: Array[Dictionary] = []
	for i in range(recent_start, recent_end):
		memories_to_summarize.append(memories[i])

	# Build prompt optimized for base models (leading structure)
	var prompt: String = "# Memories:\n"
	for memory in memories_to_summarize:
		prompt += "%s\n" % memory.content
	prompt += "\n# Summary:\n> "

	# Use generate mode with stop tokens
	Shoggoth.generate_async(
		prompt,
		_get_compaction_config("profile", "summarizer"),
		func(result: String):
			var summary: String = result.strip_edges()
			if summary != "":
				recent_summary = summary
				print("[Memory] %s: Recent summary updated (%d chars)" % [
					owner.name if owner else "unknown",
					recent_summary.length()
				])
			callback.call()
	)


func should_compact() -> bool:
	"""Check if memories should be compacted based on threshold.

	Returns:
		True if compaction should run (memories exceed threshold)

	Notes:
		Compacts when memories exceed configurable threshold (default: 256).
		This threshold should be significantly larger than immediate + recent windows
		to prevent overly aggressive compaction. Compaction is progressive:
		old mid-term → long-term, then fresh mid-term generated from aged-out memories.
	"""
	var compaction_threshold: int = _get_compaction_config("compaction_threshold", 256)

	return memories.size() > compaction_threshold


func _check_and_bootstrap_summaries() -> void:
	"""Check if agent needs bootstrap summaries and generate them if appropriate.

	Bootstrap happens when:
	- Agent has never attempted bootstrap before
	- Agent has sufficient memories IN VAULT (> immediate_window + recent_window)
	- Agent has no existing summaries
	- LLM is available

	This allows existing agents to benefit from the memory compaction system
	without waiting to accumulate 256+ memories for first compaction.

	Notes:
		Checks vault file count, not in-RAM count, since MemoryBudget may
		limit loaded memories while vault has full history.
	"""
	# Only bootstrap once per component lifetime
	if _bootstrap_attempted:
		return

	_bootstrap_attempted = true

	# Skip if no LLM available
	if not Shoggoth or not Shoggoth.ollama_client:
		return

	# Skip if we already have summaries
	if recent_summary != "" or longterm_summary != "":
		return

	# Skip if no owner (shouldn't happen but defensive)
	if not owner:
		return

	var immediate_window: int = _get_compaction_config("immediate_window", 64)
	var recent_window: int = _get_compaction_config("recent_window", 64)
	var bootstrap_threshold: int = immediate_window + recent_window

	# Check vault file count, not in-RAM count (MemoryBudget may limit loaded memories)
	var vault_count: int = get_vault_memory_count(owner.name)

	# Only bootstrap if we have enough memories to summarize
	if vault_count <= bootstrap_threshold:
		return

	print("[Memory] %s: Bootstrapping summaries (%d vault memories available, %d loaded)" % [
		owner.name,
		vault_count,
		memories.size()
	])

	# Generate initial summaries from existing memories
	bootstrap_summaries_async()


func bootstrap_summaries_async(callback: Callable = Callable()) -> void:
	"""Bootstrap initial summaries for agents with existing memories.

	Generates both mid-term and long-term summaries from the agent's
	existing memory history (loaded from vault), allowing them to immediately
	benefit from the multi-scale context system.

	Args:
		callback: Optional callback when bootstrap completes

	Notes:
		This is called automatically once per agent if they have sufficient
		memories but no existing summaries. It creates:
		1. Long-term summary from all oldest vault memories
		2. Mid-term summary from memories in the recent window

		Loads ALL memories from vault temporarily for summarization,
		regardless of MemoryBudget RAM limits.
	"""
	if not Shoggoth or not Shoggoth.ollama_client:
		if callback.is_valid():
			callback.call()
		return

	if not owner:
		if callback.is_valid():
			callback.call()
		return

	var immediate_window: int = _get_compaction_config("immediate_window", 64)
	var recent_window: int = _get_compaction_config("recent_window", 64)

	# Load ALL memories from vault (not limited by MemoryBudget)
	# We need the full history to generate accurate summaries
	var vault_count: int = get_vault_memory_count(owner.name)

	# Not enough vault memories to bootstrap
	if vault_count <= immediate_window:
		if callback.is_valid():
			callback.call()
		return

	print("[Memory] %s: Starting bootstrap (loading %d vault memories for summarization)" % [
		owner.name, vault_count
	])

	# Load all memories from vault for summarization
	var all_memories: Array[Dictionary] = load_memories_from_vault(owner.name, vault_count)

	print("[Memory] %s: Loaded %d memories from vault" % [owner.name, all_memories.size()])

	# Step 1: Generate long-term summary from older memories (everything except immediate + recent)
	var longterm_end: int = max(0, all_memories.size() - immediate_window - recent_window)
	if longterm_end > 0:
		_bootstrap_longterm_summary_from_array(all_memories, longterm_end, func():
			# Step 2: Generate mid-term summary from recent window
			_bootstrap_midterm_summary_from_array(all_memories, immediate_window, recent_window, func():
				last_compaction_time = int(Time.get_unix_time_from_system())
				print("[Memory] %s: Bootstrap complete" % owner.name)
				if callback.is_valid():
					callback.call()
			)
		)
	else:
		# No long-term memories, just generate mid-term
		_bootstrap_midterm_summary_from_array(all_memories, immediate_window, recent_window, func():
			last_compaction_time = int(Time.get_unix_time_from_system())
			print("[Memory] %s: Bootstrap complete (mid-term only)" % owner.name)
			if callback.is_valid():
				callback.call()
		)


func _bootstrap_longterm_summary_from_array(all_memories: Array[Dictionary], end_index: int, callback: Callable) -> void:
	"""Generate initial long-term summary from oldest memories in array.

	Args:
		all_memories: Full memory array loaded from vault
		end_index: Index up to which to summarize (non-inclusive)
		callback: Called when summary generation completes
	"""
	# Gather oldest memories for long-term summary
	var memories_to_summarize: Array[Dictionary] = []
	for i in range(0, end_index):
		memories_to_summarize.append(all_memories[i])

	if memories_to_summarize.size() == 0:
		callback.call()
		return

	# Build prompt optimized for base models (leading structure)
	var prompt: String = "# Memories:\n"
	for memory in memories_to_summarize:
		prompt += "%s\n" % memory.content
	prompt += "\n# Summary:\n> "

	# Generate summary
	Shoggoth.generate_async(
		prompt,
		_get_compaction_config("profile", "summarizer"),
		func(result: String):
			var summary: String = result.strip_edges()
			if summary != "":
				longterm_summary = summary
				print("[Memory] %s: Long-term summary created (%d chars from %d memories)" % [
					owner.name if owner else "unknown",
					longterm_summary.length(),
					memories_to_summarize.size()
				])
			callback.call()
	)


func _bootstrap_midterm_summary_from_array(all_memories: Array[Dictionary], immediate_window: int, recent_window: int, callback: Callable) -> void:
	"""Generate initial mid-term summary from recent window in array.

	Args:
		all_memories: Full memory array loaded from vault
		immediate_window: Number of newest memories to skip (keep in full detail)
		recent_window: Number of memories before immediate to summarize
		callback: Called when summary generation completes
	"""
	# Calculate which memories to summarize for mid-term
	var total: int = all_memories.size()
	var recent_start: int = max(0, total - immediate_window - recent_window)
	var recent_end: int = max(0, total - immediate_window)

	if recent_start >= recent_end:
		callback.call()
		return

	# Extract memories to summarize
	var memories_to_summarize: Array[Dictionary] = []
	for i in range(recent_start, recent_end):
		memories_to_summarize.append(all_memories[i])

	# Build prompt optimized for base models (leading structure)
	var prompt: String = "# Memories:\n"
	for memory in memories_to_summarize:
		prompt += "%s\n" % memory.content
	prompt += "\n# Summary:\n> "

	# Generate summary
	Shoggoth.generate_async(
		prompt,
		_get_compaction_config("profile", "summarizer"),
		func(result: String):
			var summary: String = result.strip_edges()
			if summary != "":
				recent_summary = summary
				print("[Memory] %s: Mid-term summary created (%d chars from %d memories)" % [
					owner.name if owner else "unknown",
					recent_summary.length(),
					memories_to_summarize.size()
				])
			callback.call()
	)


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


func get_vault_memory_count(owner_name: String) -> int:
	"""Count total memory files in vault (not just loaded in RAM).

	Args:
		owner_name: Name of the agent (for directory path)

	Returns:
		Total number of memory files stored in vault

	Notes:
		Used to determine if bootstrap is worthwhile, since in-RAM
		memory count may be limited by MemoryBudget.
	"""
	var agent_path: String = MarkdownVault.AGENTS_PATH + "/" + MarkdownVault.sanitize_filename(owner_name)
	var mem_path: String = agent_path + "/memories"

	var files: Array[String] = MarkdownVault.list_files(mem_path, ".md")
	return files.size()


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


## Memory Integrity Checks

func get_integrity_status() -> Dictionary:
	"""Check memory system integrity and return status summary.

	Performs lightweight integrity checks that make sense for a text game:
	- Memory count and capacity utilization
	- Note count and recent activity
	- Detection of stale memories (none added recently)
	- Basic validation of memory structure

	Returns:
		Dictionary with keys:
		- status: String ("OK", "WARNING", "ERROR")
		- summary: String (brief one-line status, suitable for command prompt)
		- memory_count: int (number of memories in RAM)
		- note_count: int (number of notes cached)
		- capacity_used: float (percentage of max_memories used, 0.0-1.0)
		- warnings: Array[String] (list of issues found)
		- last_memory_age: int (seconds since last memory was added)

	Notes:
		This is optimized for unobtrusive display - "OK" is the expected default.
		Trust the OS for file integrity; focus on application-level concerns.
	"""
	var status_result: Dictionary = {
		"status": "OK",
		"summary": "[Memory: OK]",
		"memory_count": memories.size(),
		"note_count": notes.size(),
		"capacity_used": 0.0,
		"warnings": [],
		"last_memory_age": 0
	}

	# Calculate capacity utilization
	if max_memories > 0:
		status_result.capacity_used = float(memories.size()) / float(max_memories)

	# Check for stale memories (no activity in past hour)
	if memories.size() > 0:
		var last_memory: Dictionary = memories[memories.size() - 1]
		var last_timestamp: int = last_memory.get("timestamp", 0)
		var current_time: int = int(Time.get_unix_time_from_system())
		var age_seconds: int = current_time - last_timestamp
		status_result.last_memory_age = age_seconds

		# Warn if no memories recorded in past hour (3600 seconds)
		if age_seconds > 3600:
			status_result.warnings.append("No recent memory activity (last: %d min ago)" % int(age_seconds / 60.0))

	# Warn if approaching capacity
	if status_result.capacity_used > 0.9:
		status_result.warnings.append("Memory near capacity (%d/%d)" % [memories.size(), max_memories])
	elif status_result.capacity_used > 0.75:
		status_result.warnings.append("Memory 75%% full (%d/%d)" % [memories.size(), max_memories])

	# Basic structure validation (sanity checks)
	var malformed_count: int = 0
	for memory in memories:
		if not memory.has("content") or not memory.has("timestamp"):
			malformed_count += 1

	if malformed_count > 0:
		status_result.warnings.append("%d malformed memories detected" % malformed_count)

	# Determine overall status
	if status_result.warnings.size() > 0:
		status_result.status = "WARNING"
		status_result.summary = "[Memory: WARNING - %d issues]" % status_result.warnings.size()
	else:
		status_result.status = "OK"
		status_result.summary = "[Memory: OK]"

	return status_result


func format_integrity_report() -> String:
	"""Generate a detailed human-readable integrity report.

	Returns:
		Formatted multi-line string suitable for @memory-status command output

	Notes:
		Provides comprehensive details beyond the one-line status summary.
	"""
	var status: Dictionary = get_integrity_status()

	var report: String = "# Memory System Integrity Report\n\n"

	# Overall status
	report += "**Status**: %s\n\n" % status.status

	# Statistics
	report += "## Statistics\n\n"
	report += "- **Memories in RAM**: %d / %d (%.1f%% capacity)\n" % [
		status.memory_count,
		max_memories,
		status.capacity_used * 100.0
	]
	report += "- **Notes cached**: %d\n" % status.note_count

	if status.last_memory_age > 0:
		var age_display: String = ""
		if status.last_memory_age < 60:
			age_display = "%d seconds ago" % status.last_memory_age
		elif status.last_memory_age < 3600:
			age_display = "%d minutes ago" % (status.last_memory_age / 60)
		else:
			age_display = "%.1f hours ago" % (status.last_memory_age / 3600.0)
		report += "- **Last memory recorded**: %s\n" % age_display
	elif memories.size() == 0:
		report += "- **Last memory recorded**: Never (no memories yet)\n"

	report += "\n"

	# Warnings (if any)
	if status.warnings.size() > 0:
		report += "## Warnings\n\n"
		for warning in status.warnings:
			report += "- ⚠ %s\n" % warning
		report += "\n"

	# Notes on trust and design
	report += "## Notes\n\n"
	report += "- Memory data persists to vault in real-time as markdown files\n"
	report += "- File integrity is handled by OS-level mechanisms\n"
	report += "- This report focuses on application-level concerns\n"
	report += "- Use 'recall' command to verify memory content is accessible\n"

	return report
