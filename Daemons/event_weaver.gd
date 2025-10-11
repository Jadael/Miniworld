## EventWeaver: Daemon for event propagation and observation
##
## This singleton handles broadcasting events to observers in the world.
## When something happens (speech, movement, actions), interested parties
## (actors in the same location) are notified.
##
## This replaces the Python prototype's event_bus and event_dispatcher.

extends Node

## Signals for system-wide events
signal world_event(event: Dictionary)

## Broadcast an event to all actors in a specific location
func broadcast_to_location(location: WorldObject, event: Dictionary) -> void:
	"""Send an event to all actors in a location"""
	if location == null:
		return

	# Add location to event data
	event["location"] = location

	# Find all actors in this location
	var actors = _get_actors_in_location(location)

	# Notify each actor
	for actor in actors:
		_notify_actor(actor, event)

	# Emit system-wide signal
	world_event.emit(event)

## Broadcast an event to a specific actor
func broadcast_to_actor(actor: WorldObject, event: Dictionary) -> void:
	"""Send an event directly to a specific actor"""
	if actor == null:
		return

	_notify_actor(actor, event)

## Broadcast an event to all actors in the world
func broadcast_global(event: Dictionary) -> void:
	"""Send an event to everyone"""
	var all_actors = WorldKeeper.get_objects_with_component("actor")

	for actor in all_actors:
		_notify_actor(actor, event)

	world_event.emit(event)

## Internal: Get all actors in a location
func _get_actors_in_location(location: WorldObject) -> Array[WorldObject]:
	"""Find all actors currently in a location"""
	var actors: Array[WorldObject] = []

	for obj in location.get_contents():
		if obj.has_component("actor"):
			actors.append(obj)

	return actors

## Internal: Notify a single actor of an event
func _notify_actor(actor: WorldObject, event: Dictionary) -> void:
	"""Send an event to an actor's ActorComponent"""
	var actor_comp = actor.get_component("actor")
	if actor_comp == null:
		return

	# Call the component's observe_event method
	if actor_comp.has_method("observe_event"):
		actor_comp.observe_event(event)

## Helper: Format an event as text for display
func format_event(event: Dictionary) -> String:
	"""Convert an event to human-readable text"""
	match event.get("type", ""):
		"speech":
			return event.get("text", "")
		"emote":
			return event.get("text", "")
		"action":
			return event.get("message", "")
		"movement":
			return event.get("message", "")
		_:
			return str(event)
