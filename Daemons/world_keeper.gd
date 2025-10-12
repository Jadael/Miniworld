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

## Markdown Vault Persistence

func save_world_to_vault() -> bool:
	"""Save entire world to markdown vault.

	Creates/updates:
	- vault/world/locations/<name>.md for each room
	- vault/world/objects/characters/<name>.md for each character
	- vault/world/world_state.md for snapshot

	Returns:
		true if all saves succeeded, false if any failed

	Notes:
		Uses WorldObject.to_markdown() for serialization
		Skips nexus and root_room (foundation objects)
	"""
	var success: bool = true

	# Save all rooms (except nexus and root_room which are foundation)
	for room in get_all_rooms():
		if room == nexus or room == root_room:
			continue

		var filename: String = MarkdownVault.sanitize_filename(room.name) + ".md"
		var path: String = MarkdownVault.LOCATIONS_PATH + "/" + filename
		var content: String = room.to_markdown()

		if not MarkdownVault.write_file(path, content):
			push_error("WorldKeeper: Failed to save room %s to vault" % room.name)
			success = false

	# Save all characters (objects with actor component)
	var actors: Array[WorldObject] = get_objects_with_component("actor")
	print("WorldKeeper: Found %d actors to save" % actors.size())

	for obj in actors:
		print("WorldKeeper: Saving actor: %s (ID: %s)" % [obj.name, obj.id])
		var filename: String = MarkdownVault.sanitize_filename(obj.name) + ".md"
		var path: String = MarkdownVault.OBJECTS_PATH + "/characters/" + filename
		var content: String = obj.to_markdown()

		print("WorldKeeper: Writing to path: %s" % path)
		print("WorldKeeper: Content length: %d" % content.length())

		if not MarkdownVault.write_file(path, content):
			push_error("WorldKeeper: Failed to save character %s to vault" % obj.name)
			success = false
		else:
			print("WorldKeeper: Successfully saved %s" % obj.name)

		# Save memories if character has memory component
		if obj.has_component("memory"):
			var memory_comp: MemoryComponent = obj.get_component("memory") as MemoryComponent
			memory_comp.save_all_memories_to_vault(obj.name)

	# Create world state snapshot
	_save_world_snapshot()

	if success:
		world_saved.emit()
		print("WorldKeeper: World saved to vault at %s" % MarkdownVault.get_vault_path())

	return success


func load_world_from_vault() -> bool:
	"""Load world from markdown vault.

	Reads all markdown files and reconstructs the world.
	Three-pass loading:
	1. Create all location objects
	2. Create all character objects
	3. Restore relationships (parents, locations)

	Returns:
		true if load succeeded, false on error

	Notes:
		Preserves nexus and root_room (foundation objects)
		Components must be restored based on markdown metadata
	"""
	print("WorldKeeper: Loading world from vault...")

	# Clear existing world (except foundation objects)
	_clear_dynamic_objects()

	# Pass 1: Load all location files
	var location_files: Array[String] = MarkdownVault.list_files(MarkdownVault.LOCATIONS_PATH, ".md")
	for filename in location_files:
		var path: String = MarkdownVault.LOCATIONS_PATH + "/" + filename
		var content: String = MarkdownVault.read_file(path)

		if content.is_empty():
			push_warning("WorldKeeper: Empty or missing location file: %s" % filename)
			continue

		_load_location_from_markdown(content)

	# Pass 2: Load all character files
	var char_files: Array[String] = MarkdownVault.list_files(MarkdownVault.OBJECTS_PATH + "/characters", ".md")
	for filename in char_files:
		var path: String = MarkdownVault.OBJECTS_PATH + "/characters/" + filename
		var content: String = MarkdownVault.read_file(path)

		if content.is_empty():
			push_warning("WorldKeeper: Empty or missing character file: %s" % filename)
			continue

		_load_character_from_markdown(content)

	# Pass 3: Restore relationships from world_state.md (if it exists)
	_restore_world_state()

	world_loaded.emit()
	print("WorldKeeper: World loaded from vault (%d locations, %d characters)" % [
		location_files.size(),
		char_files.size()
	])

	return true


