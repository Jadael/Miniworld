## Actor Component: Makes a WorldObject able to perform actions
##
## Objects with this component can:
## - Execute commands (look, go, say, emote, etc.)
## - Observe events in their location
## - Interact with other objects
##
## Both players and AI agents have this component.

extends ComponentBase
class_name ActorComponent

## Signals
signal command_executed(command: String, result: Dictionary)
signal event_observed(event: Dictionary)

## Actor state
var last_command: String = ""
var last_result: Dictionary = {}
var current_location: WorldObject = null

func _on_added(obj: WorldObject) -> void:
	super._on_added(obj)
	obj.set_flag("is_actor", true)
	_update_location()

func _on_removed(obj: WorldObject) -> void:
	super._on_removed(obj)
	obj.set_flag("is_actor", false)

## Update cached location reference
func _update_location() -> void:
	current_location = owner.get_location()

## Execute a command as this actor
func execute_command(command: String, args: Array = []) -> Dictionary:
	"""Execute a command and return the result"""
	_update_location()

	var result = {}

	# Try to find and execute the verb
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

	last_command = command
	last_result = result
	command_executed.emit(command, result)

	return result

## LOOK command
func _cmd_look(_args: Array) -> Dictionary:
	if current_location == null:
		return {"success": false, "message": "You are nowhere."}

	var desc = current_location.get_description()

	# Add contents
	var location_comp = current_location.get_component("location")
	if location_comp != null:
		desc += "\n\n" + location_comp.get_contents_description()

	# Notify observers
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

## GO command
func _cmd_go(args: Array) -> Dictionary:
	if args.size() == 0:
		return {"success": false, "message": "Go where?"}

	if current_location == null:
		return {"success": false, "message": "You are nowhere."}

	var exit_name = args[0]

	var location_comp = current_location.get_component("location")
	if location_comp == null:
		return {"success": false, "message": "This location has no exits."}

	var destination = location_comp.get_exit(exit_name)
	if destination == null:
		return {"success": false, "message": "There is no exit '%s' here." % exit_name}

	# Announce departure
	EventWeaver.broadcast_to_location(current_location, {
		"type": "movement",
		"actor": owner,
		"action": "leaves",
		"destination": destination,
		"message": "%s leaves to %s." % [owner.name, destination.name]
	})

	# Move
	owner.move_to(destination)
	_update_location()

	# Announce arrival
	EventWeaver.broadcast_to_location(current_location, {
		"type": "movement",
		"actor": owner,
		"action": "arrives",
		"origin": current_location,
		"message": "%s arrives." % owner.name
	})

	# Auto-look at new location
	return _cmd_look([])

## SAY command
func _cmd_say(args: Array) -> Dictionary:
	if args.size() == 0:
		return {"success": false, "message": "Say what?"}

	var message = " ".join(args)

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

## EMOTE command
func _cmd_emote(args: Array) -> Dictionary:
	if args.size() == 0:
		return {"success": false, "message": "Emote what?"}

	var action = " ".join(args)

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

## EXAMINE command
func _cmd_examine(args: Array) -> Dictionary:
	if args.size() == 0:
		return {"success": false, "message": "Examine what?"}

	var target_name = args[0]

	# Look for target in current location
	var target = WorldKeeper.find_object_by_name(target_name, current_location)

	if target == null:
		return {"success": false, "message": "You don't see '%s' here." % target_name}

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

## Observe an event happening in this actor's location
func observe_event(event: Dictionary) -> void:
	"""Called when something happens in the actor's location"""
	# Don't observe our own actions (already got the command result)
	if event.get("actor") == owner:
		return

	event_observed.emit(event)

## WHO command - List all actors in the world
func _cmd_who(_args: Array) -> Dictionary:
	var actors: Array[WorldObject] = []

	# Find all objects with actor component
	for obj_id in WorldKeeper.objects.keys():
		var obj = WorldKeeper.objects[obj_id]
		if obj.has_component("actor"):
			actors.append(obj)

	if actors.size() == 0:
		return {"success": true, "message": "No one is here."}

	var text = "[color=cyan][b]Who's Online[/b][/color]\n\n"
	for actor in actors:
		var location = actor.get_location()
		var loc_name = location.name if location else "The Void"
		var is_ai = " [AI]" if actor.has_component("thinker") else ""
		text += "• %s%s - in %s\n" % [actor.name, is_ai, loc_name]

	return {"success": true, "message": text}

