## Location Component: Makes a WorldObject into a room/location
##
## Objects with this component are locations (rooms) that can:
## - Have exits to other locations
## - Contain other objects (characters, items, etc.)
## - Be navigated to/from
##
## This is the MOO equivalent of a room object.

extends ComponentBase
class_name LocationComponent

## Exits: direction/name -> destination WorldObject
var exits: Dictionary = {}  # String -> WorldObject

func _on_added(obj: WorldObject) -> void:
	super._on_added(obj)
	obj.set_flag("is_room", true)

func _on_removed(obj: WorldObject) -> void:
	super._on_removed(obj)
	obj.set_flag("is_room", false)

## Add an exit to another location
func add_exit(exit_name: String, destination: WorldObject) -> void:
	if destination == null:
		push_warning("LocationComponent: Cannot add exit to null destination")
		return

	exits[exit_name.to_lower()] = destination

## Remove an exit
func remove_exit(exit_name: String) -> void:
	exits.erase(exit_name.to_lower())

## Get the destination for an exit
func get_exit(exit_name: String) -> WorldObject:
	return exits.get(exit_name.to_lower(), null)

## Get all exits
func get_exits() -> Dictionary:
	return exits

## Check if an exit exists
func has_exit(exit_name: String) -> bool:
	return exit_name.to_lower() in exits

## Enhance description with exit information
func enhance_description(base_description: String) -> String:
	var desc = base_description

	# Add exits
	if exits.size() > 0:
		desc += "\n\nObvious exits: "
		var exit_names: Array[String] = []
		for exit_name in exits.keys():
			exit_names.append(exit_name)
		desc += ", ".join(exit_names)
	else:
		desc += "\n\nThere are no obvious exits."

	return desc

## Get a list of all objects in this location (excluding the location itself)
func get_contents_description() -> String:
	"""Generate a description of what's in this location"""
	var contents = owner.get_contents()

	if contents.size() == 0:
		return "The area is empty."

	var desc = "You see:\n"
	for obj in contents:
		if obj != owner:  # Don't list the room itself
			desc += "  - %s\n" % obj.name

	return desc
