## ThinkerComponent: Enables AI agents to make autonomous decisions
##
## Uses Shoggoth (LLM interface) to:
## - Observe the world through Memory component
## - Make decisions based on profile and memories
## - Execute commands through Actor component
##
## Dependencies:
## - ComponentBase: Base class for all components
## - Shoggoth: AI/LLM interface daemon for inference
## - ActorComponent: Required to execute decided actions
## - MemoryComponent: Optional, provides context from past observations
##
## Notes:
## - Think interval can be adjusted per-agent for different behaviors
## - Falls back to simple behavior if LLM is unavailable
## - Processes autonomously via process() method, not frame-based

extends ComponentBase
class_name ThinkerComponent


## The agent's personality profile and behavioral guidelines
## Used as system prompt context for LLM decision-making
var profile: String = "A thoughtful entity."

## How often the agent thinks and makes decisions, in seconds
var think_interval: float = 5.0

## Internal countdown timer for next think cycle
var think_timer: float = 0.0

## Whether the agent is currently waiting for an LLM response
## Prevents overlapping think requests
var is_thinking: bool = false


## Emitted when the agent completes a thought and executes a command
signal thought_completed(command: String, reason: String)

func _on_added(obj: WorldObject) -> void:
	"""Called when this component is added to a WorldObject.

	Initializes the owner reference and think timer.

	Args:
		obj: The WorldObject this component was added to
	"""
	owner = obj
	# Start thinking after one full interval
	think_timer = think_interval


func set_profile(new_profile: String) -> void:
	"""Set the agent's personality profile.

	Updates the profile used as system context for LLM decisions.

	Args:
		new_profile: Personality description and behavioral guidelines
	"""
	profile = new_profile


func set_think_interval(interval: float) -> void:
	"""Set how often the agent thinks.

	Controls the delay between autonomous decision-making cycles.

	Args:
		interval: Time in seconds between think cycles
	"""
	think_interval = interval


func process(delta: float) -> void:
	"""Called each frame to update the think timer.

	Decrements the timer and triggers thought generation when it expires.
	Skips processing if already thinking or owner is invalid.

	Args:
		delta: Time elapsed since last frame in seconds
	"""
	if not owner or is_thinking:
		return

	think_timer -= delta
	if think_timer <= 0.0:
		print("[Thinker] %s is thinking..." % owner.name)
		think_timer = think_interval
		_think()


func _think() -> void:
	"""Generate a thought and action using LLM.

	Builds context from current situation, sends to Shoggoth for
	decision-making, and waits for async response. Falls back to
	simple behavior if LLM is unavailable.
	"""
	is_thinking = true

	# Verify agent has a location
	var location: WorldObject = owner.get_location()
	if not location:
		print("[Thinker] %s has no location!" % owner.name)
		is_thinking = false
		return

	# Build context and construct prompt
	var context: Dictionary = _build_context()
	var prompt: String = _construct_prompt(context)

	# Request LLM decision asynchronously
	if Shoggoth and Shoggoth.ollama_client:
		print("[Thinker] %s sending LLM request..." % owner.name)
		Shoggoth.generate_async(prompt, profile, Callable(self, "_on_thought_complete"))
	else:
		# Fixed FIXME: Split ternary into separate conditional to avoid type incompatibility
		var client_status: String = "N/A"
		if Shoggoth:
			client_status = str(Shoggoth.ollama_client)
		print("[Thinker] %s: No LLM available (Shoggoth: %s, client: %s)" % [owner.name, Shoggoth != null, client_status])

		# Fallback: simple random behavior if no LLM
		_fallback_behavior()
		is_thinking = false

func _build_context() -> Dictionary:
	"""Build context about the agent's current situation.

	Gathers information about location, exits, other actors, and
	recent memories to provide LLM with decision-making context.

	Returns:
		Dictionary containing:
		- name (String): Agent's name
		- profile (String): Agent's personality profile
		- location_name (String): Current location name
		- location_description (String): Location description
		- exits (Array[String]): Available exit names
		- occupants (Array[String]): Names of other actors present
		- recent_memories (Array[String]): Recent observations
	"""
	var location: WorldObject = owner.get_location()
	var context: Dictionary = {
		"name": owner.name,
		"profile": profile,
		"location_name": location.name if location else "nowhere",
		"location_description": location.description if location else "",
		"exits": [],
		"occupants": [],
		"recent_memories": []
	}

	# Extract available exits from location component
	if location and location.has_component("location"):
		var loc_comp: LocationComponent = location.get_component("location") as LocationComponent
		if loc_comp:
			context.exits = loc_comp.get_exits().keys()

	# Find other actors in the same location
	if location:
		for obj in location.get_contents():
			if obj != owner and obj.has_component("actor"):
				context.occupants.append(obj.name)

	# Retrieve recent memories if available
	if owner.has_component("memory"):
		var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent
		context.recent_memories = memory_comp.get_recent_memories(5)

	return context

