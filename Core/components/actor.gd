## Actor Component: Makes a WorldObject able to perform actions
##
## Objects with this component can:
## - Execute commands (look, go, say, emote, etc.) with optional reasoning
## - Observe events in their location
## - Interact with other objects
##
## Both players and AI agents have this component.
##
## Command Privacy Model:
## - PUBLIC commands (broadcast events to observers):
##   - look, go, say, emote, examine (social/observable actions)
##   - @dig, @exit, @teleport (building/admin actions)
## - PRIVATE CONTENT with OBSERVABLE BEHAVIOR:
##   - think, dream, note, recall (internal mental processes)
##   - Observers see: "pauses in thought", "jots something down", etc.
##   - But content remains private (can't see what they're thinking/writing)
## - SILENT commands (no observable behavior):
##   - who, where, rooms (information queries)
##   - @save, @quit, @impersonate (admin/debug utilities)
##
## Dependencies:
## - ComponentBase: Base class for all components
## - WorldKeeper: Object registry and lifecycle manager
## - EventWeaver: Event propagation and observation system
## - LocationComponent: Required for location-based commands
##
## Notes:
## - All commands return a Dictionary with at least "success" and "message" keys
## - Commands can include optional reasoning via the reason parameter
## - Commands prefixed with @ are builder/admin commands
## - Movement commands automatically trigger look at destination
## - command_executed signal includes reason as third parameter

extends ComponentBase
class_name ActorComponent


## Emitted when this actor executes a command
## Parameters:
## - command (String): The executed command string
## - result (Dictionary): Command result with success, message, etc.
## - reason (String): Optional reasoning/commentary provided with command
signal command_executed(command: String, result: Dictionary, reason: String)

## Emitted when this actor observes an event in their location
signal event_observed(event: Dictionary)


## The last command this actor executed (full command line with args)
var last_command: String = ""

## The result Dictionary from the last command execution
var last_result: Dictionary = {}

## The reason/commentary provided with the last command (if any)
var last_reason: String = ""

## Cached reference to the actor's current WorldObject location
## Updated via _update_location() before each command execution
var current_location: WorldObject = null

## Current reasoning for the command being executed (available to command functions)
var _current_reason: String = ""

## Flag to prevent infinite recursion in auto-correction
var _in_autocorrect: bool = false

func _on_added(obj: WorldObject) -> void:
	"""Called when this component is added to a WorldObject.

	Sets the is_actor flag and caches the initial location.

	Args:
		obj: The WorldObject this component was added to
	"""
	super._on_added(obj)
	obj.set_flag("is_actor", true)
	_update_location()


func _on_removed(obj: WorldObject) -> void:
	"""Called when this component is removed from a WorldObject.

	Clears the is_actor flag.

	Args:
		obj: The WorldObject this component was removed from
	"""
	super._on_removed(obj)
	obj.set_flag("is_actor", false)


func _update_location() -> void:
	"""Update cached location reference.

	Refreshes current_location from the owner's actual location.
	Called before each command execution to ensure consistency.
	"""
	current_location = owner.get_location()


func _levenshtein_distance(s1: String, s2: String) -> int:
	"""Calculate Levenshtein distance (edit distance) between two strings.

	Args:
		s1: First string
		s2: Second string

	Returns:
		Minimum number of single-character edits (insertions, deletions, substitutions)

	Notes:
		Used for fuzzy command matching to catch typos from LLMs.
	"""
	var len1 = s1.length()
	var len2 = s2.length()

	# Create distance matrix
	var matrix = []
	for i in range(len1 + 1):
		var row = []
		row.resize(len2 + 1)
		matrix.append(row)

	# Initialize first row and column
	for i in range(len1 + 1):
		matrix[i][0] = i
	for j in range(len2 + 1):
		matrix[0][j] = j

	# Calculate distances
	for i in range(1, len1 + 1):
		for j in range(1, len2 + 1):
			var cost = 0 if s1[i - 1] == s2[j - 1] else 1
			matrix[i][j] = min(
				matrix[i - 1][j] + 1,      # deletion
				min(
					matrix[i][j - 1] + 1,  # insertion
					matrix[i - 1][j - 1] + cost  # substitution
				)
			)

	return matrix[len1][len2]


func _get_all_valid_commands() -> Array[String]:
	"""Get list of all valid commands.

	Returns:
		Array of all command strings that execute_command recognizes

	Notes:
		Keep in sync with execute_command match statement.
		Used by both prefix matching and fuzzy matching.
	"""
	return [
		"look", "l",
		"go",
		"say", "\"",
		"emote", ":",
		"examine", "x",
		"take", "get",
		"drop",
		"inventory", "inv", "i",
		"help",
		"commands",
		"who",
		"where",
		"whisper",
		"note",
		"recall",
		"dream",
		"rooms",
		"@dig",
		"@exit",
		"@teleport", "@tel",
		"@my-profile",
		"@my-description",
		"@set-profile",
		"@set-description",
		"@reload-text",
		"@show-text",
		"@show-config",
		"@memory-status",
		"@llm-status",
		"@llm-config",
		"@narrative",
		"@narrative-here",
		"@narrative-clear"
	]


func _find_prefix_match(prefix: String) -> String:
	"""Find a command that matches the given prefix (MOO-style).

	Args:
		prefix: The partial command string to match

	Returns:
		The full command if exactly one match, empty string if none or ambiguous

	Notes:
		MOO-style prefix matching: "exa" → "examine", "inv" → "inventory"
		Requires unambiguous match (only one command starts with prefix).
		Exact matches are preferred (so "l" → "look" not "look" or "l").
	"""
	var valid_commands = _get_all_valid_commands()
	var prefix_lower = prefix.to_lower()

	# Check for exact match first
	for cmd in valid_commands:
		if cmd.to_lower() == prefix_lower:
			return cmd

	# Check for prefix matches
	var matches: Array[String] = []
	for cmd in valid_commands:
		if cmd.to_lower().begins_with(prefix_lower):
			matches.append(cmd)

	# Return match only if unambiguous
	if matches.size() == 1:
		return matches[0]

	return ""  # No match or ambiguous


func _find_closest_command(typo: String) -> String:
	"""Find the closest valid command to a typo using fuzzy matching.

	Args:
		typo: The mistyped command

	Returns:
		The closest valid command, or empty string if no close match

	Notes:
		Uses Levenshtein distance with a threshold of 2 edits.
		Helps LLMs by auto-correcting common typos like "eexamine" → "examine".
	"""
	var valid_commands = _get_all_valid_commands()

	var best_match: String = ""
	var best_distance: int = 999
	var threshold: int = 2  # Allow up to 2 character edits

	for cmd in valid_commands:
		var distance = _levenshtein_distance(typo.to_lower(), cmd.to_lower())
		if distance < best_distance and distance <= threshold:
			best_distance = distance
			best_match = cmd

	return best_match


func execute_command(command: String, args: Array = [], reason: String = "", task_id: String = "") -> Dictionary:
	"""Execute a command as this actor and return the result.

	Matches the command string against known commands and dispatches
	to the appropriate handler function. Updates location cache before
	execution and emits command_executed signal after completion.

	Args:
		command: The command verb to execute (case-insensitive)
		args: Array of string arguments for the command
		reason: Optional reasoning/commentary for this command (appears in echoes)
		task_id: Optional task ID for training data collection

	Returns:
		Dictionary containing at least:
		- success (bool): Whether the command succeeded
		- message (String): Result message to display
		Additional keys may be present depending on command
	"""
	_update_location()

	# Store reasoning for command functions to access
	_current_reason = reason

	var result: Dictionary = {}

	# Match command string to handler functions
	match command.to_lower():
		"look", "l":
			result = _cmd_look(args)
		"go":
			result = _cmd_go(args)
		"say":
			result = _cmd_say(args)
		"emote":
			result = _cmd_emote(args)
		"examine", "ex":
			result = _cmd_examine(args)
		"think":
			result = _cmd_think(args)
		"dream":
			result = _cmd_dream(args)
		"note":
			result = _cmd_note(args)
		"@overwrite-note":
			result = _cmd_overwrite_note(args)
		"recall":
			result = _cmd_recall(args)
		"who":
			result = _cmd_who(args)
		"where":
			result = _cmd_where(args)
		"rooms":
			result = _cmd_rooms(args)
		"@dig":
			result = _cmd_dig(args)
		"@exit":
			result = _cmd_exit(args)
		"@teleport", "@tp":
			result = _cmd_teleport(args)
		"@save":
			result = _cmd_save(args)
		"@quit":
			result = _cmd_quit(args)
		"@impersonate", "@imp":
			result = _cmd_impersonate(args)
		"@edit-profile":
			result = _cmd_edit_profile(args)
		"@edit-interval":
			result = _cmd_edit_interval(args)
		"@show-profile":
			result = _cmd_show_profile(args)
		"@my-profile":
			result = _cmd_my_profile(args)
		"@my-description":
			result = _cmd_my_description(args)
		"@set-profile":
			result = _cmd_set_profile(args)
		"@set-description":
			result = _cmd_set_description(args)
		"help", "?":
			result = _cmd_help(args)
		"commands":
			result = _cmd_commands(args)
		"@reload-text":
			result = _cmd_reload_text(args)
		"@show-text":
			result = _cmd_show_text(args)
		"@show-config":
			result = _cmd_show_config(args)
		"@memory-status":
			result = _cmd_memory_status(args)
		"@compact-memories":
			result = _cmd_compact_memories(args)
		"@bootstrap-summaries":
			result = _cmd_bootstrap_summaries(args)
		"@llm-status":
			result = _cmd_llm_status(args)
		"@llm-config":
			result = _cmd_llm_config(args)
		"@narrative":
			result = _cmd_narrative(args)
		"@narrative-here":
			result = _cmd_narrative_here(args)
		"@narrative-clear":
			result = _cmd_narrative_clear(args)
		"@training-status":
			result = _cmd_training_status(args)
		"@training-export":
			result = _cmd_training_export(args)
		"@training-clear":
			result = _cmd_training_clear(args)
		"@training-toggle":
			result = _cmd_training_toggle(args)
		_:
			# Try prefix matching first (MOO-style), then fuzzy matching for typos
			# Only auto-correct if we're not already in an auto-correction (prevent infinite recursion)
			if not _in_autocorrect:
				var suggestion = _find_prefix_match(command)
				if suggestion == "":
					suggestion = _find_closest_command(command)

				if suggestion != "":
					# Auto-correct and retry (with recursion guard)
					print("[Actor] Auto-corrected: '%s' → '%s'" % [command, suggestion])
					_in_autocorrect = true
					result = execute_command(suggestion, args, reason, task_id)
					_in_autocorrect = false
					# Add note about auto-correction to message (only for player feedback)
					if result.has("message") and owner.has_flag("is_player"):
						result.message = "[Auto-corrected '%s' → '%s']\n%s" % [command, suggestion, result.message]
				else:
					result = {"success": false, "message": "Unknown command: %s\nTry 'help' for available commands." % command}
			else:
				# Already in auto-correction, don't recurse
				result = {"success": false, "message": "Unknown command: %s\nTry 'help' for available commands." % command}

	# Reconstruct full command line from verb and args for caching
	var full_command: String = command
	if args.size() > 0:
		full_command += " " + " ".join(args)

	# Cache command, result, and reason for inspection
	last_command = full_command
	last_result = result
	last_reason = reason

	# Concise activity log showing actor and action
	var status_icon: String = "✓" if result.success else "✗"
	var args_str: String = " ".join(args) if args.size() > 0 else ""
	var log_line: String = "[%s] %s %s" % [owner.name, command, args_str]
	if reason != "":
		log_line += " | %s" % reason  # Show full reasoning
	print("%s %s" % [status_icon, log_line])

	command_executed.emit(command, result, reason)

	# Record training data if task_id provided and TrainingDataCollector available
	if task_id != "" and TrainingDataCollector:
		TrainingDataCollector.record_command_result(owner, full_command, result, task_id)

	return result


