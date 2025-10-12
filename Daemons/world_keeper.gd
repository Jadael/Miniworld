## WorldKeeper: Daemon managing all WorldObjects
##
## This singleton maintains the registry of all objects in the world,
## handles object creation/destruction, and provides lookup services.
##
## In MOO terms, this is similar to the database/object manager.
##
## Responsibilities:
## - Object registry (lookup by ID, name, etc.)
## - Object lifecycle (creation, destruction)
## - Global object queries (find by type, location, etc.)
## - Persistence (save/load world state)

extends Node

## Signals

## Emitted when a new WorldObject is created and registered
signal object_created(obj: WorldObject)

## Emitted when a WorldObject is destroyed and removed from the registry
signal object_destroyed(obj_id: String)

## Emitted after the world state is successfully loaded from disk
signal world_loaded()

## Emitted after the world state is successfully saved to disk
signal world_saved()


## Object registry: Maps object ID (String) to WorldObject instance
var objects: Dictionary = {}

## Counter for generating sequential object IDs, starting from #1000
var next_object_number: int = 1000

## Special object references

## The primordial container (#0) - holds all top-level objects and rooms
var nexus: WorldObject = null

## The default starting location (#1) - where new actors spawn
var root_room: WorldObject = null

func _ready() -> void:
	_initialize_world()

func _initialize_world() -> void:
	"""Create the foundational objects that form the basis of the world.

	Creates two special objects:
	- #0 (The Nexus): Primordial container holding all top-level objects
	- #1 (The Genesis Chamber): Default starting room for new actors

	Notes:
		Called automatically during _ready()
	"""
	# Create #0: The Nexus (primordial container)
	nexus = create_object("nexus", "the nexus")
	nexus.id = "#0"
	nexus.description = "An endless expanse of possibility, the container of all containers."
	nexus.set_flag("is_nexus", true)

	# Create #1: Root Room (default starting location)
	root_room = create_object("room", "The Genesis Chamber")
	root_room.id = "#1"
	root_room.description = "A featureless white room that seems to exist outside of space and time. This is where all things begin."
	root_room.set_flag("is_room", true)
	root_room.move_to(nexus)

	print("WorldKeeper: Initialized with nexus (#0) and root room (#1)")

## Object creation

func create_object(_obj_name: String = "object", display_name: String = "object") -> WorldObject:
	"""Create a new WorldObject and register it in the world.

	Args:
		_obj_name: Legacy parameter (unused, kept for compatibility)
		display_name: The human-readable name for the object

	Returns:
		The newly created WorldObject with auto-generated ID

	Notes:
		- Automatically assigns a sequential ID starting from #1000
		- Emits object_created signal after registration
		- The object is registered but not placed in any location (parent is null)
	"""
	var obj_id: String = _generate_next_id()
	var obj: WorldObject = WorldObject.new(obj_id, display_name)
	obj.name = display_name

	objects[obj_id] = obj
	object_created.emit(obj)

	return obj


func _generate_next_id() -> String:
	"""Generate the next sequential object ID.

	Returns:
		A string ID in the format "#NNNN" where NNNN is sequential

	Notes:
		Increments next_object_number counter for each call
	"""
	var obj_id: String = "#" + str(next_object_number)
	next_object_number += 1
	return obj_id

## Object destruction

func destroy_object(obj_id: String) -> bool:
	"""Destroy an object and remove it from the world.

	Handles cleanup of object relationships:
	- Moves all contents to the nexus (prevents orphaning)
	- Removes object from its parent's contents
	- Removes from the object registry
	- Emits object_destroyed signal

	Args:
		obj_id: The ID of the object to destroy

	Returns:
		true if object was destroyed, false if object doesn't exist

	Notes:
		- Cannot destroy objects that don't exist (logs warning)
		- All child objects are safely relocated to nexus before destruction
	"""
	if obj_id not in objects:
		push_warning("WorldKeeper: Cannot destroy non-existent object %s" % obj_id)
		return false

	var obj: WorldObject = objects[obj_id]

	# Move all contents to the nexus to prevent orphaning
	for child in obj.get_contents():
		child.move_to(nexus)

	# Remove from parent's contents array
	if obj.parent != null:
		obj.parent.contents.erase(obj)

	# Remove from registry
	objects.erase(obj_id)
	object_destroyed.emit(obj_id)

	return true

