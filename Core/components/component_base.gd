## ComponentBase: Base class for all WorldObject components
##
## Components add capabilities to WorldObjects using composition.
## Each component implements specific behavior without inheritance hierarchies.
##
## Component lifecycle:
## - _on_added(owner: WorldObject) - Called when attached to an object
## - _on_removed(owner: WorldObject) - Called when removed from an object
##
## Components can:
## - Store their own data
## - Access their owner object
## - Contribute to object behavior (description, verbs, etc.)
## - React to events
##
## This is the foundation of Miniworld's composition-based architecture,
## replacing traditional inheritance hierarchies with flexible behavior composition.

extends RefCounted
class_name ComponentBase


## Reference to the WorldObject that owns this component
var owner: WorldObject = null


func _on_added(obj: WorldObject) -> void:
	"""Called when this component is added to a WorldObject.

	Override this to initialize component state or connect to signals.

	Args:
		obj: The WorldObject this component is being added to
	"""
	owner = obj


func _on_removed(_obj: WorldObject) -> void:
	"""Called when this component is removed from a WorldObject.

	Override this to clean up state or disconnect signals.

	Args:
		_obj: The WorldObject this component is being removed from
	"""
	owner = null


func enhance_description(base_description: String) -> String:
	"""Optionally enhance the owner object's description.

	Override this to add component-specific information to object descriptions.
	For example, LocationComponent adds exit information.

	Args:
		base_description: The object's base description text

	Returns:
		Enhanced description (default: unchanged base_description)
	"""
	return base_description


func process_command(_command: String, _caller: WorldObject, _args: Array) -> Variant:
	"""Optionally handle a command directed at the owner.

	Override this to enable component-specific command handling.

	Args:
		_command: The command name
		_caller: The WorldObject executing the command
		_args: Command arguments

	Returns:
		Command result Dictionary if handled, null otherwise
	"""
	return null


func _process(_delta: float) -> void:
	"""Optionally process per-frame updates.

	Override this if the component needs to update state each frame.
	Note: This must be explicitly called by the component's manager.

	Args:
		_delta: Time elapsed since last frame in seconds
	"""
	pass