func _cmd_look(_args: Array) -> Dictionary:
	"""LOOK command - Observe the current location.

	Displays the location's description and contents. Broadcasts
	a look action to other actors in the same location.

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): Always true unless actor has no location
		- message (String): Formatted description of location and contents (compact, single-line format)
		- location (WorldObject): The location object being observed
	"""
	if current_location == null:
		return {"success": false, "message": TextManager.get_text("commands.social.look.no_location")}

	# Start with room name
	var desc: String = current_location.name + ": "

	# Add room description (includes exits from enhance_description)
	desc += current_location.get_description()

	# Add contents listing inline from location component
	var location_comp = current_location.get_component("location")
	if location_comp != null:
		var contents_desc = location_comp.get_contents_description()
		if not contents_desc.is_empty():
			desc += contents_desc

	# Notify other actors in location
	var behavior := TextManager.get_text("behaviors.actions.look", {"actor": owner.name})
	EventWeaver.broadcast_to_location(current_location, {
		"type": "action",
		"actor": owner,
		"action": "looks around",
		"message": behavior,
		"reason": _current_reason
	})

	return {
		"success": true,
		"message": desc,
		"location": current_location
	}


func _cmd_go(args: Array) -> Dictionary:
	"""GO command - Move to another location through an exit.

	Attempts to find and traverse an exit in the current location.
	If no direct exit exists, uses pathfinding to find a route to
	a room with the given name and takes the first step automatically.
	Broadcasts departure and arrival events. Automatically performs
	a look command at the destination.

	Args:
		args: Array containing the exit name or destination room name
			  Accepts "go <exit>" or "go to <exit>" (the word "to" is optional)

	Returns:
		Dictionary with:
		- success (bool): True if movement succeeded
		- message (String): Result of automatic look at destination, or error
		- location (WorldObject): The destination location (on success)

	Notes:
		Supports natural language variations:
		- "go lobby" - Direct exit or pathfinding to room named "lobby"
		- "go to lobby" - Natural (word "to" is stripped)
		- "go The Lobby" - Multi-word exit/room names work with both forms

	Pathfinding:
		If no direct exit matches, searches for a room with that name and
		automatically takes the first step of the shortest path. Shows a
		hint about the remaining path (like the SAY "but no one heard" hint).
	"""
	if args.size() == 0:
		return {"success": false, "message": TextManager.get_text("commands.movement.go.missing_arg")}

	if current_location == null:
		return {"success": false, "message": TextManager.get_text("commands.movement.go.no_location")}

	# Handle "go to <exit>" by stripping optional "to"
	var exit_args: Array = args.duplicate()
	if exit_args.size() > 0 and exit_args[0].to_lower() == "to":
		exit_args.remove_at(0)

	if exit_args.size() == 0:
		return {"success": false, "message": TextManager.get_text("commands.movement.go.missing_arg")}

	# Join all args to support multi-word exit names like "The Lobby"
	var exit_name: String = " ".join(exit_args)

	# Verify location has location component with exits
	var location_comp = current_location.get_component("location")
	if location_comp == null:
		return {"success": false, "message": TextManager.get_text("commands.movement.go.no_exits")}

	var destination: WorldObject = location_comp.get_exit(exit_name)

	# If no direct exit, try pathfinding to a room with that name
	var pathfinding_hint: String = ""
	if destination == null:
		var path: Array[String] = WorldKeeper.find_path(current_location, exit_name)
		if path.size() > 0:
			# Found a path! Take the first step
			var first_exit: String = path[0]
			destination = location_comp.get_exit(first_exit)

			# Build hint about the full path
			if path.size() == 1:
				pathfinding_hint = TextManager.get_text("commands.movement.go.pathfinding_arrived", {
					"destination": exit_name
				})
			else:
				# Show remaining path
				var remaining_path: Array[String] = []
				for i in range(1, path.size()):
					remaining_path.append(path[i])
				pathfinding_hint = TextManager.get_text("commands.movement.go.pathfinding_progress", {
					"destination": exit_name,
					"remaining": ", ".join(remaining_path)
				})
		else:
			# No path found - return error
			return {"success": false, "message": TextManager.get_text("commands.movement.go.no_exit", {"exit": exit_name})}

	# Broadcast departure event to old location
	var departure_msg := TextManager.get_text("commands.movement.go.departure", {"actor": owner.name, "destination": destination.name})
	EventWeaver.broadcast_to_location(current_location, {
		"type": "movement",
		"actor": owner,
		"action": "leaves",
		"destination": destination,
		"message": departure_msg,
		"reason": _current_reason
	})

	# Store old location name before moving (current_location will change after move_to)
	var prior_location_name: String = current_location.name

	# Perform the actual move
	owner.move_to(destination)
	_update_location()

	# Broadcast arrival event to new location
	var arrival_msg := TextManager.get_text("commands.movement.go.arrival", {"actor": owner.name, "origin": prior_location_name})
	EventWeaver.broadcast_to_location(current_location, {
		"type": "movement",
		"actor": owner,
		"action": "arrives",
		"destination": destination,
		"message": arrival_msg,
		"reason": _current_reason
	})

	# Build result message with transition + room description
	var transition_msg: String = TextManager.get_text("commands.movement.go.transition", {
		"origin": prior_location_name,
		"destination": destination.name
	})

	# Get the look result for the new location
	var look_result: Dictionary = _cmd_look([])

	# Combine transition message with room description
	var full_message: String = transition_msg + "\n\n" + look_result.message

	# Add pathfinding hint if we're on a multi-step journey
	if not pathfinding_hint.is_empty():
		full_message += "\n\n" + pathfinding_hint

	return {
		"success": true,
		"message": full_message,
		"location": destination
	}


func _cmd_say(args: Array) -> Dictionary:
	"""SAY command - Speak aloud to others in the location.

	Broadcasts speech event to all actors in the current location.

	Args:
		args: Array of words to say (joined with spaces)

	Returns:
		Dictionary with:
		- success (bool): True if message was spoken
		- message (String): Confirmation of what was said
	"""
	if args.size() == 0:
		return {"success": false, "message": TextManager.get_text("commands.social.say.missing_arg")}

	var message: String = " ".join(args)

	# Broadcast speech event to location
	var behavior := TextManager.get_text("commands.social.say.behavior", {"actor": owner.name, "text": message})
	EventWeaver.broadcast_to_location(current_location, {
		"type": "speech",
		"actor": owner,
		"message": message,
		"text": behavior,
		"reason": _current_reason
	})

	# Check if anyone else is in the room to hear it
	var success_msg := TextManager.get_text("commands.social.say.success", {"text": message})
	if current_location:
		var has_audience := false
		for obj in current_location.get_contents():
			if obj != owner and obj.has_component("actor"):
				has_audience = true
				break
		if not has_audience:
			success_msg += TextManager.get_text("commands.social.say.empty_room")

	return {
		"success": true,
		"message": success_msg
	}


func _cmd_emote(args: Array) -> Dictionary:
	"""EMOTE command - Perform a freeform action.

	Broadcasts an emote/action event to all actors in the location.
	Used for roleplay actions like "waves" or "sits down".

	Args:
		args: Array of words describing the action (joined with spaces)

	Returns:
		Dictionary with:
		- success (bool): True if emote was performed
		- message (String): The formatted emote text
	"""
	if args.size() == 0:
		return {"success": false, "message": TextManager.get_text("commands.social.emote.missing_arg")}

	var action: String = " ".join(args)

	# Broadcast emote event to location
	var behavior := TextManager.get_text("commands.social.emote.behavior", {"actor": owner.name, "text": action})
	EventWeaver.broadcast_to_location(current_location, {
		"type": "emote",
		"actor": owner,
		"action": action,
		"text": behavior,
		"reason": _current_reason
	})

	# Check if anyone else is in the room to see it
	if current_location:
		var has_audience := false
		for obj in current_location.get_contents():
			if obj != owner and obj.has_component("actor"):
				has_audience = true
				break
		if not has_audience:
			behavior += TextManager.get_text("commands.social.emote.empty_room")

	return {
		"success": true,
		"message": behavior
	}


func _cmd_examine(args: Array) -> Dictionary:
	"""EXAMINE command - Look closely at an object or actor.

	Searches for the named target in the current location and displays
	its detailed description. Broadcasts an examine action to observers.

	Args:
		args: Array with target name (may be multi-word like "The Traveler")

	Returns:
		Dictionary with:
		- success (bool): True if target was found and examined
		- message (String): The target's description
		- target (WorldObject): The examined object (on success)
	"""
	if args.size() == 0:
		return {"success": false, "message": TextManager.get_text("commands.social.examine.missing_arg")}

	# Join all args to support multi-word object names like "The Traveler"
	var target_name: String = " ".join(args)

	# Search for target in current location only (no global fallback)
	var target: WorldObject = WorldKeeper.find_object_by_name(target_name, current_location, false)

	if target == null:
		return {"success": false, "message": TextManager.get_text("commands.social.examine.not_found", {"target": target_name})}

	# Broadcast examine action to observers
	var behavior := TextManager.get_text("commands.social.examine.behavior", {"actor": owner.name, "target": target.name})
	EventWeaver.broadcast_to_location(current_location, {
		"type": "action",
		"actor": owner,
		"target": target,
		"action": "examines",
		"message": behavior
	})

	return {
		"success": true,
		"message": target.get_description(),
		"target": target
	}


