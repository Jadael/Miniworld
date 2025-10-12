## EventWeaver: Daemon for event propagation and observation
##
## This singleton handles broadcasting events to observers in the world.
## When something happens (speech, movement, actions), interested parties
## (actors in the same location) are notified.
##
## Core responsibilities:
## - Broadcasting events to actors in specific locations
## - Routing events to individual actors
## - Global event broadcasts
## - Event formatting for display
##
## In MOO terms, this handles event propagation similar to notify_except()
## and related functions, ensuring actors observe events in their environment.
##
## This replaces the Python prototype's event_bus and event_dispatcher.
##
## Related systems:
## - ActorComponent: Receives and processes observed events
## - MemoryComponent: Stores observed events for recall
## - WorldKeeper: Provides object lookups for event routing

extends Node


## Emitted for all events, allowing system-wide event monitoring and logging
signal world_event(event: Dictionary)

## Event broadcasting

func broadcast_to_location(location: WorldObject, event: Dictionary) -> void:
	"""Send an event to all actors in a specific location.

	This is the primary method for location-based events like speech,
	emotes, and actions that should be observed by everyone present.

	Args:
		location: The WorldObject representing the room/container
		event: Dictionary containing event data (type, actor, text, etc.)

	Notes:
		- Automatically adds "location" field to event data
		- Only notifies actors with ActorComponent
		- Emits world_event signal for system-wide monitoring
		- Safely handles null location (no-op)
	"""
	if location == null:
		return

	# Add location context to event data
	event["location"] = location

	# Find all actors in this location
	var actors: Array[WorldObject] = _get_actors_in_location(location)

	# Notify each actor
	for actor in actors:
		_notify_actor(actor, event)

	# Emit system-wide signal for logging/monitoring
	world_event.emit(event)


func broadcast_to_actor(actor: WorldObject, event: Dictionary) -> void:
	"""Send an event directly to a specific actor.

	Used for private messages or actor-specific notifications that
	shouldn't be observed by others in the location.

	Args:
		actor: The target WorldObject with ActorComponent
		event: Dictionary containing event data

	Notes:
		- Does not emit world_event signal (private)
		- Safely handles null actor (no-op)
		- Useful for tells, system messages, etc.
	"""
	if actor == null:
		return

	_notify_actor(actor, event)


func broadcast_global(event: Dictionary) -> void:
	"""Send an event to all actors in the entire world.

	Used for world-wide announcements, system messages, or events
	that all actors should observe regardless of location.

	Args:
		event: Dictionary containing event data

	Notes:
		- Queries WorldKeeper for all objects with ActorComponent
		- Can be expensive for large worlds
		- Emits world_event signal for monitoring
		- Use sparingly for truly global events
	"""
	var all_actors: Array[WorldObject] = WorldKeeper.get_objects_with_component("actor")

	for actor in all_actors:
		_notify_actor(actor, event)

	world_event.emit(event)

## Internal helper methods

func _get_actors_in_location(location: WorldObject) -> Array[WorldObject]:
	"""Find all actors currently in a location.

	Args:
		location: The WorldObject to search for actors

	Returns:
		Array of WorldObjects with ActorComponent in the location

	Notes:
		- Iterates through location's contents
		- Filters for objects with ActorComponent
		- Used internally by broadcast_to_location
	"""
	var actors: Array[WorldObject] = []

	for obj in location.get_contents():
		if obj.has_component("actor"):
			actors.append(obj)

	return actors


func _notify_actor(actor: WorldObject, event: Dictionary) -> void:
	"""Send an event to an actor's ActorComponent.

	Args:
		actor: The WorldObject to notify
		event: The event data to send

	Notes:
		- Safely handles missing ActorComponent (no-op)
		- Calls observe_event() method on ActorComponent if present
		- Actor's component determines how to process the event
		- Used internally by all broadcast methods
	"""
	var actor_comp = actor.get_component("actor")
	if actor_comp == null:
		return

	# Call the component's observe_event method if it exists
	if actor_comp.has_method("observe_event"):
		actor_comp.observe_event(event)


## Event formatting utilities

func format_event(event: Dictionary) -> String:
	"""Convert an event to human-readable text.

	Extracts the appropriate display text based on event type.

	Args:
		event: The event Dictionary to format

	Returns:
		Human-readable string representation of the event

	Notes:
		Supported event types:
		- "speech": Returns event["text"]
		- "emote": Returns event["text"]
		- "action": Returns event["message"]
		- "movement": Returns event["message"]
		- Unknown types: Returns str(event) for debugging
	"""
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
			# Fallback for unknown event types
			return str(event)
