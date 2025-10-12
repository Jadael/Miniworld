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

## Emitted when a property value changes
signal property_changed(property_name: String, old_value, new_value)
## Emitted when a component is added to this object
signal component_added(component_name: String)
## Emitted when a component is removed from this object
signal component_removed(component_name: String)
## Emitted when a verb is called on this object
signal verb_called(verb_name: String, caller: WorldObject, args: Array)
## Emitted when this object moves to a new parent
signal parent_changed(old_parent: WorldObject, new_parent: WorldObject)

## Unique identifier in MOO-style format (e.g., "#123")
var id: String = ""

## Display name of this object
var name: String = "object"

## Textual description shown when examining this object
var description: String = "You see nothing special."

## Alternative names for command parsing and object matching
var aliases: Array[String] = []


## Component instances attached to this object
## Key: String (component name), Value: Component instance
var components: Dictionary = {}

## Arbitrary data storage for object-specific properties
## Key: String (property name), Value: Variant (any value)
var properties: Dictionary = {}

## Callable methods that can be invoked on this object
## Key: String (verb name), Value: Callable (verb implementation)
var verbs: Dictionary = {}


## The object that contains this object (null if not contained)
var parent: WorldObject = null

## Objects contained by this object
var contents: Array[WorldObject] = []


## Unix timestamp when this object was created
var created_at: int = 0

## The WorldObject that owns or created this object
var owner: WorldObject = null

## Boolean flags for object state and capabilities
## Common flags: is_player, is_room, is_portable, etc.
var flags: Dictionary = {}

func _init(object_id: String = "", object_name: String = "object") -> void:
	"""Initialize a new WorldObject with the given ID and name.

	Args:
		object_id: Unique identifier for this object (auto-generated if empty)
		object_name: Display name for this object
	"""
	id = object_id if object_id != "" else _generate_id()
	name = object_name
	created_at = int(Time.get_unix_time_from_system())


func _generate_id() -> String:
	"""Generate a unique object ID in MOO-style format.

	Returns:
		A unique ID string in format "#timestamp_random"

	Notes:
		Combines Unix timestamp with random number for uniqueness
	"""
	return "#" + str(Time.get_unix_time_from_system()) + "_" + str(randi())

func add_component(component_name: String, component: Variant) -> void:
	"""Add a component to this object, replacing any existing component with the same name.

	Args:
		component_name: Unique identifier for this component (e.g., "actor", "thinker")
		component: The component instance to attach

	Notes:
		If the component has an _on_added(object) method, it will be called.
		Emits component_added signal.
	"""
	if component_name in components:
		push_warning("WorldObject: Replacing existing component '%s' on object %s" % [component_name, id])

	components[component_name] = component

	# Allow component to initialize itself with reference to this object
	if component.has_method("_on_added"):
		component._on_added(self)

	component_added.emit(component_name)


func remove_component(component_name: String) -> void:
	"""Remove a component from this object.

	Args:
		component_name: Name of the component to remove

	Notes:
		If the component has an _on_removed(object) method, it will be called.
		Emits component_removed signal.
		Silently returns if component doesn't exist.
	"""
	if component_name not in components:
		return

	var component = components[component_name]

	# Allow component to clean up before removal
	if component.has_method("_on_removed"):
		component._on_removed(self)

	components.erase(component_name)
	component_removed.emit(component_name)


func has_component(component_name: String) -> bool:
	"""Check if this object has a component with the given name.

	Args:
		component_name: Name of the component to check for

	Returns:
		True if the component exists, false otherwise
	"""
	return component_name in components


func get_component(component_name: String) -> Variant:
	"""Retrieve a component by name.

	Args:
		component_name: Name of the component to retrieve

	Returns:
		The component instance, or null if not found
	"""
	return components.get(component_name, null)

func set_property(property_name: String, value: Variant) -> void:
	"""Set a property value on this object (MOO-style property system).

	Args:
		property_name: Name of the property to set
		value: The value to assign

	Notes:
		Emits property_changed signal with old and new values.
		Properties can store any Variant type for maximum flexibility.
	"""
	var old_value = properties.get(property_name, null)
	properties[property_name] = value
	property_changed.emit(property_name, old_value, value)


func get_property(property_name: String, default_value: Variant = null) -> Variant:
	"""Get a property value from this object.

	Args:
		property_name: Name of the property to retrieve
		default_value: Value to return if property doesn't exist

	Returns:
		The property value, or default_value if not found
	"""
	return properties.get(property_name, default_value)


func has_property(property_name: String) -> bool:
	"""Check if this object has a property with the given name.

	Args:
		property_name: Name of the property to check for

	Returns:
		True if the property exists, false otherwise
	"""
	return property_name in properties

func add_verb(verb_name: String, callable: Callable) -> void:
	"""Add a callable verb to this object (MOO-style verb system).

	Args:
		verb_name: Name of the verb (e.g., "take", "examine", "use")
		callable: The Callable to invoke when verb is called

	Notes:
		Verbs define the actions that can be performed on/with this object.
		The Callable should accept (caller: WorldObject, args: Array) parameters.
	"""
	verbs[verb_name] = callable