func _cmd_think(args: Array) -> Dictionary:
	"""THINK command - Record internal reasoning/thoughts.

	Allows actors (both players and AI agents) to record their internal
	reasoning, plans, and observations as standalone thoughts. Thoughts
	are stored in memory but not broadcast to other actors.

	Args:
		args: Array of words describing the thought (joined with spaces)

	Returns:
		Dictionary with:
		- success (bool): True if thought was recorded
		- message (String): Confirmation of thought recorded

	Notes:
		Thoughts are private - they go to memory but not to other actors.
		However, observers will see the actor pause in contemplation.
		This is useful for recording plans, observations, or reasoning that
		isn't directly tied to a specific action.
		AI agents can also include REASON: lines with their commands to
		record action-specific reasoning.
	"""
	if args.size() == 0:
		return {"success": false, "message": TextManager.get_text("commands.memory.think.missing_arg")}

	var thought: String = " ".join(args)

	# Record to memory if available
	if owner.has_component("memory"):
		var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent
		memory_comp.add_memory(thought)

	# Broadcast observable behavior (but not the thought content)
	if current_location:
		var behavior := TextManager.get_text("behaviors.actions.think", {"actor": owner.name})
		EventWeaver.broadcast_to_location(current_location, {
			"type": "action",
			"actor": owner,
			"action": "pauses in thought",
			"message": behavior
		})

	return {
		"success": true,
		"message": TextManager.get_text("commands.memory.think.success", {"thought": thought})
	}


func _cmd_dream(_args: Array) -> Dictionary:
	"""DREAM command - Deep memory synthesis through dream-like reflection.

	Uses Python prototype's sophisticated dream scaffolding:
	- Large memory pool (128+ memories by default, configurable)
	- Filters previous dreams to prevent feedback loops
	- Oversamples older memories for depth (2x recent count from archive)
	- Creates chunked non-linear narrative (2-4 memories per chunk, shuffled)
	- Rich prompt encouraging counterfactuals, dream themes, creative insight
	- Stores result as both a note (overwrites "Dream" entry) and memory

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): True if dream analysis started
		- message (String): Acknowledgment that dream has begun

	Notes:
		Requires memory component and Shoggoth LLM interface.
		This is asynchronous - the command returns immediately and
		the dream insight appears as a follow-up message.
		Configuration via vault/config/ai_defaults.md (dream_memory_count, etc.)
	"""
	if not owner.has_component("memory"):
		return {"success": false, "message": TextManager.get_text("commands.memory.dream.no_memory")}

	if not Shoggoth or not Shoggoth.ollama_client:
		return {"success": false, "message": TextManager.get_text("commands.memory.dream.no_llm")}

	var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent

	# Get configuration from vault (with fallbacks matching Python prototype defaults)
	var dream_count: int = TextManager.get_config("dream_memory_count", 128)
	var expansion_multiplier: float = TextManager.get_config("dream_expansion_multiplier", 2.0)
	var chunk_min: int = TextManager.get_config("dream_chunk_min", 2)
	var chunk_max: int = TextManager.get_config("dream_chunk_max", 4)

	# Get all available memories for filtering and sampling
	var all_memories: Array[Dictionary] = memory_comp.get_all_memories()

	if all_memories.size() == 0:
		return {"success": false, "message": TextManager.get_text("commands.memory.dream.no_memories")}

	# Filter out previous dream memories to prevent feedback loops (Python prototype pattern)
	var filtered_memories: Array[Dictionary] = []
	for memory in all_memories:
		var mem_dict: Dictionary = memory as Dictionary
		var content_lower: String = mem_dict.content.to_lower()
		# Skip if this is a dream memory or dream insight
		if "dream insight:" in content_lower or "you've had a dream:" in content_lower:
			continue
		filtered_memories.append(memory)

	if filtered_memories.size() == 0:
		return {"success": false, "message": "All your memories are dreams. Try creating new experiences first."}

	# Calculate memory distribution (Python prototype pattern)
	var target_count: int = min(dream_count, filtered_memories.size())
	var recent_count: int = target_count / 2  # Half recent
	var older_sample_count: int = int(recent_count * expansion_multiplier)  # 2x recent from archive

	# Get recent memories (up to half the target)
	var recent_memories: Array[Dictionary] = memory_comp.get_recent_memories(recent_count)

	# Get older memories by excluding the recent set
	var older_memories: Array[Dictionary] = []
	for memory in filtered_memories:
		var is_recent: bool = false
		for recent in recent_memories:
			if memory.get("content", "") == recent.get("content", ""):
				is_recent = true
				break
		if not is_recent:
			older_memories.append(memory)

	# Randomly sample from older memories (Python prototype oversampling pattern)
	var sampled_old: Array[Dictionary] = []
	if older_memories.size() > 0:
		var sample_size: int = min(older_sample_count, older_memories.size())
		var indices: Array[int] = []
		for i in range(older_memories.size()):
			indices.append(i)
		indices.shuffle()
		for i in range(sample_size):
			sampled_old.append(older_memories[indices[i]])

	# Combine all memories
	var combined_memories: Array[Dictionary] = []
	combined_memories.append_array(recent_memories)
	combined_memories.append_array(sampled_old)

	if combined_memories.size() == 0:
		return {"success": false, "message": TextManager.get_text("commands.memory.dream.no_memories")}

	# Create chunked non-linear narrative (Python prototype pattern)
	# This maintains some local chronology but creates a dream-like overall structure
	var memory_chunks: Array[Array] = []
	var i: int = 0
	while i < combined_memories.size():
		var chunk_size: int = randi_range(chunk_min, chunk_max)
		var chunk: Array[Dictionary] = []
		for j in range(chunk_size):
			if i + j < combined_memories.size():
				chunk.append(combined_memories[i + j])
		if chunk.size() > 0:
			memory_chunks.append(chunk)
		i += chunk_size

	# Shuffle chunks for dream-like non-linearity
	memory_chunks.shuffle()

	# Flatten back to single array in new order
	var dream_memories: Array[Dictionary] = []
	for chunk in memory_chunks:
		for memory in chunk:
			dream_memories.append(memory)

	# Build memories text for prompt (Python prototype format)
	var memories_text: String = ""
	for memory in dream_memories:
		var mem_dict: Dictionary = memory as Dictionary
		memories_text += "%s\n\n" % mem_dict.content

	# Build rich dream prompt (Python prototype pattern with counterfactuals and dream themes)
	var prompt: String = "%s\n\n" % memories_text
	prompt += "You are telling the story of %s's memories.\n\n" % owner.name
	prompt += "Your goal is to create a dream-like second-person real-time stream of consciousness of the entirety of %s's experiences and behaviors, both good and bad, exciting and mundane, to help them think through who they are and what they should be doing differently. " % owner.name
	prompt += "Be creative, insightful, and focus on helping the character understand things not already mentioned in their experiences, by posing counterfactuals and letting the consequences play out. "
	prompt += "What are they NOT doing, what are they NOT seeing, what should they wonder about, what could go wrong, what could go right? "
	prompt += "Go crazy, freely adding, removing, or changing any details you want (and adding common dream themes like flying, falling, etc., even when they don't make sense) to make your points more visceral and illustrative. "
	prompt += "Your response should be written as a first-person dream narrative that feels authentic to the character. "
	prompt += "Please go on a thorough journey through everything that has happened above, including anything and everything that seems like an important detail."

	# Character-aware system prompt (Python prototype pattern)
	var system_prompt: String = "You are telling the story of a character's memories. "
	system_prompt += "Your goal is to create a dream-like reflection of the entirety of their experiences and behaviors (both good and bad). "
	system_prompt += "Be creative, insightful, and focus on helping the character understand things not already present in their experiences, and posing counterfactuals and letting the consequences play out is encouraged. "
	system_prompt += "Go crazy, freely adding, removing, or changing any details you want to make your points more visceral and illustrative. "
	system_prompt += "Your response should be written as a first-person dream narrative that feels authentic to the character. "
	system_prompt += "Please go on a thorough journey through everything that has happened, as a dream. Do not repeat any previous dreams."

	# Broadcast observable behavior (entering dream state)
	if current_location:
		var behavior := TextManager.get_text("behaviors.actions.dream", {"actor": owner.name})
		EventWeaver.broadcast_to_location(current_location, {
			"type": "action",
			"actor": owner,
			"action": "becomes still, eyes unfocused",
			"message": behavior
		})

	# Request LLM analysis asynchronously
	print("Dream: %s entering dream state with %d memories..." % [owner.name, dream_memories.size()])
	Shoggoth.generate_async(prompt, system_prompt,
		func(result: Variant):
			# Handle Dictionary format from Shoggoth
			var content: String = result.content if result is Dictionary else result
			_on_dream_complete(content)
	)

	return {
		"success": true,
		"message": TextManager.get_text("commands.memory.dream.starting")
	}


func _on_dream_complete(insight: String) -> void:
	"""Handle dream analysis result from LLM.

	Called when the LLM finishes analyzing memories in dream state.
	Implements Python prototype's dual storage pattern:
	1. Stores as a note titled "Dream" (overwrites previous dream)
	2. Also stores as a memory prefixed with "You've had a dream:"

	This allows agents to:
	- Access latest dream via note lookup (consistent title)
	- Have dream in memory timeline for context building
	- Not have dreams accumulate infinitely as separate notes

	Args:
		insight: The LLM's dream narrative from memory analysis

	Notes:
		This is a callback from the async LLM request.
		Matches Python prototype's create_note + add_response_memory pattern.
	"""
	if not owner or not owner.has_component("memory"):
		return

	var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent

	# Dual storage pattern from Python prototype:
	# 1. Store as note (overwrites "Dream" - acts like dream journal with latest entry)
	memory_comp.add_note("Dream", insight)

	# 2. Store as memory (allows dream to appear in timeline and be referenced)
	memory_comp.add_memory("You've had a dream: %s" % insight)

	# If this is an AI agent, the insight will appear in their next memory review
	# If this is the player, emit a command result
	print("Dream: %s received insight (%d chars)" % [owner.name, insight.length()])

	# Emit as a command result for player visibility
	var result: Dictionary = {
		"success": true,
		"message": "Dream:\n%s" % insight
	}
	command_executed.emit("dream", result, "")


func _cmd_note(args: Array) -> Dictionary:
	"""NOTE command - Create/update a persistent note.

	Syntax: note <title> -> <content>

	Args:
		args: Array with title and content separated by ->

	Returns:
		Dictionary with success status and message
	"""
	if args.size() == 0:
		return {"success": false, "message": TextManager.get_text("commands.memory.note.missing_arg")}

	var full_args: String = " ".join(args)
	if not "->" in full_args:
		return {"success": false, "message": TextManager.get_text("commands.memory.note.no_arrow")}

	var parts: PackedStringArray = full_args.split("->", true, 1)
	var title: String = parts[0].strip_edges()
	var content: String = parts[1].strip_edges() if parts.size() > 1 else ""

	if not owner.has_component("memory"):
		return {"success": false, "message": TextManager.get_text("commands.memory.note.no_memory_component")}

	var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent

	# Broadcast observable behavior (writing)
	if current_location:
		var behavior := TextManager.get_text("behaviors.actions.note", {"actor": owner.name})
		EventWeaver.broadcast_to_location(current_location, {
			"type": "action",
			"actor": owner,
			"action": "jots something down",
			"message": behavior
		})

	# Add note asynchronously
	memory_comp.add_note_async(title, content, last_reason, func():
		print("[Actor] %s completed note: %s" % [owner.name, title])
	)

	return {
		"success": true,
		"message": TextManager.get_text("commands.memory.note.success", {"title": title})
	}


