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
##   - @save, @impersonate (admin/debug utilities)
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


func execute_command(command: String, args: Array = [], reason: String = "") -> Dictionary:
	"""Execute a command as this actor and return the result.

	Matches the command string against known commands and dispatches
	to the appropriate handler function. Updates location cache before
	execution and emits command_executed signal after completion.

	Args:
		command: The command verb to execute (case-insensitive)
		args: Array of string arguments for the command
		reason: Optional reasoning/commentary for this command (appears in echoes)

	Returns:
		Dictionary containing at least:
		- success (bool): Whether the command succeeded
		- message (String): Result message to display
		Additional keys may be present depending on command
	"""
	_update_location()

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
		_:
			result = {"success": false, "message": "Unknown command: %s\nTry 'help' for available commands." % command}

	# Reconstruct full command line from verb and args for caching
	var full_command: String = command
	if args.size() > 0:
		full_command += " " + " ".join(args)

	# Cache command, result, and reason for inspection
	last_command = full_command
	last_result = result
	last_reason = reason
	command_executed.emit(command, result, reason)

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
		- message (String): Formatted description of location and contents
		- location (WorldObject): The location object being observed
	"""
	if current_location == null:
		return {"success": false, "message": "You are nowhere."}

	var desc: String = current_location.get_description()

	# Add contents listing from location component
	var location_comp = current_location.get_component("location")
	if location_comp != null:
		desc += "\n\n" + location_comp.get_contents_description()

	# Notify other actors in location
	EventWeaver.broadcast_to_location(current_location, {
		"type": "action",
		"actor": owner,
		"action": "looks around",
		"message": "%s looks around." % owner.name
	})

	return {
		"success": true,
		"message": desc,
		"location": current_location
	}


func _cmd_go(args: Array) -> Dictionary:
	"""GO command - Move to another location through an exit.

	Attempts to find and traverse an exit in the current location.
	Broadcasts departure and arrival events. Automatically performs
	a look command at the destination.

	Args:
		args: Array containing the exit name as the first element

	Returns:
		Dictionary with:
		- success (bool): True if movement succeeded
		- message (String): Result of automatic look at destination, or error
		- location (WorldObject): The destination location (on success)
	"""
	if args.size() == 0:
		return {"success": false, "message": "Go where?"}

	if current_location == null:
		return {"success": false, "message": "You are nowhere."}

	var exit_name: String = args[0]

	# Verify location has location component with exits
	var location_comp = current_location.get_component("location")
	if location_comp == null:
		return {"success": false, "message": "This location has no exits."}

	var destination: WorldObject = location_comp.get_exit(exit_name)
	if destination == null:
		return {"success": false, "message": "There is no exit '%s' here." % exit_name}

	# Broadcast departure event to old location
	EventWeaver.broadcast_to_location(current_location, {
		"type": "movement",
		"actor": owner,
		"action": "leaves",
		"destination": destination,
		"message": "%s leaves to %s." % [owner.name, destination.name]
	})

	# Perform the actual move
	owner.move_to(destination)
	_update_location()

	# Broadcast arrival event to new location
	EventWeaver.broadcast_to_location(current_location, {
		"type": "movement",
		"actor": owner,
		"action": "arrives",
		"origin": current_location,
		"message": "%s arrives." % owner.name
	})

	# Automatically look at the new location
	return _cmd_look([])


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
		return {"success": false, "message": "Say what?"}

	var message: String = " ".join(args)

	# Broadcast speech event to location
	EventWeaver.broadcast_to_location(current_location, {
		"type": "speech",
		"actor": owner,
		"message": message,
		"text": "%s says, \"%s\"" % [owner.name, message]
	})

	return {
		"success": true,
		"message": "You say, \"%s\"" % message
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
		return {"success": false, "message": "Emote what?"}

	var action: String = " ".join(args)

	# Broadcast emote event to location
	EventWeaver.broadcast_to_location(current_location, {
		"type": "emote",
		"actor": owner,
		"action": action,
		"text": "%s %s" % [owner.name, action]
	})

	return {
		"success": true,
		"message": "%s %s" % [owner.name, action]
	}


func _cmd_examine(args: Array) -> Dictionary:
	"""EXAMINE command - Look closely at an object or actor.

	Searches for the named target in the current location and displays
	its detailed description. Broadcasts an examine action to observers.

	Args:
		args: Array with target name as first element

	Returns:
		Dictionary with:
		- success (bool): True if target was found and examined
		- message (String): The target's description
		- target (WorldObject): The examined object (on success)
	"""
	if args.size() == 0:
		return {"success": false, "message": "Examine what?"}

	var target_name: String = args[0]

	# Search for target in current location
	var target: WorldObject = WorldKeeper.find_object_by_name(target_name, current_location)

	if target == null:
		return {"success": false, "message": "You don't see '%s' here." % target_name}

	# Broadcast examine action to observers
	EventWeaver.broadcast_to_location(current_location, {
		"type": "action",
		"actor": owner,
		"target": target,
		"action": "examines",
		"message": "%s examines %s." % [owner.name, target.name]
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
		return {"success": false, "message": "Think what?"}

	var thought: String = " ".join(args)

	# Record to memory if available
	if owner.has_component("memory"):
		var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent
		memory_comp.add_memory(thought)

	# Broadcast observable behavior (but not the thought content)
	if current_location:
		EventWeaver.broadcast_to_location(current_location, {
			"type": "action",
			"actor": owner,
			"action": "pauses in thought",
			"message": "%s pauses in thought." % owner.name
		})

	return {
		"success": true,
		"message": "You think: %s" % thought
	}


func _cmd_dream(_args: Array) -> Dictionary:
	"""DREAM command - Review mixed memories for insights.

	Combines recent and random memories, sends them to an LLM for analysis,
	and stores the insights as a note. Useful for making connections between
	older and newer experiences, or breaking out of repetitive thought patterns.

	Args:
		_args: Unused, but kept for consistent command signature

	Returns:
		Dictionary with:
		- success (bool): True if dream analysis succeeded
		- message (String): The dream insights from the LLM

	Notes:
		Requires memory component and Shoggoth LLM interface.
		Creates a jumbled mix of ~5 recent + ~5 random older memories.
		LLM processes them for patterns, insights, and connections.
		Result is stored as a note for future reference.
		This is asynchronous - the command returns immediately and
		the dream insight appears as a follow-up message.
	"""
	if not owner.has_component("memory"):
		return {"success": false, "message": "You have no memory to dream about."}

	if not Shoggoth or not Shoggoth.ollama_client:
		return {"success": false, "message": "Dream analysis requires LLM connection."}

	var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent

	# Get mix of recent and random memories
	var recent: Array[Dictionary] = memory_comp.get_recent_memories(5)
	var random: Array[Dictionary] = memory_comp.get_random_memories(5)

	if recent.size() == 0 and random.size() == 0:
		return {"success": false, "message": "You have no memories to dream about."}

	# Combine and shuffle to create dream-like jumble
	var dream_memories: Array = []
	dream_memories.append_array(recent)
	dream_memories.append_array(random)
	dream_memories.shuffle()

	# Build dream prompt
	var prompt: String = "You are reviewing a jumbled set of memories. Look for patterns, insights, connections, or things you might have missed. These memories are a mix of recent experiences and older ones randomly surfaced.\n\n"
	prompt += "## Memory Fragments\n\n"

	for memory in dream_memories:
		var mem_dict: Dictionary = memory as Dictionary
		prompt += "- %s\n" % mem_dict.content

	prompt += "\n## Task\n\n"
	prompt += "Analyze these memory fragments. What patterns emerge? What connections can you make? "
	prompt += "What insights or hunches arise? What might be worth investigating further?\n\n"
	prompt += "Provide a brief analysis (2-4 sentences) focusing on actionable insights or interesting connections."

	# Broadcast observable behavior (entering dream state)
	if current_location:
		EventWeaver.broadcast_to_location(current_location, {
			"type": "action",
			"actor": owner,
			"action": "becomes still, eyes unfocused",
			"message": "%s becomes still, eyes unfocused, lost in thought." % owner.name
		})

	# Request LLM analysis asynchronously
	print("Dream: %s entering dream state..." % owner.name)
	Shoggoth.generate_async(prompt, "You are an insightful analyst helping someone process their memories.",
		func(response: String):
			_on_dream_complete(response)
	)

	return {
		"success": true,
		"message": "You drift into a dream state, memories swirling together..."
	}


func _on_dream_complete(insight: String) -> void:
	"""Handle dream analysis result from LLM.

	Called when the LLM finishes analyzing the jumbled memories.
	Stores the insight as a note and notifies the actor.

	Args:
		insight: The LLM's analysis of the memory fragments

	Notes:
		This is a callback from the async LLM request
	"""
	if not owner or not owner.has_component("memory"):
		return

	var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent

	# Store dream insight as a memory
	memory_comp.add_memory("Dream insight: %s" % insight)

	# If this is an AI agent, the insight will appear in their next memory review
	# If this is the player, emit a command result
	print("Dream: %s received insight: %s" % [owner.name, insight])

	# Emit as a command result for player visibility
	var result: Dictionary = {
		"success": true,
		"message": "Dream Insight:\n%s" % insight
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
		return {"success": false, "message": "Usage: note <title> -> <content>"}

	var full_args: String = " ".join(args)
	if not "->" in full_args:
		return {"success": false, "message": "Usage: note <title> -> <content> (arrow required)"}

	var parts: PackedStringArray = full_args.split("->", true, 1)
	var title: String = parts[0].strip_edges()
	var content: String = parts[1].strip_edges() if parts.size() > 1 else ""

	if not owner.has_component("memory"):
		return {"success": false, "message": "You have no memory to write notes."}

	var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent

	# Broadcast observable behavior (writing)
	if current_location:
		EventWeaver.broadcast_to_location(current_location, {
			"type": "action",
			"actor": owner,
			"action": "jots something down",
			"message": "%s jots something down." % owner.name
		})

	# Add note asynchronously
	memory_comp.add_note_async(title, content, last_reason, func():
		print("[Actor] %s completed note: %s" % [owner.name, title])
	)

	return {
		"success": true,
		"message": "Creating note: %s\n(Indexing in background...)" % title
	}


func _cmd_recall(args: Array) -> Dictionary:
	"""RECALL command - Search notes semantically.

	Args:
		args: Array of words forming search query

	Returns:
		Dictionary with success status (async results via signal)
	"""
	if args.size() == 0:
		return {"success": false, "message": "Usage: recall <query>"}

	var query: String = " ".join(args)

	if not owner.has_component("memory"):
		return {"success": false, "message": "You have no memory to recall from."}

	var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent

	# Broadcast observable behavior (searching memory)
	if current_location:
		EventWeaver.broadcast_to_location(current_location, {
			"type": "action",
			"actor": owner,
			"action": "searches their memory",
			"message": "%s furrows their brow, searching their memory." % owner.name
		})

	# Search notes asynchronously
	memory_comp.recall_notes_async(query, func(result: String):
		# Emit result as delayed command_executed
		var delayed_result: Dictionary = {
			"success": true,
			"message": result
		}
		command_executed.emit("recall", delayed_result, "")
	)

	return {
		"success": true,
		"message": "Searching memories for: %s\n(Processing...)" % query
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
	var rooms: Array = WorldKeeper.get_all_rooms()

	if rooms.size() == 0:
		return {"success": true, "message": "No rooms exist."}

	# Build formatted room list with occupants
	var text: String = "Rooms in the World\n\n"
	for room in rooms:
		var occupants: Array = []
		for obj in room.get_contents():
			if obj.has_component("actor"):
				occupants.append(obj.name)

		var occupant_text: String = " (%s)" % ", ".join(occupants) if occupants.size() > 0 else " (empty)"
		text += "• %s [%s]%s\n" % [room.name, room.id, occupant_text]

	return {"success": true, "message": text}


func _cmd_dig(args: Array) -> Dictionary:
	"""@DIG command - Create a new room (builder command).

	Creates a new WorldObject with a LocationComponent, ready to be
	connected via exits.

	Args:
		args: Array of words for the room name (joined with spaces)

	Returns:
		Dictionary with:
		- success (bool): True if room was created
		- message (String): Confirmation with room name and ID

	Notes:
		This is a builder/admin command for world construction
	"""
	if args.size() == 0:
		return {"success": false, "message": "Usage: @dig <room name>"}

	var room_name: String = " ".join(args)

	# Create new room WorldObject with LocationComponent
	var new_room: WorldObject = WorldKeeper.create_room(room_name, "A newly created room.")
	var loc_comp: LocationComponent = LocationComponent.new()
	new_room.add_component("location", loc_comp)

	# Broadcast creation event to current location
	if current_location:
		EventWeaver.broadcast_to_location(current_location, {
			"type": "building",
			"actor": owner,
			"action": "creates a room",
			"target": new_room,
			"message": "%s digs a new room: %s" % [owner.name, new_room.name]
		})

	return {
		"success": true,
		"message": "Created room: %s [%s]\nUse @exit to connect it to other rooms." % [new_room.name, new_room.id]
	}


func _cmd_exit(args: Array) -> Dictionary:
	"""@EXIT command - Create an exit between rooms (builder command).

	Creates a one-way exit from the current location to a target room.
	The destination can be specified by name or #ID.

	Args:
		args: Array containing: <exit_name> to <destination>
			  Example: ["north", "to", "Garden"] or ["south", "to", "#3"]

	Returns:
		Dictionary with:
		- success (bool): True if exit was created
		- message (String): Confirmation with exit and destination details

	Notes:
		This is a builder/admin command. Creates one-way exits only.
		Use twice to create bidirectional connections.
	"""
	if args.size() < 3:
		return {"success": false, "message": "Usage: @exit <exit name> to <destination room name or #ID>"}

	var exit_name: String = args[0]

	# Find "to" keyword in arguments
	var to_index: int = -1
	for i in range(args.size()):
		if args[i].to_lower() == "to":
			to_index = i
			break

	if to_index == -1:
		return {"success": false, "message": "Usage: @exit <exit name> to <destination>"}

	# Extract destination name from arguments after "to"
	var dest_parts: Array = args.slice(to_index + 1, args.size())
	var dest_name: String = " ".join(dest_parts)

	# Lookup destination room by ID or name
	var destination: WorldObject = null

	if dest_name.begins_with("#"):
		# ID-based lookup
		destination = WorldKeeper.get_object(dest_name)
	else:
		# Name-based lookup
		var all_rooms: Array = WorldKeeper.get_all_rooms()
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
		"message": "Created exit: %s → %s [%s]" % [exit_name, destination.name, destination.id]
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
		var all_rooms: Array = WorldKeeper.get_all_rooms()
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
		var all_rooms: Array = WorldKeeper.get_all_rooms()
		for room in all_rooms:
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

	if context.recent_memories.size() > 0:
		message += "[Recent Events - what %s has been doing and seeing]\n\n" % agent_name
		for memory in context.recent_memories:
			var mem_dict: Dictionary = memory as Dictionary
			# Display memory content as-is to preserve transcript format ("> command\nresult")
			message += "%s\n" % mem_dict.content
		message += "\n"
	else:
		message += "[No recent memories]\n\n"

	message += "[Full LLM Prompt]\n"
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