## Object lookup

func get_object(obj_id: String) -> WorldObject:
	"""Get an object by its ID.

	Args:
		obj_id: The unique identifier of the object (e.g., "#1000")

	Returns:
		The WorldObject if found, null otherwise
	"""
	return objects.get(obj_id, null)


func find_object_by_name(search_name: String, location: WorldObject = null) -> WorldObject:
	"""Find an object by name, optionally restricted to a location.

	Performs a two-stage search:
	1. If location is provided, searches within that location first
	2. Falls back to global search across all objects

	Args:
		search_name: The name or alias to search for
		location: Optional location to restrict the search to

	Returns:
		The first WorldObject matching the name, or null if not found

	Notes:
		Uses WorldObject.matches_name() which checks both name and aliases
	"""
	# If location specified, search there first
	if location != null:
		for obj in location.get_contents():
			if obj.matches_name(search_name):
				return obj

	# Global search if not found locally
	for obj_id in objects:
		var obj: WorldObject = objects[obj_id]
		if obj.matches_name(search_name):
			return obj

	return null


func get_objects_in_location(location: WorldObject) -> Array[WorldObject]:
	"""Get all objects in a specific location.

	Args:
		location: The container object to get contents from

	Returns:
		Array of WorldObjects in the location, empty array if location is null
	"""
	if location == null:
		return []
	return location.get_contents()


func get_all_objects() -> Array[WorldObject]:
	"""Get all objects in the world.

	Returns:
		Array containing every registered WorldObject

	Notes:
		This can be expensive for large worlds - prefer more specific queries
	"""
	var all_objs: Array[WorldObject] = []
	for obj_id in objects:
		all_objs.append(objects[obj_id])
	return all_objs


func get_objects_with_flag(flag_name: String) -> Array[WorldObject]:
	"""Get all objects with a specific flag set.

	Args:
		flag_name: The name of the flag to search for

	Returns:
		Array of WorldObjects that have the specified flag set to true

	Notes:
		Common flags include "is_room", "is_nexus", "is_actor"
	"""
	var result: Array[WorldObject] = []
	for obj_id in objects:
		var obj: WorldObject = objects[obj_id]
		if obj.has_flag(flag_name):
			result.append(obj)
	return result


func get_objects_with_component(component_name: String) -> Array[WorldObject]:
	"""Get all objects with a specific component attached.

	Args:
		component_name: The name of the component to search for

	Returns:
		Array of WorldObjects that have the specified component

	Notes:
		Common components include "actor", "thinker", "memory"
	"""
	var result: Array[WorldObject] = []
	for obj_id in objects:
		var obj: WorldObject = objects[obj_id]
		if obj.has_component(component_name):
			result.append(obj)
	return result

## Room/Location helpers

func get_all_rooms() -> Array[WorldObject]:
	"""Get all objects marked as rooms.

	Returns:
		Array of WorldObjects with the "is_room" flag set

	Notes:
		This is a convenience wrapper around get_objects_with_flag("is_room")
	"""
	return get_objects_with_flag("is_room")


func create_room(room_name: String, room_description: String = "") -> WorldObject:
	"""Convenience method to create a room with proper defaults.

	Args:
		room_name: The name of the room
		room_description: Optional description, defaults to generic text

	Returns:
		The newly created room WorldObject

	Notes:
		- Automatically sets the "is_room" flag
		- Places the room in the nexus (standard for all rooms)
		- Provides default description if none specified
	"""
	var room: WorldObject = create_object("room", room_name)
	room.description = room_description if room_description != "" else "You see nothing special about this place."
	room.set_flag("is_room", true)
	room.move_to(nexus)  # Rooms exist in the nexus
	return room

## Persistence (simplified for MVP - can expand later)

func save_world(filepath: String = "user://world_state.json") -> bool:
	"""Save the world state to a JSON file.

	Serializes all objects and their properties to disk for later restoration.

	Args:
		filepath: The path to save to, defaults to "user://world_state.json"

	Returns:
		true if save succeeded, false on error

	Notes:
		- Uses JSON format for human-readable saves
		- Saves object counter to maintain ID continuity
		- Component and verb serialization is TODO
		- Emits world_saved signal on success
	"""
	var save_data: Dictionary = {
		"next_object_number": next_object_number,
		"objects": []
	}

	# Serialize all objects
	for obj_id in objects:
		var obj: WorldObject = objects[obj_id]
		var obj_data: Dictionary = _serialize_object(obj)
		save_data["objects"].append(obj_data)

	# Write to file
	var file: FileAccess = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		push_error("WorldKeeper: Failed to open save file: %s" % filepath)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	world_saved.emit()
	print("WorldKeeper: World saved to %s" % filepath)
	return true