func _cmd_overwrite_note(args: Array) -> Dictionary:
	"""@OVERWRITE-NOTE command - Create/overwrite a persistent note (replaces existing).

	Unlike NOTE which appends to existing notes, this command completely
	replaces any existing note with the same title.

	Syntax: @overwrite-note <title> -> <content>

	Args:
		args: Array with title and content separated by ->

	Returns:
		Dictionary with success status and message
	"""
	if args.size() == 0:
		return {"success": false, "message": TextManager.get_text("commands.memory.overwrite_note.missing_arg")}

	var full_args: String = " ".join(args)
	if not "->" in full_args:
		return {"success": false, "message": TextManager.get_text("commands.memory.overwrite_note.no_arrow")}

	var parts: PackedStringArray = full_args.split("->", true, 1)
	var title: String = parts[0].strip_edges()
	var content: String = parts[1].strip_edges() if parts.size() > 1 else ""

	if not owner.has_component("memory"):
		return {"success": false, "message": TextManager.get_text("commands.memory.overwrite_note.no_memory_component")}

	var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent

	# Broadcast observable behavior (writing)
	if current_location:
		var behavior := TextManager.get_text("behaviors.actions.note", {"actor": owner.name})
		EventWeaver.broadcast_to_location(current_location, {
			"type": "action",
			"actor": owner,
			"action": "jots something down",
			"message": behavior
		})

	# Add note asynchronously with append_mode=false to overwrite
	memory_comp.add_note_async(title, content, last_reason, func():
		print("[Actor] %s completed note overwrite: %s" % [owner.name, title])
	, false)

	return {
		"success": true,
		"message": TextManager.get_text("commands.memory.overwrite_note.success", {"title": title})
	}


func _cmd_recall(args: Array) -> Dictionary:
	"""RECALL command - Search notes instantly with keyword matching.

	Returns immediate results including:
	- Most recently edited note (for convenience)
	- All note titles (for reference)
	- Keyword search results (if query provided)

	This command is now instant - no async processing required.
	AI agents can use this without losing turns waiting for results.

	Args:
		args: Array of words forming search query (optional)

	Returns:
		Dictionary with success status and immediate results
	"""
	if not owner.has_component("memory"):
		return {"success": false, "message": TextManager.get_text("commands.memory.recall.no_memory_component")}

	var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent
	var query: String = " ".join(args) if args.size() > 0 else ""

	# Broadcast observable behavior (brief pause to think)
	if current_location:
		var behavior := TextManager.get_text("behaviors.actions.recall", {"actor": owner.name})
		EventWeaver.broadcast_to_location(current_location, {
			"type": "action",
			"actor": owner,
			"action": "pauses to recall",
			"message": behavior
		})

	# Get instant results (no async required)
	var result_text: String = memory_comp.recall_notes_instant(query)

	return {
		"success": true,
		"message": result_text
	}


func observe_event(event: Dictionary) -> void:
	"""Observe an event happening in this actor's location.

	Called by EventWeaver when an event is broadcast to this actor's
	location. Filters out the actor's own actions to avoid redundancy.

	Args:
		event: Dictionary containing event details (type, actor, message, etc.)

	Notes:
		Does not observe own actions since those are already handled
		through command execution results
	"""
	# Don't observe our own actions (already got the command result)
	if event.get("actor") == owner:
		return

	# Emit event to observers (UI, Memory, AI agents, etc.)
	event_observed.emit(event)


func _cmd_who(_args: Array) -> Dictionary:
	"""WHO command - List all actors currently in the world.

	Scans all WorldObjects to find those with actor components and
	displays them with their locations and AI status.

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): Always true
		- message (String): Formatted list of actors and their locations
	"""
	var actors: Array[WorldObject] = []

	# Scan all WorldObjects to find actors
	for obj_id in WorldKeeper.objects.keys():
		var obj: WorldObject = WorldKeeper.objects[obj_id]
		if obj.has_component("actor"):
			actors.append(obj)

	if actors.size() == 0:
		return {"success": true, "message": "No one is here."}

	# Format actor list with locations and AI indicators
	var text: String = "Who's Online\n\n"
	for actor in actors:
		var location: WorldObject = actor.get_location()
		var loc_name: String = location.name if location else "The Void"
		var is_ai: String = " [AI]" if actor.has_component("thinker") else ""
		text += "• %s%s - in %s\n" % [actor.name, is_ai, loc_name]

	return {"success": true, "message": text}


func _cmd_where(_args: Array) -> Dictionary:
	"""WHERE command - Show the actor's current location.

	Displays the name and ID of the current location.

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): Always true
		- message (String): Current location name and ID
	"""
	if current_location == null:
		return {"success": true, "message": "You are nowhere."}

	return {"success": true, "message": "You are in %s (%s)" % [current_location.name, current_location.id]}


func _cmd_rooms(_args: Array) -> Dictionary:
	"""ROOMS command - List all rooms in the world.

	Displays all rooms with their IDs and current occupants.

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): Always true
		- message (String): Formatted list of rooms with occupants
	"""
	var rooms: Array[WorldObject] = WorldKeeper.get_all_rooms()

	if rooms.size() == 0:
		return {"success": true, "message": "No rooms exist."}

	# Build formatted room list with occupants
	var text: String = "Rooms in the World\n\n"
	for room in rooms:
		var occupants: Array[String] = []
		for obj in room.get_contents():
			if obj.has_component("actor"):
				occupants.append(obj.name)

		var occupant_text: String = " (%s)" % ", ".join(occupants) if occupants.size() > 0 else " (empty)"
		text += "• %s [%s]%s\n" % [room.name, room.id, occupant_text]

	return {"success": true, "message": text}


func _cmd_dig(args: Array) -> Dictionary:
	"""@DIG command - Create a new room and auto-connect it (builder command).

	Creates a new WorldObject with a LocationComponent and automatically
	creates a bidirectional exit from the current location to the new room.
	The exit is named after the new room.

	Args:
		args: Array of words for the room name (joined with spaces)

	Returns:
		Dictionary with:
		- success (bool): True if room was created
		- message (String): Confirmation with room name, ID, and exit info

	Notes:
		This is a builder/admin command for world construction.
		Automatically creates an exit named after the new room.
	"""
	if args.size() == 0:
		return {"success": false, "message": "Usage: @dig <room name>"}

	if current_location == null:
		return {"success": false, "message": "You must be in a location to dig a new room."}

	var current_loc_comp: LocationComponent = current_location.get_component("location")
	if current_loc_comp == null:
		return {"success": false, "message": "Your current location cannot have exits."}

	var room_name: String = " ".join(args)

	# Create new room WorldObject with LocationComponent
	var new_room: WorldObject = WorldKeeper.create_room(room_name, "A newly created room.")
	var loc_comp: LocationComponent = LocationComponent.new()
	new_room.add_component("location", loc_comp)

	# Automatically create exit from current location to new room
	# Exit name is the new room's name (lowercase)
	var exit_name: String = room_name.to_lower()
	current_loc_comp.add_exit(exit_name, new_room)

	# Broadcast creation event to current location
	EventWeaver.broadcast_to_location(current_location, {
		"type": "building",
		"actor": owner,
		"action": "creates a room",
		"target": new_room,
		"message": "%s digs a new room: %s" % [owner.name, new_room.name]
	})

	return {
		"success": true,
		"message": "Created room: %s [%s]\nAuto-created exit '%s' from %s.\nBidirectional connection established - you can now go '%s' and return via '%s'." % [
			new_room.name,
			new_room.id,
			exit_name,
			current_location.name,
			exit_name,
			current_location.name.to_lower()
		]
	}


func _cmd_exit(args: Array) -> Dictionary:
	"""@EXIT command - Create an exit between rooms (builder command).

	Creates an exit from the current location to a target room. The connection
	automatically works bidirectionally - if room A has an exit to room B, then
	room B will automatically show an exit back to room A (named after room A).

	The destination can be specified by name or #ID.

	Args:
		args: Array containing: <exit_name> to <destination>
			  Example: ["north", "to", "Garden"] or ["south", "to", "#3"]

	Returns:
		Dictionary with:
		- success (bool): True if exit was created
		- message (String): Confirmation with exit and destination details

	Notes:
		This is a builder/admin command. Exits automatically work bidirectionally.
		Only need to create exits once - the reverse connection is automatic.
	"""
	if args.size() < 3:
		return {"success": false, "message": "Usage: @exit <exit name> to <destination room name or #ID>"}

	# Find "to" keyword in arguments
	var to_index: int = -1
	for i in range(args.size()):
		if args[i].to_lower() == "to":
			to_index = i
			break

	if to_index == -1:
		return {"success": false, "message": "Usage: @exit <exit name> to <destination>"}

	# Extract exit name from arguments before "to" (support multi-word like "The Lobby")
	var exit_parts: Array[String] = []
	for i in range(to_index):
		exit_parts.append(args[i])
	var exit_name: String = " ".join(exit_parts)

	# Extract destination name from arguments after "to"
	var dest_parts: Array[String] = []
	for i in range(to_index + 1, args.size()):
		dest_parts.append(args[i])
	var dest_name: String = " ".join(dest_parts)

	# Lookup destination room by ID or name
	var destination: WorldObject = null

	if dest_name.begins_with("#"):
		# ID-based lookup
		destination = WorldKeeper.get_object(dest_name)
	else:
		# Name-based lookup
		var all_rooms: Array[WorldObject] = WorldKeeper.get_all_rooms()
		for room in all_rooms:
			if room.name.to_lower() == dest_name.to_lower():
				destination = room
				break

	if destination == null:
		return {"success": false, "message": "Cannot find room: %s" % dest_name}

	if not destination.has_component("location"):
		return {"success": false, "message": "%s is not a room." % destination.name}

	# Verify current location can have exits
	if current_location == null:
		return {"success": false, "message": "You are nowhere."}

	var loc_comp = current_location.get_component("location")
	if loc_comp == null:
		return {"success": false, "message": "This location cannot have exits."}

	# Create the exit
	loc_comp.add_exit(exit_name, destination)

	# Broadcast exit creation event to current location
	EventWeaver.broadcast_to_location(current_location, {
		"type": "building",
		"actor": owner,
		"action": "creates an exit",
		"target": destination,
		"message": "%s creates an exit '%s' leading to %s." % [owner.name, exit_name, destination.name]
	})

	return {
		"success": true,
		"message": "Created exit: %s → %s [%s]\nReverse exit automatically created: %s can now be reached from %s." % [exit_name, destination.name, destination.id, current_location.name, destination.name]
	}


