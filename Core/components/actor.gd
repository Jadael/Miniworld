## Actor Component: Makes a WorldObject able to perform actions
##
## Objects with this component can:
## - Execute commands (look, go, say, emote, etc.)
## - Observe events in their location
## - Interact with other objects
##
## Both players and AI agents have this component.
##
## Dependencies:
## - ComponentBase: Base class for all components
## - WorldKeeper: Object registry and lifecycle manager
## - EventWeaver: Event propagation and observation system
## - LocationComponent: Required for location-based commands
##
## Notes:
## - All commands return a Dictionary with at least "success" and "message" keys
## - Commands prefixed with @ are builder/admin commands
## - Movement commands automatically trigger look at destination

extends ComponentBase
class_name ActorComponent


## Emitted when this actor executes a command
signal command_executed(command: String, result: Dictionary)

## Emitted when this actor observes an event in their location
signal event_observed(event: Dictionary)


## The last command this actor executed
var last_command: String = ""

## The result Dictionary from the last command execution
var last_result: Dictionary = {}

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


func execute_command(command: String, args: Array = []) -> Dictionary:
	"""Execute a command as this actor and return the result.

	Matches the command string against known commands and dispatches
	to the appropriate handler function. Updates location cache before
	execution and emits command_executed signal after completion.

	Args:
		command: The command verb to execute (case-insensitive)
		args: Array of string arguments for the command

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
		_:
			result = {"success": false, "message": "Unknown command: %s" % command}

	# Cache command and result for inspection
	last_command = command
	last_result = result
	command_executed.emit(command, result)

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
	var text: String = "[color=cyan][b]Who's Online[/b][/color]\n\n"
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

	return {"success": true, "message": "You are in [color=yellow]%s[/color] (%s)" % [current_location.name, current_location.id]}


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
	var text: String = "[color=cyan][b]Rooms in the World[/b][/color]\n\n"
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

	return {
		"success": true,
		"message": "[color=green]Created room:[/color] %s [%s]\nUse @exit to connect it to other rooms." % [new_room.name, new_room.id]
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

	return {
		"success": true,
		"message": "[color=green]Created exit:[/color] %s → %s [%s]" % [exit_name, destination.name, destination.id]
	}


func _cmd_teleport(args: Array) -> Dictionary:
	"""@TELEPORT command - Instantly jump to any room (builder command).

	Moves the actor directly to the specified room without requiring
	an exit. Broadcasts dramatic teleport events to both locations.

	Args:
		args: Array containing room name or #ID

	Returns:
		Dictionary with:
		- success (bool): True if teleport succeeded
		- message (String): Result of automatic look at destination
		- location (WorldObject): The destination location

	Notes:
		This is a builder/admin command that bypasses normal movement.
		Automatically performs a look command at the destination.
	"""
	if args.size() == 0:
		return {"success": false, "message": "Usage: @teleport <room name or #ID>"}

	var dest_name: String = " ".join(args)
	var destination: WorldObject = null

	# Lookup destination room by ID or name
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
