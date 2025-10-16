## ThinkerComponent: Enables AI agents to make autonomous decisions
##
## Uses Shoggoth (LLM interface) to:
## - Observe the world through Memory component
## - Make decisions based on profile and memories
## - Execute commands through Actor component using MOO-style syntax
##
## Dependencies:
## - ComponentBase: Base class for all components
## - Shoggoth: AI/LLM interface daemon for inference
## - ActorComponent: Required to execute decided actions
## - MemoryComponent: Optional, provides context from past observations
## - EventWeaver: Used to broadcast observable thinking behavior
##
## Notes:
## - Think interval can be adjusted per-agent for different behaviors
## - Falls back to simple behavior if LLM is unavailable
## - Processes autonomously via process() method, not frame-based
## - Uses MOO-style command syntax: "command args | reason" where | is optional
## - Reasoning after | is private (stored in memory, not visible to others)
## - Broadcasts "pauses, deep in thought..." just-in-time when prompt is built (visible to others)
## - Broadcasting happens at the last moment so agent sees all events until they "zone out"

extends ComponentBase
class_name ThinkerComponent


## DEPRECATED: Use owner.get_property("thinker.profile") instead
## This var exists only for backwards compatibility
var _deprecated_profile: String = "A thoughtful entity."

## DEPRECATED: Use owner.get_property("thinker.think_interval") instead
## This var exists only for backwards compatibility
var _deprecated_think_interval: float = 6.0

## Internal countdown timer for next think cycle
var think_timer: float = 0.0

## Whether the agent is currently waiting for an LLM response
## Prevents overlapping think requests
var is_thinking: bool = false


## Emitted when the agent completes a thought and executes a command
signal thought_completed(command: String, reason: String)

func _on_added(obj: WorldObject) -> void:
	"""Called when this component is added to a WorldObject.

	Initializes the owner reference, think timer, and sets up default
	properties if they don't already exist.

	Args:
		obj: The WorldObject this component was added to
	"""
	owner = obj

	# Initialize default properties if not already set
	if not owner.has_property("thinker.profile"):
		owner.set_property("thinker.profile", _deprecated_profile)
	if not owner.has_property("thinker.think_interval"):
		owner.set_property("thinker.think_interval", _deprecated_think_interval)
	if not owner.has_property("thinker.prompt_template"):
		owner.set_property("thinker.prompt_template", "default")

	# Start thinking after one full interval
	think_timer = get_think_interval()


func set_profile(new_profile: String) -> void:
	"""Set the agent's personality profile.

	Updates the profile property used as system context for LLM decisions.

	Args:
		new_profile: Personality description and behavioral guidelines
	"""
	if owner:
		owner.set_property("thinker.profile", new_profile)
	else:
		_deprecated_profile = new_profile


func get_profile() -> String:
	"""Get the agent's personality profile.

	Returns:
		The profile string from properties, or deprecated fallback
	"""
	if owner and owner.has_property("thinker.profile"):
		return owner.get_property("thinker.profile")
	return _deprecated_profile


func set_think_interval(interval: float) -> void:
	"""Set how often the agent thinks.

	Controls the delay between autonomous decision-making cycles.

	Args:
		interval: Time in seconds between think cycles
	"""
	if owner:
		owner.set_property("thinker.think_interval", interval)
	else:
		_deprecated_think_interval = interval


func get_think_interval() -> float:
	"""Get the agent's think interval.

	Returns:
		The think interval from properties, or deprecated fallback
	"""
	if owner and owner.has_property("thinker.think_interval"):
		return owner.get_property("thinker.think_interval")
	return _deprecated_think_interval


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
		think_timer = get_think_interval()
		_think()