func _cmd_teleport(args: Array) -> Dictionary:
	"""@TELEPORT command - Instantly jump to any room or character's location (builder command).

	Moves the actor directly to the specified room without requiring
	an exit. Can teleport to a room by name/#ID, or to where a character is.

	Args:
		args: Array containing room name, #ID, or character name

	Returns:
		Dictionary with:
		- success (bool): True if teleport succeeded
		- message (String): Result of automatic look at destination
		- location (WorldObject): The destination location

	Notes:
		This is a builder/admin command that bypasses normal movement.
		If you name a character, it teleports you to that character's location.
		Automatically performs a look command at the destination.
	"""
	if args.size() == 0:
		return {"success": false, "message": "Usage: @teleport <room name, #ID, or character name>"}

	var dest_name: String = " ".join(args)
	var destination: WorldObject = null

	# Try ID-based lookup first
	if dest_name.begins_with("#"):
		destination = WorldKeeper.get_object(dest_name)
		if destination and not destination.has_component("location"):
			return {"success": false, "message": "%s [%s] is not a room" % [destination.name, destination.id]}
	else:
		# Try room name lookup (case-insensitive)
		var all_rooms: Array[WorldObject] = WorldKeeper.get_all_rooms()
		for room in all_rooms:
			if room.name.to_lower() == dest_name.to_lower():
				destination = room
				break

		# If no room found, try finding it as a character and teleport to their location
		if destination == null:
			var target_char: WorldObject = WorldKeeper.find_object_by_name(dest_name)
			if target_char:
				var char_location: WorldObject = target_char.get_location()
				if char_location and char_location.has_component("location"):
					destination = char_location
					print("Teleporting to %s's location: %s" % [target_char.name, destination.name])
				else:
					return {"success": false, "message": "%s is not in a valid location" % target_char.name}

	if destination == null:
		# Show helpful error with available rooms
		var room_list: String = "\nAvailable rooms:\n"
		var all_rooms_error: Array[WorldObject] = WorldKeeper.get_all_rooms()
		for room in all_rooms_error:
			room_list += "  • %s [%s]\n" % [room.name, room.id]
		return {"success": false, "message": "Cannot find room or character: %s%s" % [dest_name, room_list]}

	if not destination.has_component("location"):
		return {"success": false, "message": "%s is not a valid location" % destination.name}

	# Broadcast dramatic departure event to old location
	if current_location:
		EventWeaver.broadcast_to_location(current_location, {
			"type": "teleport",
			"actor": owner,
			"action": "teleports away",
			"message": "%s vanishes in a swirl of light." % owner.name
		})

	# Perform the teleport
	owner.move_to(destination)
	_update_location()

	# Broadcast dramatic arrival event to new location
	EventWeaver.broadcast_to_location(current_location, {
		"type": "teleport",
		"actor": owner,
		"action": "teleports in",
		"message": "%s appears in a swirl of light." % owner.name
	})

	# Automatically look at the new location
	return _cmd_look([])


func _cmd_save(_args: Array) -> Dictionary:
	"""@SAVE command - Save the world to markdown vault (builder command).

	Triggers WorldKeeper.save_world_to_vault() to persist the current
	world state to markdown files.

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): True if save succeeded
		- message (String): Confirmation or error message

	Notes:
		This is a builder/admin command for manually saving world state
	"""
	var success: bool = WorldKeeper.save_world_to_vault()

	if success:
		return {
			"success": true,
			"message": "World saved to vault!\nCheck the console output for details."
		}
	else:
		return {
			"success": false,
			"message": "Failed to save world to vault.\nCheck the console for errors."
		}


func _cmd_quit(_args: Array) -> Dictionary:
	"""@QUIT command - Save the world and gracefully exit the application.

	Triggers WorldKeeper.save_and_quit() which saves the world state
	and then quits the application.

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): Always true
		- message (String): Confirmation message

	Notes:
		This is an admin command for gracefully exiting the application.
		The world will be saved before exiting to prevent data loss.
	"""
	return {
		"success": true,
		"message": "Saving world and exiting...",
		"quit": true  # Special flag to trigger quit
	}


func _cmd_impersonate(args: Array) -> Dictionary:
	"""@IMPERSONATE command - See the game from an AI agent's perspective (debug command).

	Shows what prompt and context an AI agent would see, including their
	memories, location, occupants, and exact LLM prompt.

	Args:
		args: Array containing the agent name as first element

	Returns:
		Dictionary with:
		- success (bool): True if agent found and has thinker component
		- message (String): The agent's perspective including full prompt

	Notes:
		This is a debug/admin command for understanding AI agent behavior.
		Useful for debugging why agents make certain decisions.
	"""
	if args.size() == 0:
		return {"success": false, "message": "Usage: @impersonate <agent name>"}

	var agent_name: String = args[0]

	# Find the agent
	var agent: WorldObject = WorldKeeper.find_object_by_name(agent_name)
	if not agent:
		return {"success": false, "message": "Cannot find agent: %s" % agent_name}

	if not agent.has_component("thinker"):
		return {"success": false, "message": "%s is not an AI agent (no thinker component)" % agent_name}

	# Build the agent's context
	var thinker_comp: ThinkerComponent = agent.get_component("thinker") as ThinkerComponent
	var context: Dictionary = thinker_comp._build_context()
	var prompt: String = thinker_comp._construct_prompt(context)

	# Format the perspective to show exactly what the AI sees
	var message: String = "═══ Impersonating %s ═══\n\n" % agent_name

	message += "[What %s currently perceives]\n\n" % agent_name
	message += "Location: %s\n" % context.location_name
	message += "%s\n" % context.location_description

	if context.exits.size() > 0:
		message += "Exits: %s\n" % ", ".join(context.exits)
	else:
		message += "No exits visible\n"

	if context.occupants.size() > 0:
		message += "Also here: %s\n\n" % ", ".join(context.occupants)
	else:
		message += "Alone here\n\n"

	message += "[Full LLM Prompt - includes profile, commands, notes, and recent memories]\n"
	message += "────────────────────────────────────────────────────────────\n"
	message += "%s" % prompt
	message += "────────────────────────────────────────────────────────────\n"

	return {
		"success": true,
		"message": message
	}


func _cmd_show_profile(args: Array) -> Dictionary:
	"""@SHOW-PROFILE command - Display an agent's current profile (admin command).

	Shows the personality profile and settings for an AI agent.

	Args:
		args: Array containing the agent name as first element

	Returns:
		Dictionary with:
		- success (bool): True if agent found and has thinker component
		- message (String): The agent's current profile and settings

	Notes:
		This is an admin command for inspecting agent configuration
	"""
	if args.size() == 0:
		return {"success": false, "message": "Usage: @show-profile <agent name>"}

	var agent_name: String = args[0]

	# Find the agent
	var agent: WorldObject = WorldKeeper.find_object_by_name(agent_name)
	if not agent:
		return {"success": false, "message": "Cannot find agent: %s" % agent_name}

	if not agent.has_component("thinker"):
		return {"success": false, "message": "%s is not an AI agent (no thinker component)" % agent_name}

	# Get thinker component
	var thinker_comp: ThinkerComponent = agent.get_component("thinker") as ThinkerComponent

	var message: String = "═══ Profile for %s ═══\n\n" % agent_name
	message += "Think Interval: %.1f seconds\n\n" % thinker_comp.get_think_interval()
	message += "Personality Profile:\n"
	message += "────────────────────────────────────────────────────────────\n"
	message += "%s\n" % thinker_comp.get_profile()
	message += "────────────────────────────────────────────────────────────\n"

	return {
		"success": true,
		"message": message
	}


func _cmd_edit_profile(args: Array) -> Dictionary:
	"""@EDIT-PROFILE command - Change an agent's personality profile (admin command).

	Syntax: @edit-profile <agent name> -> <new profile text>

	Args:
		args: Array with agent name and profile text separated by ->

	Returns:
		Dictionary with success status and message

	Notes:
		This is an admin command for configuring AI agent behavior.
		The profile is used as the system prompt for LLM decisions.
	"""
	if args.size() == 0:
		return {"success": false, "message": "Usage: @edit-profile <agent name> -> <new profile>"}

	var full_args: String = " ".join(args)
	if not "->" in full_args:
		return {"success": false, "message": "Usage: @edit-profile <agent name> -> <new profile> (arrow required)"}

	var parts: PackedStringArray = full_args.split("->", true, 1)
	var agent_name: String = parts[0].strip_edges()
	var new_profile: String = parts[1].strip_edges() if parts.size() > 1 else ""

	if new_profile == "":
		return {"success": false, "message": "Profile cannot be empty"}

	# Find the agent
	var agent: WorldObject = WorldKeeper.find_object_by_name(agent_name)
	if not agent:
		return {"success": false, "message": "Cannot find agent: %s" % agent_name}

	if not agent.has_component("thinker"):
		return {"success": false, "message": "%s is not an AI agent (no thinker component)" % agent_name}

	# Update the profile via ThinkerComponent
	var thinker_comp: ThinkerComponent = agent.get_component("thinker") as ThinkerComponent
	thinker_comp.set_profile(new_profile)

	# Save agent to vault to persist the change
	AIAgent._save_agent_to_vault(agent)

	return {
		"success": true,
		"message": "Updated profile for %s\n\nNew profile:\n%s" % [agent_name, new_profile]
	}


func _cmd_edit_interval(args: Array) -> Dictionary:
	"""@EDIT-INTERVAL command - Change how often an agent thinks (admin command).

	Syntax: @edit-interval <agent name> <seconds>

	Args:
		args: Array with agent name and interval in seconds

	Returns:
		Dictionary with success status and message

	Notes:
		This is an admin command for controlling AI agent thinking frequency.
		Lower intervals make agents more reactive but use more LLM resources.
		Higher intervals make agents slower but more deliberate.
	"""
	if args.size() < 2:
		return {"success": false, "message": "Usage: @edit-interval <agent name> <seconds>"}

	var agent_name: String = args[0]
	var interval_str: String = args[1]

	if not interval_str.is_valid_float():
		return {"success": false, "message": "Interval must be a number (seconds)"}

	var new_interval: float = interval_str.to_float()

	if new_interval < 1.0:
		return {"success": false, "message": "Interval must be at least 1.0 seconds"}

	# Find the agent
	var agent: WorldObject = WorldKeeper.find_object_by_name(agent_name)
	if not agent:
		return {"success": false, "message": "Cannot find agent: %s" % agent_name}

	if not agent.has_component("thinker"):
		return {"success": false, "message": "%s is not an AI agent (no thinker component)" % agent_name}

	# Update the think interval via ThinkerComponent
	var thinker_comp: ThinkerComponent = agent.get_component("thinker") as ThinkerComponent
	thinker_comp.set_think_interval(new_interval)

	# Save agent to vault to persist the change
	AIAgent._save_agent_to_vault(agent)

	return {
		"success": true,
		"message": "Updated think interval for %s to %.1f seconds" % [agent_name, new_interval]
	}


