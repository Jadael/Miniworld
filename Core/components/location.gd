## LocationComponent: Makes a WorldObject into a room/location
##
## Objects with this component are locations (rooms) that can:
## - Have exits to other locations
## - Contain other objects (characters, items, etc.)
## - Be navigated to/from
##
## This is the MOO equivalent of a room object. Every navigable space
## in Miniworld should have this component attached.
##
## Related: ActorComponent (for entities that move between locations)

extends ComponentBase
class_name LocationComponent


## Maps exit names to destination WorldObjects (direction -> location)
## Keys are normalized to lowercase for case-insensitive matching
var exits: Dictionary = {}


func _on_added(obj: WorldObject) -> void:
	"""Initialize location component and mark object as a room.

	Args:
		obj: The WorldObject becoming a location
	"""
	super._on_added(obj)
	obj.set_flag("is_room", true)


func _on_removed(obj: WorldObject) -> void:
	"""Clean up location component and remove room flag.

	Args:
		obj: The WorldObject being removed from
	"""
	super._on_removed(obj)
	obj.set_flag("is_room", false)


func add_exit(exit_name: String, destination: WorldObject) -> void:
	"""Add an exit from this location to another.

	Exit names are case-insensitive (stored as lowercase).

	Args:
		exit_name: Name of the exit (e.g., "north", "door", "garden")
		destination: The WorldObject to travel to via this exit

	Notes:
		Silently fails if destination is null (with warning)
	"""
	if destination == null:
		push_warning("LocationComponent: Cannot add exit to null destination")
		return

	exits[exit_name.to_lower()] = destination


func remove_exit(exit_name: String) -> void:
	"""Remove an exit from this location.

	Args:
		exit_name: Name of the exit to remove
	"""
	exits.erase(exit_name.to_lower())


func get_exit(exit_name: String) -> WorldObject:
	"""Get the destination for an exit.

	Args:
		exit_name: Name of the exit to look up

	Returns:
		Destination WorldObject, or null if exit doesn't exist
	"""
	return exits.get(exit_name.to_lower(), null)


func get_exits() -> Dictionary:
	"""Get all exits from this location.

	Returns:
		Dictionary mapping exit names (String) to destinations (WorldObject)
	"""
	return exits


func has_exit(exit_name: String) -> bool:
	"""Check if an exit exists.

	Args:
		exit_name: Name of the exit to check

	Returns:
		True if the exit exists, false otherwise
	"""
	return exit_name.to_lower() in exits


func enhance_description(base_description: String) -> String:
	"""Add exit information to the location's description.

	Args:
		base_description: The location's base description

	Returns:
		Enhanced description with exit list appended
	"""
	var desc = base_description

	# Add exit information
	if exits.size() > 0:
		desc += "\n\nObvious exits: "
		var exit_names: Array[String] = []
		for exit_name in exits.keys():
			exit_names.append(exit_name)
		desc += ", ".join(exit_names)
	else:
		desc += "\n\nThere are no obvious exits."

	return desc


func get_contents_description() -> String:
	"""Generate a description of objects in this location.

	Returns:
		Formatted text listing all objects in the location
	"""
	var contents = owner.get_contents()

	if contents.size() == 0:
		return "The area is empty."

	var desc = "You see:\n"
	for obj in contents:
		if obj != owner:  # Don't list the room itself
			desc += "  - %s\n" % obj.name

	return desc