func _clear_dynamic_objects() -> void:
	"""Clear all objects except nexus and root_room.

	Preserves foundation objects (#0 and #1) while removing all
	dynamically created objects.

	Notes:
		Used before loading world from vault
	"""
	var to_remove: Array[String] = []

	for obj_id in objects:
		if obj_id != "#0" and obj_id != "#1":
			to_remove.append(obj_id)

	for obj_id in to_remove:
		objects.erase(obj_id)

	print("WorldKeeper: Cleared %d dynamic objects" % to_remove.size())


func _load_location_from_markdown(content: String) -> WorldObject:
	"""Create a location from markdown file.

	Args:
		content: Full markdown content with frontmatter

	Returns:
		The created location WorldObject

	Notes:
		Parses frontmatter for metadata, body for properties
		Adds LocationComponent if specified and restores component data
	"""
	var room: WorldObject = create_object("room", "temp")
	room.from_markdown(content)
	room.set_flag("is_room", true)
	room.move_to(nexus)

	# Add LocationComponent if specified
	var parsed: Dictionary = MarkdownVault.parse_frontmatter(content)
	if "## Components" in parsed.body and "location" in parsed.body:
		var loc_comp: LocationComponent = LocationComponent.new()
		room.add_component("location", loc_comp)
		# Note: Exits will be restored later in _resolve_all_exits()

	return room


func _load_character_from_markdown(content: String) -> WorldObject:
	"""Create a character from markdown file.

	Args:
		content: Full markdown content with frontmatter

	Returns:
		The created character WorldObject

	Notes:
		Restores components based on Components section
		Loads memories from vault if MemoryComponent present
		Does NOT restore location yet (done in pass 3)
	"""
	var char: WorldObject = create_object("character", "temp")
	char.from_markdown(content)

	# Restore components based on Components section
	var parsed: Dictionary = MarkdownVault.parse_frontmatter(content)
	if "## Components" in parsed.body:
		var body: String = parsed.body

		if "actor" in body:
			var actor_comp: ActorComponent = ActorComponent.new()
			char.add_component("actor", actor_comp)

		if "thinker" in body:
			var thinker_comp: ThinkerComponent = ThinkerComponent.new()
			char.add_component("thinker", thinker_comp)

		if "memory" in body:
			var memory_comp: MemoryComponent = MemoryComponent.new()
			char.add_component("memory", memory_comp)

			# Load memories from vault
			var loaded_memories: Array[Dictionary] = memory_comp.load_memories_from_vault(char.name)
			for memory in loaded_memories:
				memory_comp.add_memory(
					memory.get("content", ""),
					memory.get("metadata", {})
				)

	return char


func _save_world_snapshot() -> void:
	"""Create a world_state.md snapshot file.

	Saves current state overview:
	- Active locations with occupant counts
	- Character locations table
	- Recent events (TODO)

	Notes:
		Called by save_world_to_vault()
	"""
	var frontmatter: Dictionary = {
		"snapshot_time": MarkdownVault.get_timestamp()
	}

	var content: String = MarkdownVault.create_frontmatter(frontmatter)
	content += "# World State\n\n"

	# Active Locations
	content += "## Active Locations\n\n"
	for room in get_all_rooms():
		if room == nexus or room == root_room:
			continue
		var occupant_count: int = room.get_contents().size()
		content += "- [[%s]] - %d occupant%s\n" % [
			room.name,
			occupant_count,
			"s" if occupant_count != 1 else ""
		]
	content += "\n"

	# Character Locations
	content += "## Character Locations\n\n"
	content += "| Character | Location |\n"
	content += "|-----------|----------|\n"

	for char in get_objects_with_component("actor"):
		var location: WorldObject = char.get_location()
		var location_name: String = location.name if location else "Nowhere"
		content += "| [[%s]] | [[%s]] |\n" % [char.name, location_name]
	content += "\n"

	# Recent Events (placeholder)
	content += "## Recent Events\n\n"
	content += "*(Event logging to be implemented)*\n\n"

	MarkdownVault.write_file(MarkdownVault.WORLD_PATH + "/world_state.md", content)