func _cmd_my_profile(_args: Array) -> Dictionary:
	"""@MY-PROFILE command - View your own personality profile (self-awareness).

	Shows the current personality profile if this actor has a thinker component.
	Works for both players (to see their character concept) and AI agents
	(for self-reflection and potential self-modification).

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): True if actor has a profile
		- message (String): Current profile and think interval

	Notes:
		This enables AI agents to be aware of their own configuration.
		Future: Agents could analyze and modify their own profiles.
	"""
	if not owner.has_component("thinker"):
		return {
			"success": false,
			"message": "You don't have a personality profile (no thinker component)."
		}

	var thinker_comp: ThinkerComponent = owner.get_component("thinker") as ThinkerComponent

	var message: String = "═══ Your Profile ═══\n\n"
	message += "Think Interval: %.1f seconds\n\n" % thinker_comp.get_think_interval()
	message += "Your Personality:\n"
	message += "────────────────────────────────────────────────────────────\n"
	message += "%s\n" % thinker_comp.get_profile()
	message += "────────────────────────────────────────────────────────────\n\n"
	message += "Use @set-profile to update your personality.\n"
	message += "Use @my-description to view/edit your physical description."

	return {
		"success": true,
		"message": message
	}


func _cmd_my_description(_args: Array) -> Dictionary:
	"""@MY-DESCRIPTION command - View your own description (self-awareness).

	Shows how others see you when they examine you.
	Works for all actors (players and AI agents).

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): Always true
		- message (String): Current description

	Notes:
		This enables self-reflection and self-modification.
		Agents can see how they appear to others.
	"""
	var message: String = "═══ How Others See You ═══\n\n"
	message += "%s\n\n" % owner.description
	message += "Use @set-description to update how you appear to others."

	return {
		"success": true,
		"message": message
	}


func _cmd_set_profile(args: Array) -> Dictionary:
	"""@SET-PROFILE command - Update your own personality profile (self-modification).

	Syntax: @set-profile -> <new profile text>

	Allows actors to modify their own personality. This enables:
	- Players to adjust their character concept
	- AI agents to evolve based on experience (future)
	- Self-directed character development

	Args:
		args: Array with profile text after ->

	Returns:
		Dictionary with success status and message

	Notes:
		This is a powerful command - agents can reprogram themselves!
		Changes are saved to vault automatically.
	"""
	if not owner.has_component("thinker"):
		return {
			"success": false,
			"message": "You don't have a personality profile to modify (no thinker component)."
		}

	if args.size() == 0:
		return {"success": false, "message": "Usage: @set-profile -> <new profile>"}

	var full_args: String = " ".join(args)
	if not "->" in full_args:
		return {"success": false, "message": "Usage: @set-profile -> <new profile> (arrow required)"}

	var parts: PackedStringArray = full_args.split("->", true, 1)
	var new_profile: String = parts[1].strip_edges() if parts.size() > 1 else ""

	if new_profile == "":
		return {"success": false, "message": "Profile cannot be empty"}

	# Update profile
	var thinker_comp: ThinkerComponent = owner.get_component("thinker") as ThinkerComponent
	var old_profile: String = thinker_comp.get_profile()
	thinker_comp.set_profile(new_profile)

	# Save to vault
	AIAgent._save_agent_to_vault(owner)

	# Broadcast self-modification event (observable but not intrusive)
	if current_location:
		EventWeaver.broadcast_to_location(current_location, {
			"type": "action",
			"actor": owner,
			"action": "pauses in deep contemplation",
			"message": "%s pauses in deep contemplation." % owner.name
		})

	var message: String = "You have updated your personality profile.\n\n"
	message += "Old profile:\n%s\n\n" % old_profile
	message += "New profile:\n%s\n\n" % new_profile
	message += "This change will affect your future decisions and behavior."

	return {
		"success": true,
		"message": message
	}


func _cmd_set_description(args: Array) -> Dictionary:
	"""@SET-DESCRIPTION command - Update your own description (self-modification).

	Syntax: @set-description -> <new description text>

	Allows actors to change how they appear to others when examined.

	Args:
		args: Array with description text after ->

	Returns:
		Dictionary with success status and message

	Notes:
		This changes how others see you with the examine command.
		Changes are saved to vault automatically.
	"""
	if args.size() == 0:
		return {"success": false, "message": "Usage: @set-description -> <new description>"}

	var full_args: String = " ".join(args)
	if not "->" in full_args:
		return {"success": false, "message": "Usage: @set-description -> <new description> (arrow required)"}

	var parts: PackedStringArray = full_args.split("->", true, 1)
	var new_description: String = parts[1].strip_edges() if parts.size() > 1 else ""

	if new_description == "":
		return {"success": false, "message": "Description cannot be empty"}

	var old_description: String = owner.description
	owner.description = new_description

	# Save to vault if this is an AI agent
	if owner.has_component("thinker"):
		AIAgent._save_agent_to_vault(owner)

	# Broadcast observable behavior
	if current_location:
		EventWeaver.broadcast_to_location(current_location, {
			"type": "action",
			"actor": owner,
			"action": "adjusts their appearance",
			"message": "%s adjusts their appearance." % owner.name
		})

	var message: String = "You have updated your description.\n\n"
	message += "Old description:\n%s\n\n" % old_description
	message += "New description:\n%s\n\n" % new_description
	message += "This is how others will see you when they examine you."

	return {
		"success": true,
		"message": message
	}


func _cmd_help(args: Array) -> Dictionary:
	"""HELP command - Get help on commands and categories.

	With no arguments, shows overview of categories and usage.
	With a command name, shows detailed help for that command.
	With a category name, shows all commands in that category.

	Args:
		args: Optional command or category name

	Returns:
		Dictionary with:
		- success (bool): True if help was found
		- message (String): Formatted help text

	Notes:
		Aliases are automatically resolved (e.g., "help l" shows "look").
		Supports both full command names and aliases.
	"""
	if args.size() == 0:
		return _show_help_overview()

	var query: String = args[0].to_lower()

	# Check if query is a category
	if query in CommandMetadata.CATEGORIES:
		return _show_category_help(query)

	# Check if query is a command
	if query in CommandMetadata.COMMANDS:
		return _show_command_help(query)

	# Try resolving as alias
	var resolved: String = CommandMetadata.resolve_alias(query)
	if resolved != "":
		return _show_command_help(resolved)

	return {
		"success": false,
		"message": "Unknown command or category: %s\nTry 'help' for an overview." % query
	}


func _show_help_overview() -> Dictionary:
	"""Show general help overview with categories.

	Returns:
		Dictionary with formatted overview of all command categories
	"""
	var text: String = "═══ Miniworld Help ═══\n\n"

	text += "Available command categories:\n\n"

	# Show categories with descriptions
	for category in CommandMetadata.CATEGORIES:
		text += "  • %s - %s\n" % [category, CommandMetadata.CATEGORIES[category]]

	text += "\nUsage:\n"
	text += "  help <command>  - Detailed help on a specific command\n"
	text += "  help <category> - List all commands in a category\n"
	text += "  commands        - List all available commands\n"
	text += "  ? <command>     - Shortcut for help\n"

	return {"success": true, "message": text}


func _show_command_help(command: String) -> Dictionary:
	"""Show detailed help for a specific command.

	Args:
		command: The command name to show help for

	Returns:
		Dictionary with detailed command information
	"""
	var cmd_info: Dictionary = CommandMetadata.COMMANDS[command]

	var text: String = "═══ %s ═══\n\n" % command.to_upper()
	text += "%s\n\n" % cmd_info.description

	if cmd_info.has("syntax"):
		text += "Syntax: %s\n" % cmd_info.syntax

	if cmd_info.has("aliases") and cmd_info.aliases.size() > 0:
		text += "Aliases: %s\n" % ", ".join(cmd_info.aliases)

	if cmd_info.has("example"):
		text += "\nExample:\n  %s\n" % cmd_info.example

	if cmd_info.has("admin") and cmd_info.admin:
		text += "\n[Admin/Builder Command]\n"

	text += "\nCategory: %s\n" % cmd_info.category

	return {"success": true, "message": text}


func _show_category_help(category: String) -> Dictionary:
	"""Show all commands in a specific category.

	Args:
		category: The category name to show commands for

	Returns:
		Dictionary with formatted list of commands in category
	"""
	var text: String = "═══ %s Commands ═══\n\n" % category.capitalize()
	text += "%s\n\n" % CommandMetadata.CATEGORIES[category]

	# Get all commands in this category
	var commands: Array = CommandMetadata.get_commands_in_category(category)

	if commands.size() == 0:
		text += "No commands in this category.\n"
	else:
		for cmd_name in commands:
			var cmd_info: Dictionary = CommandMetadata.COMMANDS[cmd_name]
			var admin_marker: String = " [admin]" if cmd_info.get("admin", false) else ""
			text += "  %-20s %s%s\n" % [cmd_name, cmd_info.description, admin_marker]

	text += "\nUse 'help <command>' for detailed information.\n"

	return {"success": true, "message": text}


func _cmd_commands(_args: Array) -> Dictionary:
	"""COMMANDS command - List all available commands in compact format.

	Groups commands by category for easy scanning.

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): Always true
		- message (String): Compact list of all commands grouped by category
	"""
	var text: String = "Available Commands:\n\n"

	# Define category order for consistent display
	var categories: Array = ["social", "movement", "memory", "self", "building", "admin", "query"]

	for category in categories:
		var cmds: Array = CommandMetadata.get_commands_in_category(category)

		if cmds.size() > 0:
			text += "%s: %s\n" % [category.capitalize(), ", ".join(cmds)]

	text += "\nUse 'help <command>' for details on any command.\n"

	return {"success": true, "message": text}


func _cmd_reload_text(_args: Array) -> Dictionary:
	"""@RELOAD-TEXT command - Hot-reload all text and config from vault (admin command).

	Reloads all text strings and configuration values from vault files
	without restarting the game. Useful for testing text changes.

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): Always true
		- message (String): Confirmation with entry counts

	Notes:
		This is an admin command for development and customization
	"""
	TextManager.reload()

	return {
		"success": true,
		"message": "Text and config reloaded from vault!\n\nText entries: %d\nConfig entries: %d\n\nChanges are now active." % [TextManager._text_data.size(), TextManager._config_data.size()]
	}


func _cmd_show_text(args: Array) -> Dictionary:
	"""@SHOW-TEXT command - Display a text entry from the vault (admin command).

	Shows the current value of a text key and available variables.

	Syntax: @show-text <key>

	Args:
		args: Array with text key as first element

	Returns:
		Dictionary with success status and text value

	Notes:
		This is an admin command for inspecting text values
	"""
	if args.size() == 0:
		return {"success": false, "message": "Usage: @show-text <key>\n\nExample: @show-text commands.social.say.success"}

	var key: String = args[0]
	var value: String = TextManager.get_text(key)

	if value.is_empty():
		return {"success": false, "message": "Text key not found: %s\n\nCheck vault files or use inline fallback." % key}

	var message: String = "═══ Text Entry ═══\n\n"
	message += "Key: %s\n" % key
	message += "Value: %s\n\n" % value

	# Show available variables
	if "{" in value:
		message += "Variables: "
		var vars := []
		var regex := RegEx.new()
		regex.compile("\\{([^}]+)\\}")
		for match in regex.search_all(value):
			vars.append(match.get_string(1))
		message += ", ".join(vars) + "\n"

	return {"success": true, "message": message}