func load_world(filepath: String = "user://world_state.json") -> bool:
	"""Load the world state from a JSON file.

	Deserializes all objects and restores the world to a saved state.

	Args:
		filepath: The path to load from, defaults to "user://world_state.json"

	Returns:
		true if load succeeded, false on error

	Notes:
		- Clears all existing objects before loading
		- Restores object counter to maintain ID continuity
		- Parent relationships need two-pass restoration (TODO)
		- Emits world_loaded signal on success
	"""
	if not FileAccess.file_exists(filepath):
		push_warning("WorldKeeper: Save file does not exist: %s" % filepath)
		return false

	var file: FileAccess = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("WorldKeeper: Failed to open save file: %s" % filepath)
		return false

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)

	if parse_result != OK:
		push_error("WorldKeeper: Failed to parse save file: %s" % filepath)
		return false

	var save_data: Dictionary = json.data

	# Clear existing world
	objects.clear()

	# Restore object counter
	next_object_number = save_data.get("next_object_number", 1000)

	# Deserialize all objects
	for obj_data in save_data.get("objects", []):
		_deserialize_object(obj_data)

	# Restore special references
	nexus = get_object("#0")
	root_room = get_object("#1")

	world_loaded.emit()
	print("WorldKeeper: World loaded from %s" % filepath)
	return true

func _serialize_object(obj: WorldObject) -> Dictionary:
	"""Convert a WorldObject to a serializable dictionary.

	Args:
		obj: The WorldObject to serialize

	Returns:
		Dictionary containing the object's serializable state

	Notes:
		Components and verbs will need custom serialization in the future (TODO)
	"""
	# Get parent ID safely, ensuring type compatibility
	var parent_id: String = ""
	if obj.parent != null:
		parent_id = obj.parent.id

	return {
		"id": obj.id,
		"name": obj.name,
		"description": obj.description,
		"aliases": obj.aliases,
		"properties": obj.properties,
		"flags": obj.flags,
		"parent_id": parent_id,
		# Components and verbs will need custom serialization (TODO)
	}

func _deserialize_object(obj_data: Dictionary) -> WorldObject:
	"""Recreate a WorldObject from serialized data.

	Args:
		obj_data: Dictionary containing serialized object state

	Returns:
		The reconstructed WorldObject

	Notes:
		- Parent relationships will be restored in a second pass (TODO)
		- Components and verbs need custom deserialization (TODO)
	"""
	var obj: WorldObject = WorldObject.new(obj_data["id"], obj_data["name"])
	obj.description = obj_data.get("description", "You see nothing special.")
	obj.aliases = obj_data.get("aliases", [])
	obj.properties = obj_data.get("properties", {})
	obj.flags = obj_data.get("flags", {})

	objects[obj.id] = obj

	# Parent relationships will be restored in a second pass (TODO)

	return obj

## Debug/utility methods

func print_world_tree(start_obj: WorldObject = null, indent: int = 0) -> void:
	"""Print the object hierarchy for debugging.

	Recursively prints the containment tree starting from a given object.

	Args:
		start_obj: Object to start from, defaults to nexus if null
		indent: Current indentation level (used for recursion)

	Notes:
		Useful for visualizing the world structure and object relationships
	"""
	if start_obj == null:
		start_obj = nexus

	var indent_str: String = "  ".repeat(indent)
	print("%s%s" % [indent_str, start_obj.get_debug_string()])

	# Recursively print all children
	for child in start_obj.get_contents():
		print_world_tree(child, indent + 1)


func get_stats() -> Dictionary:
	"""Get statistics about the world.

	Returns:
		Dictionary with keys:
		- total_objects: Total number of registered objects
		- total_rooms: Number of objects marked as rooms
		- next_id: The next object ID that will be assigned

	Notes:
		Useful for monitoring world state and debugging
	"""
	return {
		"total_objects": objects.size(),
		"total_rooms": get_all_rooms().size(),
		"next_id": next_object_number
	}