func _think() -> void:
	"""Queue a thought task with Shoggoth.

	Instead of building the prompt immediately, we pass a callable that will
	build the prompt just-in-time when Shoggoth is ready to execute it.
	This ensures the agent has the most up-to-date memories and observations.

	Falls back to simple behavior if LLM is unavailable.

	The prompt generator callable broadcasts observable "pondering" behavior
	at the last possible moment (just before building context), ensuring the
	agent sees all events up until they actually "zone out" to think.
	"""
	is_thinking = true

	# Verify agent has a location
	var location: WorldObject = owner.get_location()
	if not location:
		print("[Thinker] %s has no location!" % owner.name)
		is_thinking = false
		return

	# Request LLM decision asynchronously
	if Shoggoth and Shoggoth.ollama_client:
		print("[Thinker] %s queuing LLM request..." % owner.name)

		# Pass a callable that:
		# 1. Broadcasts thinking behavior (at the last moment before context is built)
		# 2. Builds the prompt fresh when Shoggoth is ready to execute
		var prompt_generator: Callable = func() -> String:
			# This runs just-in-time when Shoggoth is ready - broadcast NOW
			var current_location: WorldObject = owner.get_location()
			_broadcast_thinking_behavior(current_location)

			# Now build fresh context and prompt
			var fresh_context: Dictionary = _build_context()
			return _construct_prompt(fresh_context)

		Shoggoth.generate_async(prompt_generator, get_profile(), Callable(self, "_on_thought_complete"))
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
		- relevant_notes (Array[Dictionary]): Contextually relevant notes from personal wiki
	"""
	var location: WorldObject = owner.get_location()
	var context: Dictionary = {
		"name": owner.name,
		"profile": get_profile(),
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
		context.recent_memories = memory_comp.get_recent_memories(64)

		# Retrieve contextually relevant notes based on location and occupants
		# Create typed array for occupants to satisfy type checker
		var occupants_typed: Array[String] = []
		for occupant in context.occupants:
			occupants_typed.append(occupant)

		context.relevant_notes = memory_comp.get_relevant_notes_for_context(
			context.location_name,
			occupants_typed,
			3  # max 3 relevant notes
		)
	else:
		context.relevant_notes = []

	return context

func _construct_prompt(context: Dictionary) -> String:
	"""Construct LLM prompt from context.

	Builds a structured prompt containing agent identity, current
	situation, available actions, and instructions for response format.

	Uses the Python prototype strategy: repeats current situation at
	the beginning and end to act like an automatic LOOK command.

	Now includes contextually relevant notes from personal wiki, automatically
	surfacing knowledge about the current location, present actors, and recent
	activity. Notes are intelligently deduplicated to avoid showing the same
	note multiple times.

	Now supports customization via properties:
	- "thinker.prompt_sections" (Dictionary) - override specific sections
	- "thinker.custom_commands" (Array[String]) - additional commands
	- "thinker.anti_repetition_hint" (String) - custom anti-loop text

	Args:
		context: Dictionary from _build_context() with situation info

	Returns:
		String containing the complete LLM prompt

	Notes:
		Expects LLM to respond with MOO-style: "command args | reason"
	"""
	var prompt: String = ""

	# Agent identity and personality
	prompt += "You are %s.\n\n" % context.name
	prompt += "%s\n\n" % context.profile

	# FIRST presentation: Current situation (automatic LOOK already happened)
	prompt += "You just looked around and see:\n\n"
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
	var notes_shown_in_memories: Array[String] = []  # Track notes already shown
	if context.recent_memories.size() > 0:
		prompt += "## Recent Events (what you've been doing and seeing)\n\n"
		for memory in context.recent_memories:
			var mem_dict: Dictionary = memory as Dictionary
			var content: String = mem_dict.content
			prompt += "%s\n" % content

			# Track if this memory line contains a note title (to avoid duplication later)
			if content.contains("You saved a note titled"):
				var parts: PackedStringArray = content.split("\"")
				if parts.size() >= 2:
					notes_shown_in_memories.append(parts[1])
		prompt += "\n"

	# Contextually relevant notes from personal wiki
	if context.has("relevant_notes") and context.relevant_notes.size() > 0:
		prompt += "## Relevant Notes from Your Personal Wiki\n\n"
		prompt += "These notes might be helpful for your current situation:\n\n"
		for note_data in context.relevant_notes:
			var note_dict: Dictionary = note_data as Dictionary
			var note_title: String = note_dict.get("title", "")
			var note_content: String = note_dict.get("content", "")

			# Skip notes that were recently created (already shown in memories)
			if note_title in notes_shown_in_memories:
				continue

			prompt += "**%s**\n%s\n\n" % [note_title, note_content]
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

	# Anti-repetition hints - customizable via property
	var anti_rep_hint: String = ""
	if owner.has_property("thinker.anti_repetition_hint"):
		anti_rep_hint = owner.get_property("thinker.anti_repetition_hint")
	else:
		# Default anti-repetition text
		anti_rep_hint = "IMPORTANT: You already looked around (see above). Don't look again unless something changes! "
		anti_rep_hint += "Review your recent memories to see what you did last. "
		anti_rep_hint += "If stuck or repeating yourself, try something NEW - move to a different location, "
		anti_rep_hint += "talk to someone, or examine something interesting."
	prompt += anti_rep_hint + "\n\n"

	# Available command reference - customizable via property
	prompt += "## Available Commands\n\n"
	var command_list: Array = []
	if owner.has_property("thinker.command_list"):
		command_list = owner.get_property("thinker.command_list")
	else:
		# Default command list
		command_list = [
			"go <exit>: Move to another location",
			"say <message>: Speak to others",
			"emote <action>: Perform an action",
			"examine <target>: Look at something/someone closely",
			"note <title> -> <content>: Save important information to your personal wiki",
			"recall <query>: Search your notes for relevant information",
			"dream: Review jumbled memories for new insights (when feeling stuck or curious)",
			"@my-profile: View your personality profile and think interval",
			"@my-description: View how others see you",
			"@set-profile -> <text>: Update your personality (self-modification)",
			"@set-description -> <text>: Update your appearance",
			"help [command|category]: Get help on commands (try 'help social' or 'help say')",
			"commands: List all available commands"
		]

	for cmd in command_list:
		prompt += "- %s\n" % cmd
	prompt += "\n"

	# Response format instructions
	prompt += "## Response Format\n\n"
	prompt += "Respond with a single line using MOO-style syntax:\n\n"
	prompt += "command args | reason\n\n"
	prompt += "Everything after | is your private reasoning "
	prompt += "(not visible to others, but recorded in your memory for future reference).\n\n"
	prompt += "Examples:\n"
	prompt += "- go garden | Want to explore somewhere new\n"
	prompt += "- say Hello! How are you today?\n"
	prompt += "- emote waves enthusiastically | They look friendly, making a connection\n"
	prompt += "- examine Moss | Curious about this contemplative being\n"
	prompt += "- note Moss Observations -> Contemplative being in garden, likes philosophy\n"
	prompt += "- recall skroderiders\n\n"
	prompt += "What do you want to do?\n"

	return prompt

func _on_thought_complete(response: String) -> void:
	"""Handle LLM response and execute the decided action.

	Parses the LLM response using LambdaMOO-compatible parser:
	- Handles quoted arguments: put "yellow bird" in clock
	- Supports prepositions: put bird in cage
	- Extracts reasoning: command | reason

	Args:
		response: The LLM's text response containing decision

	Notes:
		Resets is_thinking flag to allow next think cycle.
		Emits thought_completed signal after command execution.
		Uses CommandParser for consistent, robust parsing.
	"""
	is_thinking = false

	# Extract first non-empty line from response (in case LLM adds extra text)
	var command_line: String = response.strip_edges()
	var lines: PackedStringArray = command_line.split("\n")
	for line in lines:
		var trimmed: String = line.strip_edges()
		if trimmed != "" and not trimmed.begins_with("#"):
			command_line = trimmed
			break

	if command_line != "":
		# Execute the decided command through ActorComponent
		if owner.has_component("actor"):
			var actor_comp: ActorComponent = owner.get_component("actor") as ActorComponent

			# Parse command using LambdaMOO parser
			var location: WorldObject = owner.get_location()
			var parsed: CommandParser.ParsedCommand = CommandParser.parse(command_line, owner, location)

			actor_comp.execute_command(parsed.verb, parsed.args, parsed.reason)
			thought_completed.emit(command_line, parsed.reason)


func _broadcast_thinking_behavior(location: WorldObject) -> void:
	"""Broadcast observable thinking behavior to location occupants.

	Emits a subtle event indicating the agent is pondering/contemplating,
	making the async thinking process visible to other observers without
	being too spammy.

	Args:
		location: The WorldObject where the agent is located

	Notes:
		Uses EventWeaver.broadcast_to_location() to notify all actors present.
		Message is contextual - varies based on agent name/type.
	"""
	if not EventWeaver:
		return

	# Construct observable message
	var thinking_msg: String = "%s pauses, deep in thought..." % owner.name

	# Broadcast to location (others will see this)
	EventWeaver.broadcast_to_location(location, {
		"type": "observation",
		"actor": owner,
		"message": thinking_msg,
		"timestamp": Time.get_ticks_msec()
	})


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