func _construct_prompt(context: Dictionary) -> String:
	"""Construct LLM prompt from context.

	Builds a structured prompt containing agent identity, current
	situation, available actions, and instructions for response format.

	Uses the Python prototype strategy: repeats current situation at
	the beginning and end to act like an automatic LOOK command.

	Args:
		context: Dictionary from _build_context() with situation info

	Returns:
		String containing the complete LLM prompt

	Notes:
		Expects LLM to respond with COMMAND: and REASON: lines
	"""
	var prompt: String = ""

	# Agent identity and personality
	prompt += "You are %s.\n\n" % context.name
	prompt += "%s\n\n" % context.profile

	# FIRST presentation: Current situation (like an automatic LOOK)
	prompt += "You LOOK around and see:\n\n"
	prompt += "Location: %s\n" % context.location_name
	prompt += "%s\n\n" % context.location_description

	# Available exits
	if context.exits.size() > 0:
		prompt += "Exits: %s\n" % ", ".join(context.exits)
	else:
		prompt += "No exits visible.\n"

	# Other actors present
	if context.occupants.size() > 0:
		prompt += "Also here: %s\n\n" % ", ".join(context.occupants)
	else:
		prompt += "You are alone.\n\n"

	# Recent observations from memory - presented as a transcript scroll
	if context.recent_memories.size() > 0:
		prompt += "## Recent Events (what you've been doing and seeing)\n\n"
		for memory in context.recent_memories:
			var mem_dict: Dictionary = memory as Dictionary
			prompt += "%s\n" % mem_dict.content
		prompt += "\n"

	# SECOND presentation: Reinforce current situation after memories
	prompt += "## Now that you're caught up, remember your current situation:\n\n"
	prompt += "You are %s in %s.\n" % [context.name, context.location_name]
	prompt += "%s\n\n" % context.location_description

	# Repeat exits and occupants for reinforcement
	if context.exits.size() > 0:
		prompt += "Exits: %s\n" % ", ".join(context.exits)
	else:
		prompt += "No exits visible.\n"

	if context.occupants.size() > 0:
		prompt += "Also here: %s\n\n" % ", ".join(context.occupants)
	else:
		prompt += "You are alone.\n\n"

	# Anti-repetition hints (no color tags for LLM)
	prompt += "Hint: Review your prior command and what happened since then. "
	prompt += "If you are stuck or keep doing the same thing, try something different! "
	prompt += "Simply looking around repeatedly without new information wastes time. "
	prompt += "If nothing has changed, consider moving to a different location or initiating conversation.\n\n"

	# Available command reference
	prompt += "## Available Commands\n\n"
	prompt += "- LOOK: Observe your surroundings (only useful if something changed)\n"
	prompt += "- GO exit: Move to another location\n"
	prompt += "- SAY message: Speak to others\n"
	prompt += "- EMOTE action: Perform an action\n"
	prompt += "- EXAMINE target: Look at something/someone closely\n"
	prompt += "- DREAM: Review jumbled memories for new insights (when feeling stuck or curious)\n\n"

	# Response format instructions
	prompt += "What do you want to do? Include a REASON to record your internal "
	prompt += "reasoning (this is private and not visible to others) for your own future freference."
	prompt += "\nRespond with:\n"
	prompt += "COMMAND: <command>\n"
	prompt += "REASON: <optional - detailed explanation of why you're doing this and how it advances your goals>\n"

	return prompt

func _on_thought_complete(response: String) -> void:
	"""Handle LLM response and execute the decided action.

	Parses the LLM response for COMMAND: and REASON: lines, then
	executes the command through the ActorComponent.

	Args:
		response: The LLM's text response containing decision

	Notes:
		Resets is_thinking flag to allow next think cycle.
		Emits thought_completed signal after command execution.
	"""
	is_thinking = false

	# Parse COMMAND: and REASON: lines from response
	var command: String = ""
	var reason: String = ""

	var lines: PackedStringArray = response.split("\n")
	for line in lines:
		if line.begins_with("COMMAND:"):
			command = line.replace("COMMAND:", "").strip_edges()
		elif line.begins_with("REASON:"):
			reason = line.replace("REASON:", "").strip_edges()

	if command != "":
		# Execute the decided command through ActorComponent
		if owner.has_component("actor"):
			var actor_comp: ActorComponent = owner.get_component("actor") as ActorComponent

			# Parse command into verb and arguments
			var parts: PackedStringArray = command.split(" ", true, 1)
			var cmd: String = parts[0].to_lower()
			var args: Array = []
			if parts.size() > 1:
				args = parts[1].split(" ", false)

			actor_comp.execute_command(cmd, args)

		thought_completed.emit(command, reason)


func _fallback_behavior() -> void:
	"""Simple fallback behavior when no LLM is available.

	Performs a basic "look" command to maintain some autonomous
	behavior even without AI inference.

	Notes:
		Called when Shoggoth or its client is unavailable.
		Provides minimal autonomous activity for debugging.
	"""
	print("[Thinker] %s using fallback behavior (no LLM)" % owner.name)

	# Perform simple observation action
	if owner.has_component("actor"):
		var actor_comp: ActorComponent = owner.get_component("actor") as ActorComponent
		actor_comp.execute_command("look")