func _restore_world_state() -> void:
	"""Restore relationships from world_state.md.

	Parses the world state snapshot to restore:
	- Character locations
	- Exit connections

	Notes:
		Called as third pass during load_world_from_vault()
	"""
	var state_path: String = MarkdownVault.WORLD_PATH + "/world_state.md"
	var content: String = MarkdownVault.read_file(state_path)

	if content.is_empty():
		print("WorldKeeper: No world_state.md found, skipping relationship restoration")
		return

	# Resolve exit connections for all LocationComponents
	_resolve_all_exits()

	# Restore character locations from their markdown frontmatter
	_restore_character_locations()


func _resolve_all_exits() -> void:
	"""Resolve all exit connections for LocationComponents.

	After loading all locations, this method connects exits by parsing
	the Exits section from each location's markdown file.

	Notes:
		Called by _restore_world_state() after all objects loaded
		Uses simple pipe-delimited format: - [[Destination]] | alias1 | alias2
	"""
	# Build name -> object lookup for all rooms
	var room_by_name: Dictionary = {}
	for room in get_all_rooms():
		room_by_name[room.name] = room

	# Resolve exits for each location
	for room in get_all_rooms():
		if not room.has_component("location"):
			continue

		var loc_comp: LocationComponent = room.get_component("location") as LocationComponent

		# Re-parse the room's markdown to get exit data
		var filename: String = MarkdownVault.sanitize_filename(room.name) + ".md"
		var path: String = MarkdownVault.LOCATIONS_PATH + "/" + filename
		var content: String = MarkdownVault.read_file(path)

		if content.is_empty():
			continue

		var parsed: Dictionary = MarkdownVault.parse_frontmatter(content)

		# Parse exits from the Exits section
		if loc_comp.has_method("parse_exits_from_markdown"):
			loc_comp.parse_exits_from_markdown(parsed.body, room_by_name)


func _restore_character_locations() -> void:
	"""Restore character locations from their markdown frontmatter.

	Reads the location metadata from each character's markdown file and
	moves them to the appropriate room. Falls back to root_room if the
	location cannot be found.

	Notes:
		Called by _restore_world_state() after exits are resolved
		Parses location field in format: [[Room Name]]
	"""
	# Build room lookup dictionary for fast name-based lookup
	var room_by_name: Dictionary = {}
	for room in get_all_rooms():
		room_by_name[room.name] = room

	# Restore location for each character with actor component
	for character in get_objects_with_component("actor"):
		# Re-read character markdown to get location metadata
		var filename: String = MarkdownVault.sanitize_filename(character.name) + ".md"
		var path: String = MarkdownVault.OBJECTS_PATH + "/characters/" + filename
		var content: String = MarkdownVault.read_file(path)

		if content.is_empty():
			push_warning("WorldKeeper: Cannot find character file for %s, defaulting to root_room" % character.name)
			character.move_to(root_room)
			continue

		# Parse frontmatter to get location field
		var parsed: Dictionary = MarkdownVault.parse_frontmatter(content)
		var location_str: String = parsed.frontmatter.get("location", "")

		# Parse [[Room Name]] format
		if location_str.begins_with("[[") and location_str.ends_with("]]"):
			var room_name: String = location_str.substr(2, location_str.length() - 4)

			if room_by_name.has(room_name):
				character.move_to(room_by_name[room_name])
				print("WorldKeeper: Restored %s to %s" % [character.name, room_name])
			else:
				push_warning("WorldKeeper: Cannot find room '%s' for character %s, defaulting to root_room" % [room_name, character.name])
				character.move_to(root_room)
		else:
			# No valid location specified, use root_room as fallback
			print("WorldKeeper: No location specified for %s, defaulting to root_room" % character.name)
			character.move_to(root_room)


## Legacy JSON Persistence (deprecated, use vault methods)

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
