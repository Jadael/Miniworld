## WorldObject: The foundation of everything in Miniworld
##
## In the spirit of LambdaMOO, everything in the world is a WorldObject.
## Rooms, players, AI agents, furniture, even abstract concepts - all are objects.
##
## Objects are identified by unique IDs (MOO-style #123 format) and compose
## their behavior through components rather than inheritance hierarchies.
##
## Key concepts:
## - Every object has an ID, name, description, and parent (containment)
## - Objects can have components that add capabilities (Actor, Thinker, Location, etc.)
## - Objects have verbs (callable methods) that define their behavior
## - Objects have properties (arbitrary data storage)
##
## This approach enables:
## - Uniform interaction model (players and AI use same systems)
## - Runtime object creation and modification
## - Future in-game scripting/programming capabilities

extends RefCounted
class_name WorldObject

## Signals for object lifecycle and state changes
signal property_changed(property_name: String, old_value, new_value)
signal component_added(component_name: String)
signal component_removed(component_name: String)
signal verb_called(verb_name: String, caller: WorldObject, args: Array)
signal parent_changed(old_parent: WorldObject, new_parent: WorldObject)

## Core identity
var id: String = ""  # Unique identifier (e.g., "#123")
var name: String = "object"
var description: String = "You see nothing special."
var aliases: Array[String] = []  # Alternative names for matching

## Composition over inheritance
var components: Dictionary = {}  # String -> Component
var properties: Dictionary = {}  # String -> Variant (arbitrary data)
var verbs: Dictionary = {}  # String -> Callable (verb definitions)

## Containment hierarchy (MOO-style)
var parent: WorldObject = null  # What contains this object
var contents: Array[WorldObject] = []  # What this object contains

## Metadata
var created_at: int = 0  # Unix timestamp
var owner: WorldObject = null  # Who owns/created this object
var flags: Dictionary = {}  # Boolean flags (is_player, is_room, etc.)

func _init(object_id: String = "", object_name: String = "object") -> void:
	id = object_id if object_id != "" else _generate_id()
	name = object_name
	created_at = int(Time.get_unix_time_from_system())

## Generate a unique object ID (MOO-style #number)
func _generate_id() -> String:
	return "#" + str(Time.get_unix_time_from_system()) + "_" + str(randi())

## Component management
func add_component(component_name: String, component: Variant) -> void:
	if component_name in components:
		push_warning("WorldObject: Replacing existing component '%s' on object %s" % [component_name, id])

	components[component_name] = component

	# If the component has an _on_added method, call it
	if component.has_method("_on_added"):
		component._on_added(self)

	component_added.emit(component_name)

func remove_component(component_name: String) -> void:
	if component_name not in components:
		return

	var component = components[component_name]

	# If the component has an _on_removed method, call it
	if component.has_method("_on_removed"):
		component._on_removed(self)

	components.erase(component_name)
	component_removed.emit(component_name)

func has_component(component_name: String) -> bool:
	return component_name in components

func get_component(component_name: String) -> Variant:
	return components.get(component_name, null)

## Property management (MOO-style properties)
func set_property(property_name: String, value: Variant) -> void:
	var old_value = properties.get(property_name, null)
	properties[property_name] = value
	property_changed.emit(property_name, old_value, value)

func get_property(property_name: String, default_value: Variant = null) -> Variant:
	return properties.get(property_name, default_value)

func has_property(property_name: String) -> bool:
	return property_name in properties

## Verb management (MOO-style verbs)
func add_verb(verb_name: String, callable: Callable) -> void:
	verbs[verb_name] = callable

func remove_verb(verb_name: String) -> void:
	verbs.erase(verb_name)

func has_verb(verb_name: String) -> bool:
	return verb_name in verbs

## Call a verb on this object
func call_verb(verb_name: String, caller: WorldObject, args: Array = []) -> Variant:
	if not has_verb(verb_name):
		return {"success": false, "error": "Verb '%s' not found on object %s" % [verb_name, name]}

	verb_called.emit(verb_name, caller, args)

	var verb_callable = verbs[verb_name]
	return verb_callable.call(caller, args)

## Containment management
func move_to(new_parent: WorldObject) -> bool:
	# Remove from current parent
	if parent != null:
		parent.contents.erase(self)

	var old_parent = parent
	parent = new_parent

	# Add to new parent
	if new_parent != null:
		if self not in new_parent.contents:
			new_parent.contents.append(self)

	parent_changed.emit(old_parent, new_parent)
	return true

func get_contents() -> Array[WorldObject]:
	return contents

func contains(obj: WorldObject) -> bool:
	return obj in contents

## Location traversal
func get_location() -> WorldObject:
	"""Get the location (room) this object is in by walking up the parent chain"""
	var current = self
	while current != null:
		if current.has_flag("is_room"):
			return current
		current = current.parent
	return null

## Flag management
func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value

func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

func get_flag(flag_name: String, default: bool = false) -> bool:
	return flags.get(flag_name, default)

## Name matching (for command parsing)
func matches_name(test_name: String) -> bool:
	"""Check if this object matches a given name (case-insensitive)"""
	var test_lower = test_name.to_lower()
	if name.to_lower() == test_lower:
		return true
	for alias in aliases:
		if alias.to_lower() == test_lower:
			return true
	return false

## Utility methods
func get_debug_string() -> String:
	"""Get a debug string representation of this object"""
	return "%s (%s)" % [name, id]

func get_description() -> String:
	"""Get the full description, potentially enhanced by components"""
	var desc = description

	# Let components contribute to description
	for component_name in components:
		var component = components[component_name]
		if component.has_method("enhance_description"):
			desc = component.enhance_description(desc)

	return desc