func _cmd_show_config(args: Array) -> Dictionary:
	"""@SHOW-CONFIG command - Display a config value from the vault (admin command).

	Shows the current value and type of a configuration entry.

	Syntax: @show-config <key>

	Args:
		args: Array with config key as first element

	Returns:
		Dictionary with success status and config value

	Notes:
		This is an admin command for inspecting configuration
	"""
	if args.size() == 0:
		return {"success": false, "message": "Usage: @show-config <key>\n\nExample: @show-config ai_defaults.think_interval"}

	var key: String = args[0]
	var value: Variant = TextManager.get_config(key)

	if value == null:
		return {"success": false, "message": "Config key not found: %s\n\nCheck vault/config/ files." % key}

	var message: String = "═══ Config Entry ═══\n\n"
	message += "Key: %s\n" % key
	message += "Value: %s\n" % str(value)
	message += "Type: %s\n" % type_string(typeof(value))

	return {"success": true, "message": message}


func _cmd_memory_status(_args: Array) -> Dictionary:
	"""@MEMORY-STATUS command - Display memory system integrity report (admin command).

	Shows comprehensive memory system statistics including:
	- Memory count and capacity utilization
	- Note count and recent activity
	- Last memory timestamp
	- Any warnings or issues detected

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): True if actor has memory component
		- message (String): Formatted integrity report

	Notes:
		This is an admin/query command for verifying memory system health.
		Focuses on application-level concerns, trusts OS for file integrity.
	"""
	if not owner.has_component("memory"):
		return {"success": false, "message": "No memory component found."}

	var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent
	var report: String = memory_comp.format_integrity_report()

	return {"success": true, "message": report}


func _cmd_compact_memories(_args: Array) -> Dictionary:
	"""@COMPACT-MEMORIES command - Manually trigger memory compaction (admin command).

	Forces immediate memory compaction regardless of threshold.
	Generates cascading temporal summaries using LLM:
	- Recent summary: Memories outside immediate window
	- Long-term summary: All older memories (waterfall pattern)

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): True if compaction initiated
		- message (String): Status message

	Notes:
		Compaction runs asynchronously. Use @memory-status to check results.
		This command is useful for testing or forcing compaction early.
	"""
	if not owner.has_component("memory"):
		return {"success": false, "message": "No memory component found."}

	var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent

	# Check if we have enough memories to compact
	var immediate_window: int = memory_comp._get_compaction_config("immediate_window", 20)
	if memory_comp.memories.size() <= immediate_window:
		return {
			"success": false,
			"message": "Not enough memories to compact. Need more than %d memories." % immediate_window
		}

	# Trigger compaction asynchronously
	memory_comp.compact_memories_async(func():
		print("[Actor] %s: Memory compaction completed" % owner.name)
	)

	return {
		"success": true,
		"message": "Memory compaction started. Generating summaries asynchronously..."
	}


func _cmd_bootstrap_summaries(args: Array) -> Dictionary:
	"""@BOOTSTRAP-SUMMARIES command - Generate initial summaries for existing memories (admin command).

	Creates long-term and mid-term summaries from existing memory history,
	allowing agents to immediately benefit from the multi-scale context system
	without waiting for natural compaction cycles.

	Syntax:
		@bootstrap-summaries - Bootstrap your own summaries
		@bootstrap-summaries <agent name> - Bootstrap summaries for another agent

	Args:
		args: Optional agent name to bootstrap (defaults to self)

	Returns:
		Dictionary with:
		- success (bool): True if bootstrap initiated
		- message (String): Status message

	Notes:
		Bootstrap only runs if agent has sufficient memories (> 128) and
		no existing summaries. Runs asynchronously.
	"""
	var target_agent: WorldObject = owner

	# If agent name provided, find that agent
	if args.size() > 0:
		var agent_name: String = args[0]
		target_agent = WorldKeeper.find_object_by_name(agent_name)
		if not target_agent:
			return {"success": false, "message": "Cannot find agent: %s" % agent_name}

	if not target_agent.has_component("memory"):
		return {"success": false, "message": "%s has no memory component." % target_agent.name}

	var memory_comp: MemoryComponent = target_agent.get_component("memory") as MemoryComponent

	# Check if already has summaries
	if memory_comp.recent_summary != "" or memory_comp.longterm_summary != "":
		return {
			"success": false,
			"message": "%s already has summaries. Use @compact-memories to update them." % target_agent.name
		}

	# Check vault file count (not in-RAM count, which may be limited by MemoryBudget)
	var immediate_window: int = memory_comp._get_compaction_config("immediate_window", 64)
	var recent_window: int = memory_comp._get_compaction_config("recent_window", 64)
	var bootstrap_threshold: int = immediate_window + recent_window

	var vault_count: int = memory_comp.get_vault_memory_count(target_agent.name)
	var loaded_count: int = memory_comp.memories.size()

	if vault_count <= bootstrap_threshold:
		return {
			"success": false,
			"message": "%s doesn't have enough vault memories to bootstrap. Need more than %d, has %d in vault (%d loaded)." % [
				target_agent.name,
				bootstrap_threshold,
				vault_count,
				loaded_count
			]
		}

	# Trigger bootstrap (generate both recent and longterm summaries)
	memory_comp.bootstrap_summaries_async(true, true, func():
		print("[Actor] %s: Summary bootstrap completed" % target_agent.name)
	)

	return {
		"success": true,
		"message": "Bootstrapping summaries for %s (%d vault memories, %d loaded). This will run asynchronously..." % [
			target_agent.name,
			vault_count,
			loaded_count
		]
	}


func _cmd_llm_status(_args: Array) -> Dictionary:
	"""@LLM-STATUS command - Display LLM connection status (admin command).

	Shows current LLM configuration and connection status including:
	- Availability (connected/disconnected)
	- Host URL and model name
	- Temperature and max tokens settings
	- Queue status
	- Last error details (if any)

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): Always true
		- message (String): Formatted status report

	Notes:
		This is an admin command for diagnosing LLM connectivity issues.
		Use this after seeing connection failed errors.
	"""
	if not Shoggoth:
		return {"success": false, "message": "Shoggoth daemon not available"}

	var status: Dictionary = Shoggoth.get_status()

	var message: String = "═══ LLM Status ═══\n\n"

	# Connection status
	if status.is_available:
		message += "[color=green]✓ Connected[/color]\n\n"
	else:
		message += "[color=red]✗ Disconnected[/color]\n\n"

	# Configuration
	message += "Host: %s\n" % status.host
	message += "Model: %s\n" % status.model
	message += "Temperature: %.2f\n" % status.temperature
	message += "Max Tokens: %d\n\n" % status.max_tokens

	# Queue status
	message += "Queue Length: %d task(s)\n" % status.queue_length
	message += "Busy: %s\n\n" % ("Yes" if status.is_busy else "No")

	# Last error (if any)
	if status.last_error.size() > 0:
		message += "[color=yellow]Last Error:[/color]\n"
		message += "Type: %s\n" % status.last_error.type
		message += "Message: %s\n" % status.last_error.message
		message += "Suggestion: %s\n\n" % status.last_error.suggested_action
		var timestamp: float = status.last_error.timestamp
		var time_ago: int = int(Time.get_unix_time_from_system() - timestamp)
		message += "(occurred %d seconds ago)\n\n" % time_ago

	message += "Use @llm-config to modify settings"

	return {"success": true, "message": message}


func _cmd_llm_config(args: Array) -> Dictionary:
	"""@LLM-CONFIG command - Configure LLM settings (admin command).

	Allows changing LLM configuration at runtime without restarting.

	Syntax:
		@llm-config host <url>        - Set Ollama server URL
		@llm-config model <name>      - Set model name
		@llm-config temperature <num> - Set temperature (0.0-1.0)
		@llm-config test              - Test current connection
		@llm-config                   - Show current configuration

	Args:
		args: Array with subcommand and value

	Returns:
		Dictionary with success status and message

	Notes:
		This is an admin command for runtime configuration.
		Changes are saved immediately and persist across restarts.
		Changing host or model triggers re-initialization.
	"""
	if not Shoggoth:
		return {"success": false, "message": "Shoggoth daemon not available"}

	# No args - show current config
	if args.size() == 0:
		var status: Dictionary = Shoggoth.get_status()
		var message: String = "═══ LLM Configuration ═══\n\n"
		message += "Host: %s\n" % status.host
		message += "Model: %s\n" % status.model
		message += "Temperature: %.2f\n" % status.temperature
		message += "Max Tokens: %d\n\n" % status.max_tokens
		message += "Usage:\n"
		message += "  @llm-config host <url>\n"
		message += "  @llm-config model <name>\n"
		message += "  @llm-config temperature <0.0-1.0>\n"
		message += "  @llm-config test\n"
		return {"success": true, "message": message}

	var subcommand: String = args[0].to_lower()

	match subcommand:
		"host":
			if args.size() < 2:
				return {"success": false, "message": "Usage: @llm-config host <url>\nExample: @llm-config host http://localhost:11434"}
			var new_host: String = args[1]
			Shoggoth.set_host(new_host)
			return {"success": true, "message": "Host set to: %s\nRe-initializing connection..." % new_host}

		"model":
			if args.size() < 2:
				return {"success": false, "message": "Usage: @llm-config model <name>\nExample: @llm-config model llama3.2:3b"}
			var new_model: String = args[1]
			Shoggoth.set_model(new_model)
			return {"success": true, "message": "Model set to: %s\nRe-initializing connection..." % new_model}

		"temperature", "temp":
			if args.size() < 2:
				return {"success": false, "message": "Usage: @llm-config temperature <0.0-1.0>\nExample: @llm-config temperature 0.7"}
			var temp_str: String = args[1]
			if not temp_str.is_valid_float():
				return {"success": false, "message": "Temperature must be a number between 0.0 and 1.0"}
			var new_temp: float = temp_str.to_float()
			if new_temp < 0.0 or new_temp > 1.0:
				return {"success": false, "message": "Temperature must be between 0.0 and 1.0"}
			Shoggoth.set_temperature(new_temp)
			return {"success": true, "message": "Temperature set to: %.2f" % new_temp}

		"test":
			Shoggoth.test_connection()
			return {"success": true, "message": "Testing LLM connection...\nWatch for status messages."}

		_:
			return {"success": false, "message": "Unknown subcommand: %s\nTry: host, model, temperature, test" % subcommand}


