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
signal object_created(obj: WorldObject)
signal object_destroyed(obj_id: String)
signal world_loaded()
signal world_saved()

## Object registry
var objects: Dictionary = {}  # id -> WorldObject
var next_object_number: int = 1000  # For generating sequential IDs

## Special object references
var nexus: WorldObject = null  # The primordial container (#0)
var root_room: WorldObject = null  # Starting location (#1)

func _ready() -> void:
	_initialize_world()

func _initialize_world() -> void:
	"""Create the foundational objects"""
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
	"""Create a new WorldObject and register it"""
	var obj_id = _generate_next_id()
	var obj = WorldObject.new(obj_id, display_name)
	obj.name = display_name

	objects[obj_id] = obj
	object_created.emit(obj)

	return obj

func _generate_next_id() -> String:
	"""Generate the next sequential object ID"""
	var obj_id = "#" + str(next_object_number)
	next_object_number += 1
	return obj_id

## Object destruction
func destroy_object(obj_id: String) -> bool:
	"""Destroy an object and remove it from the world"""
	if obj_id not in objects:
		push_warning("WorldKeeper: Cannot destroy non-existent object %s" % obj_id)
		return false

	var obj = objects[obj_id]

	# Move all contents to the nexus
	for child in obj.get_contents():
		child.move_to(nexus)

	# Remove from parent
	if obj.parent != null:
		obj.parent.contents.erase(obj)

	# Remove from registry
	objects.erase(obj_id)
	object_destroyed.emit(obj_id)

	return true

## Object lookup
func get_object(obj_id: String) -> WorldObject:
	"""Get an object by its ID"""
	return objects.get(obj_id, null)

func find_object_by_name(search_name: String, location: WorldObject = null) -> WorldObject:
	"""Find an object by name, optionally restricted to a location"""
	# If location specified, search there first
	if location != null:
		for obj in location.get_contents():
			if obj.matches_name(search_name):
				return obj

	# Global search
	for obj_id in objects:
		var obj = objects[obj_id]
		if obj.matches_name(search_name):
			return obj

	return null

func get_objects_in_location(location: WorldObject) -> Array[WorldObject]:
	"""Get all objects in a specific location"""
	if location == null:
		return []
	return location.get_contents()

func get_all_objects() -> Array[WorldObject]:
	"""Get all objects in the world"""
	var all_objs: Array[WorldObject] = []
	for obj_id in objects:
		all_objs.append(objects[obj_id])
	return all_objs

func get_objects_with_flag(flag_name: String) -> Array[WorldObject]:
	"""Get all objects with a specific flag set"""
	var result: Array[WorldObject] = []
	for obj_id in objects:
		var obj = objects[obj_id]
		if obj.has_flag(flag_name):
			result.append(obj)
	return result

func get_objects_with_component(component_name: String) -> Array[WorldObject]:
	"""Get all objects with a specific component"""
	var result: Array[WorldObject] = []
	for obj_id in objects:
		var obj = objects[obj_id]
		if obj.has_component(component_name):
			result.append(obj)
	return result

## Room/Location helpers
func get_all_rooms() -> Array[WorldObject]:
	"""Get all objects marked as rooms"""
	return get_objects_with_flag("is_room")

func create_room(room_name: String, room_description: String = "") -> WorldObject:
	"""Convenience method to create a room"""
	var room = create_object("room", room_name)
	room.description = room_description if room_description != "" else "You see nothing special about this place."
	room.set_flag("is_room", true)
	room.move_to(nexus)  # Rooms exist in the nexus
	return room

## Persistence (simplified for MVP - can expand later)
func save_world(filepath: String = "user://world_state.json") -> bool:
	"""Save the world state to a file"""
	var save_data = {
		"next_object_number": next_object_number,
		"objects": []
	}

	# Serialize all objects
	for obj_id in objects:
		var obj = objects[obj_id]
		var obj_data = _serialize_object(obj)
		save_data["objects"].append(obj_data)

	# Write to file
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		push_error("WorldKeeper: Failed to open save file: %s" % filepath)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	world_saved.emit()
	print("WorldKeeper: World saved to %s" % filepath)
	return true

func load_world(filepath: String = "user://world_state.json") -> bool:
	"""Load the world state from a file"""
	if not FileAccess.file_exists(filepath):
		push_warning("WorldKeeper: Save file does not exist: %s" % filepath)
		return false

	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("WorldKeeper: Failed to open save file: %s" % filepath)
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("WorldKeeper: Failed to parse save file: %s" % filepath)
		return false

	var save_data = json.data

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
	"""Convert a WorldObject to a serializable dictionary"""
	return {
		"id": obj.id,
		"name": obj.name,
		"description": obj.description,
		"aliases": obj.aliases,
		"properties": obj.properties,
		"flags": obj.flags,
		"parent_id": obj.parent.id if obj.parent else "", #FIXME: Values of the ternary operator are not mutually compatible
		# Components and verbs will need custom serialization (TODO)
	}

func _deserialize_object(obj_data: Dictionary) -> WorldObject:
	"""Recreate a WorldObject from serialized data"""
	var obj = WorldObject.new(obj_data["id"], obj_data["name"])
	obj.description = obj_data.get("description", "You see nothing special.")
	obj.aliases = obj_data.get("aliases", [])
	obj.properties = obj_data.get("properties", {})
	obj.flags = obj_data.get("flags", {})

	objects[obj.id] = obj

	# Parent relationships will be restored in a second pass (TODO)

	return obj

## Debug/utility methods
func print_world_tree(start_obj: WorldObject = null, indent: int = 0) -> void:
	"""Print the object hierarchy for debugging"""
	if start_obj == null:
		start_obj = nexus

	var indent_str = "  ".repeat(indent)
	print("%s%s" % [indent_str, start_obj.get_debug_string()])

	for child in start_obj.get_contents():
		print_world_tree(child, indent + 1)

func get_stats() -> Dictionary:
	"""Get statistics about the world"""
	return {
		"total_objects": objects.size(),
		"total_rooms": get_all_rooms().size(),
		"next_id": next_object_number
	}