## WHERE command - Show current location
func _cmd_where(_args: Array) -> Dictionary:
	if current_location == null:
		return {"success": true, "message": "You are nowhere."}

	return {"success": true, "message": "You are in [color=yellow]%s[/color] (%s)" % [current_location.name, current_location.id]}

## ROOMS command - List all rooms
func _cmd_rooms(_args: Array) -> Dictionary:
	var rooms = WorldKeeper.get_all_rooms()

	if rooms.size() == 0:
		return {"success": true, "message": "No rooms exist."}

	var text = "[color=cyan][b]Rooms in the World[/b][/color]\n\n"
	for room in rooms:
		var occupants = []
		for obj in room.get_contents():
			if obj.has_component("actor"):
				occupants.append(obj.name)

		var occupant_text = " (%s)" % ", ".join(occupants) if occupants.size() > 0 else " (empty)"
		text += "• %s [%s]%s\n" % [room.name, room.id, occupant_text]

	return {"success": true, "message": text}

## @DIG command - Create a new room
func _cmd_dig(args: Array) -> Dictionary:
	if args.size() == 0:
		return {"success": false, "message": "Usage: @dig <room name>"}

	var room_name = " ".join(args)

	# Create the room
	var new_room = WorldKeeper.create_room(room_name, "A newly created room.")
	var loc_comp = LocationComponent.new()
	new_room.add_component("location", loc_comp)

	return {
		"success": true,
		"message": "[color=green]Created room:[/color] %s [%s]\nUse @exit to connect it to other rooms." % [new_room.name, new_room.id]
	}

## @EXIT command - Create an exit between rooms
func _cmd_exit(args: Array) -> Dictionary:
	if args.size() < 3:
		return {"success": false, "message": "Usage: @exit <exit name> to <destination room name or #ID>"}

	# Parse: @exit north to Garden  OR  @exit north to #3
	var exit_name = args[0]

	# Find "to" keyword
	var to_index = -1
	for i in range(args.size()):
		if args[i].to_lower() == "to":
			to_index = i
			break

	if to_index == -1:
		return {"success": false, "message": "Usage: @exit <exit name> to <destination>"}

	# Destination is everything after "to"
	var dest_parts = args.slice(to_index + 1, args.size())
	var dest_name = " ".join(dest_parts)

	# Find destination room
	var destination: WorldObject = null

	if dest_name.begins_with("#"):
		# ID lookup
		destination = WorldKeeper.get_object(dest_name)
	else:
		# Name lookup
		var all_rooms = WorldKeeper.get_all_rooms()
		for room in all_rooms:
			if room.name.to_lower() == dest_name.to_lower():
				destination = room
				break

	if destination == null:
		return {"success": false, "message": "Cannot find room: %s" % dest_name}

	if not destination.has_component("location"):
		return {"success": false, "message": "%s is not a room." % destination.name}

	# Add exit from current location
	if current_location == null:
		return {"success": false, "message": "You are nowhere."}

	var loc_comp = current_location.get_component("location")
	if loc_comp == null:
		return {"success": false, "message": "This location cannot have exits."}

	loc_comp.add_exit(exit_name, destination)

	return {
		"success": true,
		"message": "[color=green]Created exit:[/color] %s → %s [%s]" % [exit_name, destination.name, destination.id]
	}

## @TELEPORT command - Jump to any room
func _cmd_teleport(args: Array) -> Dictionary:
	if args.size() == 0:
		return {"success": false, "message": "Usage: @teleport <room name or #ID>"}

	var dest_name = " ".join(args)
	var destination: WorldObject = null

	# ID lookup
	if dest_name.begins_with("#"):
		destination = WorldKeeper.get_object(dest_name)
	else:
		# Name lookup
		var all_rooms = WorldKeeper.get_all_rooms()
		for room in all_rooms:
			if room.name.to_lower() == dest_name.to_lower():
				destination = room
				break

	if destination == null:
		return {"success": false, "message": "Cannot find room: %s" % dest_name}

	if not destination.has_component("location"):
		return {"success": false, "message": "%s is not a room." % destination.name}

	# Announce departure from old location
	if current_location:
		EventWeaver.broadcast_to_location(current_location, {
			"type": "teleport",
			"actor": owner,
			"action": "teleports away",
			"message": "%s vanishes in a swirl of light." % owner.name
		})

	# Move
	owner.move_to(destination)
	_update_location()

	# Announce arrival
	EventWeaver.broadcast_to_location(current_location, {
		"type": "teleport",
		"actor": owner,
		"action": "teleports in",
		"message": "%s appears in a swirl of light." % owner.name
	})

	# Auto-look
	return _cmd_look([])
