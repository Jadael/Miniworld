## ThinkerComponent: Enables AI agents to make autonomous decisions
##
## Uses Shoggoth (LLM interface) to:
## - Observe the world through Memory component
## - Make decisions based on profile and memories
## - Execute commands through Actor component

extends ComponentBase
class_name ThinkerComponent

## Agent's personality profile
var profile: String = "A thoughtful entity."

## How often to think (in seconds)
var think_interval: float = 5.0

## Timer for autonomous thinking
var think_timer: float = 0.0

## Whether the agent is currently thinking
var is_thinking: bool = false

signal thought_completed(command: String, reason: String)

func _on_added(obj: WorldObject) -> void:
	owner = obj
	# Start thinking on next frame
	think_timer = think_interval

func set_profile(new_profile: String) -> void:
	"""Set the agent's personality profile"""
	profile = new_profile

func set_think_interval(interval: float) -> void:
	"""Set how often the agent thinks"""
	think_interval = interval

func process(delta: float) -> void:
	"""Called each frame to update thinking"""
	if not owner or is_thinking:
		return

	think_timer -= delta
	if think_timer <= 0.0:
		print("AI Agent %s is thinking..." % owner.name)
		think_timer = think_interval
		_think()

func _think() -> void:
	"""Generate a thought and action using LLM"""
	is_thinking = true

	# Get current context
	var location = owner.get_location()
	if not location:
		print("AI Agent %s has no location!" % owner.name)
		is_thinking = false
		return

	# Build context for LLM
	var context = _build_context()

	# Ask Shoggoth for a decision
	var prompt = _construct_prompt(context)

	# Call Shoggoth asynchronously
	if Shoggoth and Shoggoth.ollama_client:
		print("AI Agent %s sending LLM request..." % owner.name)
		Shoggoth.generate_async(prompt, profile, Callable(self, "_on_thought_complete"))
	else:
		print("AI Agent %s: No LLM available (Shoggoth: %s, client: %s)" % [owner.name, Shoggoth != null, Shoggoth.ollama_client if Shoggoth else "N/A"])		# FIXME: W 0:00:01:365   Values of the ternary operator are not mutually compatible. | <GDScript Error>INCOMPATIBLE_TERNARY | <GDScript Source>thinker.gd:71
		# Fallback: simple random behavior if no LLM
		_fallback_behavior()
		is_thinking = false

func _build_context() -> Dictionary:
	"""Build context about current situation"""
	var location = owner.get_location()
	var context = {
		"name": owner.name,
		"profile": profile,
		"location_name": location.name if location else "nowhere",
		"location_description": location.description if location else "",
		"exits": [],
		"occupants": [],
		"recent_memories": []
	}

	# Get location info
	if location and location.has_component("location"):
		var loc_comp = location.get_component("location") as LocationComponent
		if loc_comp:
			context.exits = loc_comp.get_exits().keys()

	# Get occupants
	if location:
		for obj in location.get_contents():
			if obj != owner and obj.has_component("actor"):
				context.occupants.append(obj.name)

	# Get recent memories
	if owner.has_component("memory"):
		var memory_comp = owner.get_component("memory") as MemoryComponent
		context.recent_memories = memory_comp.get_recent_memories(5)

	return context

func _construct_prompt(context: Dictionary) -> String:
	"""Construct LLM prompt from context"""
	var prompt = ""

	# Profile
	prompt += "You are %s.\n\n" % context.name
	prompt += "%s\n\n" % context.profile

	# Current situation
	prompt += "## Current Situation\n\n"
	prompt += "You are in: %s\n" % context.location_name
	prompt += "%s\n\n" % context.location_description

	# Exits
	if context.exits.size() > 0:
		prompt += "Exits: %s\n" % ", ".join(context.exits)
	else:
		prompt += "No exits visible.\n"

	# Occupants
	if context.occupants.size() > 0:
		prompt += "Also here: %s\n\n" % ", ".join(context.occupants)
	else:
		prompt += "You are alone.\n\n"

	# Recent memories
	if context.recent_memories.size() > 0:
		prompt += "## Recent Memories\n\n"
		for memory in context.recent_memories:
			prompt += "- %s\n" % memory
		prompt += "\n"

	# Instructions
	prompt += "## Available Commands\n\n"
	prompt += "- look: Observe your surroundings\n"
	prompt += "- go <exit>: Move to another location\n"
	prompt += "- say <message>: Speak to others\n"
	prompt += "- emote <action>: Perform an action\n"
	prompt += "- examine <target>: Look at something/someone closely\n\n"

	prompt += "What do you want to do? Respond with:\n"
	prompt += "COMMAND: <command>\n"
	prompt += "REASON: <why you want to do this>\n"

	return prompt

func _on_thought_complete(response: String) -> void:
	"""Handle LLM response"""
	is_thinking = false

	# Parse response
	var command = ""
	var reason = ""

	var lines = response.split("\n")
	for line in lines:
		if line.begins_with("COMMAND:"):
			command = line.replace("COMMAND:", "").strip_edges()
		elif line.begins_with("REASON:"):
			reason = line.replace("REASON:", "").strip_edges()

	if command != "":
		# Execute command through actor
		if owner.has_component("actor"):
			var actor_comp = owner.get_component("actor") as ActorComponent
			var parts = command.split(" ", true, 1)
			var cmd = parts[0].to_lower()
			var args: Array = []
			if parts.size() > 1:
				args = parts[1].split(" ", false)

			actor_comp.execute_command(cmd, args)

		thought_completed.emit(command, reason)

func _fallback_behavior() -> void:
	"""Simple fallback behavior when no LLM available"""
	print("AI Agent %s using fallback behavior (no LLM)" % owner.name)
	# Just look around occasionally
	if owner.has_component("actor"):
		var actor_comp = owner.get_component("actor") as ActorComponent
		actor_comp.execute_command("look")