func remove_verb(verb_name: String) -> void:
	"""Remove a verb from this object.

	Args:
		verb_name: Name of the verb to remove
	"""
	verbs.erase(verb_name)


func has_verb(verb_name: String) -> bool:
	"""Check if this object has a verb with the given name.

	Args:
		verb_name: Name of the verb to check for

	Returns:
		True if the verb exists, false otherwise
	"""
	return verb_name in verbs


func call_verb(verb_name: String, caller: WorldObject, args: Array = []) -> Variant:
	"""Execute a verb on this object.

	Args:
		verb_name: Name of the verb to call
		caller: The WorldObject invoking this verb
		args: Arguments to pass to the verb

	Returns:
		Result from the verb callable, or error Dictionary if verb not found

	Notes:
		Emits verb_called signal before executing the verb.
		Returns {"success": false, "error": "..."} if verb doesn't exist.
	"""
	if not has_verb(verb_name):
		return {"success": false, "error": "Verb '%s' not found on object %s" % [verb_name, name]}

	verb_called.emit(verb_name, caller, args)

	var verb_callable = verbs[verb_name]
	return verb_callable.call(caller, args)

func move_to(new_parent: WorldObject) -> bool:
	"""Move this object to a new container (parent object).

	Args:
		new_parent: The WorldObject that should contain this object (null for no container)

	Returns:
		Always returns true (for future error handling expansion)

	Notes:
		Automatically handles removing from old parent and adding to new parent.
		Emits parent_changed signal.
		Maintains bidirectional parent-child relationships.
	"""
	# Remove from current parent's contents
	if parent != null:
		parent.contents.erase(self)

	var old_parent = parent
	parent = new_parent

	# Add to new parent's contents
	if new_parent != null:
		if self not in new_parent.contents:
			new_parent.contents.append(self)

	parent_changed.emit(old_parent, new_parent)
	return true


func get_contents() -> Array[WorldObject]:
	"""Get all objects contained by this object.

	Returns:
		Array of WorldObjects directly contained by this object
	"""
	return contents


func contains(obj: WorldObject) -> bool:
	"""Check if this object contains another object.

	Args:
		obj: The WorldObject to check for

	Returns:
		True if obj is in this object's contents, false otherwise

	Notes:
		Only checks direct containment, not recursive.
	"""
	return obj in contents


func get_location() -> WorldObject:
	"""Get the room this object is in by walking up the parent chain.

	Returns:
		The first ancestor WorldObject with is_room flag set, or null if not in a room

	Notes:
		Walks up parent chain until finding an object with the is_room flag.
		This enables objects to be nested (in containers, in rooms, etc.).
	"""
	var current = self
	while current != null:
		if current.has_flag("is_room"):
			return current
		current = current.parent
	return null

func set_flag(flag_name: String, value: bool = true) -> void:
	"""Set a boolean flag on this object.

	Args:
		flag_name: Name of the flag to set
		value: Boolean value to assign (default: true)

	Notes:
		Common flags include: is_player, is_room, is_portable, is_locked, etc.
	"""
	flags[flag_name] = value


func has_flag(flag_name: String) -> bool:
	"""Check if a flag is set to true on this object.

	Args:
		flag_name: Name of the flag to check

	Returns:
		True if flag exists and is true, false otherwise
	"""
	return flags.get(flag_name, false)


func get_flag(flag_name: String, default: bool = false) -> bool:
	"""Get the value of a flag with a default fallback.

	Args:
		flag_name: Name of the flag to retrieve
		default: Value to return if flag doesn't exist

	Returns:
		The flag's boolean value, or default if not set
	"""
	return flags.get(flag_name, default)


func matches_name(test_name: String) -> bool:
	"""Check if this object matches a given name (case-insensitive).

	Args:
		test_name: The name to test against

	Returns:
		True if test_name matches this object's name or any alias

	Notes:
		Used for command parsing to match player input to objects.
		Performs case-insensitive comparison.
	"""
	var test_lower = test_name.to_lower()
	if name.to_lower() == test_lower:
		return true
	for alias in aliases:
		if alias.to_lower() == test_lower:
			return true
	return false


func get_debug_string() -> String:
	"""Get a debug string representation of this object.

	Returns:
		A string in format "name (id)" for debugging purposes
	"""
	return "%s (%s)" % [name, id]


func get_description() -> String:
	"""Get the full description, potentially enhanced by components.

	Returns:
		The object's description, modified by any components that implement enhance_description()

	Notes:
		Allows components to add dynamic information to object descriptions.
		For example, a health component might add current HP to the description.
	"""
	var desc = description

	# Allow components to enhance or modify the description
	for component_name in components:
		var component = components[component_name]
		if component.has_method("enhance_description"):
			desc = component.enhance_description(desc)

	return desc