func _cmd_narrative(args: Array) -> Dictionary:
	"""@NARRATIVE command - View global narrative chronicle.

	Shows recent events across all locations from an observer perspective.

	Syntax:
		@narrative [limit]  - View recent N entries (default: 50)

	Args:
		args: Optional limit number

	Returns:
		Dictionary with success status and formatted chronicle

	Notes:
		Events displayed in chronological order with location tags.
		Silent observer viewpoint - no "you" language.
	"""
	if not NarrativeLog:
		return {"success": false, "message": "NarrativeLog daemon not available"}

	var limit: int = NarrativeLog.DEFAULT_VIEW_LIMIT
	if args.size() > 0:
		if args[0].is_valid_int():
			limit = args[0].to_int()
		else:
			return {"success": false, "message": "Usage: @narrative [limit]\nExample: @narrative 100"}

	var entries: Array[String] = NarrativeLog.get_chronicle(limit)
	if entries.is_empty():
		return {"success": true, "message": "No narrative events recorded yet."}

	var message: String = "═══ Narrative Chronicle ═══\n\n"
	message += "Showing %d recent events across all locations:\n\n" % entries.size()
	for entry in entries:
		message += entry + "\n"

	return {"success": true, "message": message}


func _cmd_narrative_here(args: Array) -> Dictionary:
	"""@NARRATIVE-HERE command - View narrative log for current location.

	Shows recent events that occurred in the current room.

	Syntax:
		@narrative-here [limit]  - View recent N entries (default: 50)

	Args:
		args: Optional limit number

	Returns:
		Dictionary with success status and formatted location log

	Notes:
		Only shows events from current location.
		Silent observer viewpoint - no "you" language.
	"""
	if not NarrativeLog:
		return {"success": false, "message": "NarrativeLog daemon not available"}

	_update_location()
	if not current_location:
		return {"success": false, "message": "You are not in a location."}

	var limit: int = NarrativeLog.DEFAULT_VIEW_LIMIT
	if args.size() > 0:
		if args[0].is_valid_int():
			limit = args[0].to_int()
		else:
			return {"success": false, "message": "Usage: @narrative-here [limit]\nExample: @narrative-here 100"}

	var location_id: String = current_location.id if current_location.id else current_location.name.replace(" ", "_").to_lower()

	var entries: Array[String] = NarrativeLog.get_location_log(location_id, limit)
	if entries.is_empty():
		return {"success": true, "message": "No narrative events recorded at this location yet."}

	var location_name: String = current_location.name
	var message: String = "═══ Narrative Log: %s ═══\n\n" % location_name
	message += "Showing %d recent events:\n\n" % entries.size()
	for entry in entries:
		message += entry + "\n"

	return {"success": true, "message": message}


func _cmd_narrative_clear(args: Array) -> Dictionary:
	"""@NARRATIVE-CLEAR command - Clear narrative logs (admin command).

	Clears either all narrative logs or current location's log.

	Syntax:
		@narrative-clear all   - Clear entire chronicle
		@narrative-clear here  - Clear current location's log

	Args:
		args: Subcommand (all or here)

	Returns:
		Dictionary with success status and message

	Notes:
		This is an admin command. Use with caution.
	"""
	if not NarrativeLog:
		return {"success": false, "message": "NarrativeLog daemon not available"}

	if args.size() == 0:
		return {"success": false, "message": "Usage: @narrative-clear <all|here>\nExamples:\n  @narrative-clear all\n  @narrative-clear here"}

	var subcommand: String = args[0].to_lower()

	match subcommand:
		"all":
			NarrativeLog.clear_all()
			return {"success": true, "message": "All narrative logs cleared."}

		"here":
			_update_location()
			if not current_location:
				return {"success": false, "message": "You are not in a location."}

			var location_id: String = current_location.id if current_location.id else current_location.name.replace(" ", "_").to_lower()

			NarrativeLog.clear_location(location_id)
			var location_name: String = current_location.name
			return {"success": true, "message": "Narrative log cleared for: %s" % location_name}

		_:
			return {"success": false, "message": "Unknown subcommand: %s\nUse: all or here" % subcommand}


func _cmd_training_status(_args: Array) -> Dictionary:
	"""@TRAINING-STATUS command - Display training data collection statistics (admin command).

	Shows current collection status, counts of successful/unsuccessful examples,
	and provides guidance on exporting the dataset.

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): True if TrainingDataCollector is available
		- message (String): Formatted status report

	Notes:
		This is an admin command for monitoring training data collection.
	"""
	if not TrainingDataCollector:
		return {"success": false, "message": "TrainingDataCollector daemon not loaded.\nCheck project autoload settings."}

	var status: Dictionary = TrainingDataCollector.get_status()

	var message: String = "═══ Training Data Collection Status ═══\n\n"

	# Collection state
	if status.enabled:
		message += "[color=green]✓ Collection ENABLED[/color]\n\n"
	else:
		message += "[color=red]✗ Collection DISABLED[/color]\n\n"

	# Session statistics
	message += "Session Statistics:\n"
	message += "  Successful examples: %d\n" % status.successful_count
	message += "  Unsuccessful examples: %d\n" % status.unsuccessful_count
	message += "  Pending (awaiting result): %d\n\n" % status.pending_count

	# Total on disk
	message += "Total on Disk:\n"
	message += "  Successful: %d examples\n" % status.total_successful
	message += "  Unsuccessful: %d examples\n\n" % status.total_unsuccessful

	# Guidance
	message += "Commands:\n"
	message += "  @training-export - Export consolidated training file\n"
	message += "  @training-toggle - Enable/disable collection\n"
	message += "  @training-clear - Delete all collected data\n\n"

	message += "Location: user://training_data/\n"

	return {"success": true, "message": message}


func _cmd_training_export(args: Array) -> Dictionary:
	"""@TRAINING-EXPORT command - Export training data with filtering (admin command).

	Combines training examples into a single file suitable for fine-tuning,
	with flexible filtering options.

	Syntax:
		@training-export - Export successful examples (default)
		@training-export <filename> - Export to custom filename
		@training-export failed - Export only failed examples
		@training-export all - Export all examples (successful + failed)
		@training-export agent <name> - Export only examples from specific agent
		@training-export exclude <name> - Export excluding specific agent

	Args:
		args: Optional arguments for filename and filtering

	Returns:
		Dictionary with:
		- success (bool): Whether export succeeded
		- message (String): Result message with file locations and counts

	Notes:
		Creates timestamped filename if not specified.
		Includes instructions for sharing data with the Miniworld community.
	"""
	if not TrainingDataCollector:
		return {"success": false, "message": "TrainingDataCollector daemon not loaded."}

	# Parse arguments for filters and filename
	var filters: Dictionary = {}
	var output_path: String = ""

	var i := 0
	while i < args.size():
		var arg: String = args[i]

		if arg == "failed":
			filters["failed_only"] = true
			filters["success_only"] = false
		elif arg == "all":
			filters["success_only"] = false
			filters["failed_only"] = false
		elif arg == "agent" and i + 1 < args.size():
			if not filters.has("agents"):
				filters["agents"] = []
			filters["agents"].append(args[i + 1])
			i += 1  # Skip next arg
		elif arg == "exclude" and i + 1 < args.size():
			if not filters.has("exclude_agents"):
				filters["exclude_agents"] = []
			filters["exclude_agents"].append(args[i + 1])
			i += 1  # Skip next arg
		elif output_path == "":
			# First non-flag argument is filename
			output_path = arg

		i += 1

	# Determine output path
	if output_path == "":
		var timestamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-")
		output_path = "user://miniworld_training_%s.txt" % timestamp
	elif not output_path.begins_with("user://"):
		output_path = "user://%s" % output_path

	if not output_path.ends_with(".txt"):
		output_path += ".txt"

	# Export the data with filters
	var export_result: Dictionary = TrainingDataCollector.export_consolidated_dataset(output_path, filters)

	if not export_result.success:
		return export_result

	# Build success message with filter info
	var message: String = "═══ Training Data Exported ═══\n\n"
	message += "Successfully exported:\n"
	message += "  %d examples included\n" % export_result.included_count
	if export_result.excluded_count > 0:
		message += "  %d examples excluded by filters\n" % export_result.excluded_count
	message += "\n"

	# Show active filters
	if filters.size() > 0:
		message += "Filters applied:\n"
		if filters.get("success_only", true):
			message += "  ✓ Success only\n"
		if filters.get("failed_only", false):
			message += "  ✓ Failed only\n"
		if filters.has("agents"):
			message += "  ✓ Agents: %s\n" % ", ".join(filters.agents)
		if filters.has("exclude_agents"):
			message += "  ✓ Excluding: %s\n" % ", ".join(filters.exclude_agents)
		message += "\n"

	message += "File created:\n"
	message += "  %s\n\n" % output_path

	# Add sharing instructions
	message += "═══ Share Your Data! ═══\n\n"
	message += "Help improve Miniworld for everyone!\n\n"
	message += "To contribute your training data:\n"
	message += "1. Find the exported file in your Godot user data folder\n"
	message += "2. Zip it up: miniworld_training_data.zip\n"
	message += "3. Share via:\n"
	message += "   - GitHub issue/discussion\n"
	message += "   - Discord/community channels\n"
	message += "   - Direct message to maintainers\n\n"
	message += "Your gameplay examples help fine-tune AI for better commands!\n"

	return {"success": true, "message": message}


func _cmd_training_clear(_args: Array) -> Dictionary:
	"""@TRAINING-CLEAR command - Delete all collected training data (admin command).

	WARNING: This permanently deletes all training examples. Cannot be undone!

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): Whether clear succeeded
		- message (String): Confirmation of deletion

	Notes:
		Use with caution - deleted data cannot be recovered.
	"""
	if not TrainingDataCollector:
		return {"success": false, "message": "TrainingDataCollector daemon not loaded."}

	# Clear all data
	var clear_result: Dictionary = TrainingDataCollector.clear_all_data()

	var message: String = "═══ Training Data Cleared ═══\n\n"
	message += "%s\n\n" % clear_result.message
	message += "[color=yellow]WARNING: This action cannot be undone![/color]\n"

	return clear_result


func _cmd_training_toggle(_args: Array) -> Dictionary:
	"""@TRAINING-TOGGLE command - Enable/disable training data collection (admin command).

	Toggles collection on/off. Useful for:
	- Pausing collection during testing/debugging
	- Collecting only specific gameplay sessions
	- Reducing disk usage

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): Always true
		- message (String): New collection state

	Notes:
		State is persisted to config file.
	"""
	if not TrainingDataCollector:
		return {"success": false, "message": "TrainingDataCollector daemon not loaded."}

	# Toggle collection
	var new_state: bool = TrainingDataCollector.toggle_collection()

	var message: String = "Training data collection is now "
	if new_state:
		message += "[color=green]ENABLED[/color]"
	else:
		message += "[color=red]DISABLED[/color]"

	return {"success": true, "message": message}
