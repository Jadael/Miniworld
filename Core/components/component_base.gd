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

extends RefCounted
class_name ComponentBase

## Reference to the WorldObject that owns this component
var owner: WorldObject = null

## Called when this component is added to a WorldObject
func _on_added(obj: WorldObject) -> void:
	owner = obj

## Called when this component is removed from a WorldObject
func _on_removed(_obj: WorldObject) -> void:
	owner = null

## Optional: enhance the object's description
func enhance_description(base_description: String) -> String:
	return base_description

## Optional: process a command directed at the owner
func process_command(_command: String, _caller: WorldObject, _args: Array) -> Variant:
	return null  # Return null if this component doesn't handle the command

## Optional: called every frame if component needs updates
func _process(_delta: float) -> void:
	pass
