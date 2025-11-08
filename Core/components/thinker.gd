## ThinkerComponent: Enables AI agents to make autonomous decisions
##
## Uses Shoggoth (LLM interface) to:
## - Observe the world through Memory component with multi-scale context
## - Make decisions based on profile and memories
## - Execute commands through Actor component using MOO-style syntax
##
## Memory Context Engineering:
## - Uses cascading temporal summaries (Anthropic context engineering pattern)
## - Immediate window: N most recent memories in full detail
## - Recent summary: LLM-generated summary of aged-out memories
## - Long-term summary: Progressively compacted summary of all older memories
## - Provides agents with historical context beyond immediate window
##
## Anti-Repetition Features:
## - Memory deduplication: Collapses consecutive identical memories in prompt display
## - Explicit prior command: Shows last command with reasoning before "Next command:" prompt
##   (formatted exactly as they should write: single line with | separator)
## - Reasoning deduplication: Skips most recent reasoning in PRIOR REASONING section
##   (since it's shown in the prior command echo)
## - Exact repetition detection: Retries if agent generates same command+args+reason
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
## - Anti-repetition: Retries if agent generates exact same command as previous turn (prevents loops)
##   - Compares full command: verb + args + reason
##   - Up to MAX_REPETITION_RETRIES attempts (default 2)
##   - Allows intentional repetition if LLM persists after retries
## - Reasoning Display: Shows last 3 unique reasonings (most recent shown in prior command echo,
##   then 2-3 earlier reasonings in PRIOR REASONING section; duplicates auto-filtered to prevent pattern learning)

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

## Last command executed (for detecting exact repetition)
## Format: "verb args|reason" - compared to prevent unintended loops
var last_command_full: String = ""

## Retry counter for when agent repeats exact same command
var repetition_retry_count: int = 0

## Maximum retries when agent repeats exact same command
const MAX_REPETITION_RETRIES: int = 2

## Task ID for pending LLM request (used for training data collection)
var _pending_training_task_id: String = ""

## Last prompt used (captured for training data)
var _last_prompt: String = ""


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
		# 3. Captures the prompt for training data collection
		var prompt_generator: Callable = func() -> String:
			# This runs just-in-time when Shoggoth is ready - broadcast NOW
			var current_location: WorldObject = owner.get_location()
			_broadcast_thinking_behavior(current_location)

			# Now build fresh context and prompt
			var fresh_context: Dictionary = _build_context()
			var prompt: String = _construct_prompt(fresh_context)

			# Capture prompt for training data (stored in component)
			_last_prompt = prompt

			return prompt

		# Generate task and capture task_id for training data collection
		var task_id: String = Shoggoth.generate_async(prompt_generator, get_profile(), Callable(self, "_on_thought_complete"))

		# Store task_id for training data collection
		_pending_training_task_id = task_id
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

	# Retrieve recent memories with multi-scale context if available
	if owner.has_component("memory"):
		var memory_comp: MemoryComponent = owner.get_component("memory") as MemoryComponent

		# Get memories with cascading temporal summaries
		# Using 64 immediate memories to provide rich context for decision-making
		var memory_context: Dictionary = memory_comp.get_recent_context(64)
		context.recent_memories = memory_context.immediate
		context.recent_summary = memory_context.recent_summary
		context.longterm_summary = memory_context.longterm_summary
		context.has_summaries = memory_context.has_summaries

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

		# Get relevant memory summaries (experiential history from RAG)
		context.relevant_summaries = memory_comp.get_relevant_summaries_for_context(
			context.location_name,
			occupants_typed,
			"",  # no recent_events context for now
			2  # max 2 relevant summaries
		)

		# Get recent reasonings to display separately from memories
		# Request 4 (one extra) since we'll skip the most recent if shown in prior command
		# Duplicates are automatically filtered
		context.recent_reasonings = memory_comp.get_recent_reasonings(4)
	else:
		context.recent_memories = []
		context.recent_summary = ""
		context.longterm_summary = ""
		context.has_summaries = false
		context.relevant_notes = []
		context.relevant_summaries = []
		context.recent_reasonings = []

	return context

func _construct_prompt(context: Dictionary) -> String:
	"""Construct LLM prompt from context.

	Builds a structured prompt optimized for both base models and instruct models:

	1. Identity & Profile (system context)
	2. Command List & Format Instructions
	3. Relevant Notes (from personal wiki)
	4. Multi-Scale Memory Context:
	   - Long-term summary (oldest compressed memories)
	   - Recent summary (memories outside immediate window)
	   - Recent transcript (immediate memories in full detail)
	5. Current Situation (minimal summary)
	6. Command Prompt ("> " - triggers command generation)

	The transcript placement is KEY for base models: by putting it immediately
	before the command prompt, recent events show the model what happens and the
	outcomes of actions. Successful commands show only narrative results (not echoed
	commands) to prevent pattern replication. Failed commands show full context
	(what was attempted, why it failed, suggestions). Summaries provide historical
	context without overwhelming the attention budget.

	Args:
		context: Dictionary from _build_context() with situation info and memory summaries

	Returns:
		String containing the complete LLM prompt

	Notes:
		Expects LLM to respond with MOO-style: "command args | reason"
		Uses cascading temporal summaries (Anthropic context engineering pattern)
		The transcript-before-prompt structure is optimized for base models
		while remaining effective for instruct/chat models.
	"""
	var prompt: String = ""

	# Agent identity and personality (character context)
	prompt += "CURRENT SITUATION:\n"
	prompt += "You are %s in %s. " % [context.name, context.location_name]
	prompt += "%s\n\n" % context.profile
	if context.occupants.size() > 0:
		prompt += "Also here: %s\n" % ", ".join(context.occupants)
	else:
		prompt += "You are alone here.\n"

	# Available command reference early for context
	prompt += "BASIC COMMANDS:\n"
	prompt += "(Your response must start with a valid command keyword.)\n"
	var command_list: Array = []
	if owner.has_property("thinker.command_list"):
		command_list = owner.get_property("thinker.command_list")
	else:
		# Default command list
		command_list = [
			"GO <exit> | <reasoning>: Move to another location",
			"SAY <message> | <reasoning>: Speak to others",
			"THINK <reasoning>: Pass your 'turn', reason privately without taking action",
			"NOTE <title> -> <content>: Save important information to your personal wiki",
			"RECALL <query> | <reasoning>: Search your notes for relevant information",
			"DREAM | <reasoning>: Review jumbled memories for new insights (when feeling stuck or curious)",
			"HELP [command|category]: Get help on commands (try 'HELP SOCIAL' or 'HELP MEMORY')",
			"(Text after the | is private and visible only to you; use this space to explain your goal, expected result, and potential follow ups.)"
		]

	for cmd in command_list:
		prompt += "- %s\n" % cmd
	prompt += "\n"

	# Response format instructions
	prompt += "EXAMPLE:\n\n"
	#prompt += "go garden | Want to explore somewhere new.\n"
	prompt += "say Hello! How are you today? | Greeting them before I wait for a resposne.\n"
	#prompt += "emote waves enthusiastically | They look friendly, making a connection.\n"
	#prompt += "think I should wait for a bit and see what they say.\n"
	#prompt += "note Goal -> I want to...\n\n"
	#prompt += "help\n\n"
	#prompt += "(Everything after the | is private and visible only to you.)\n\n"

	# Contextually relevant notes from personal wiki (before transcript for context)
	var notes_shown_in_memories: Array[String] = []  # Track notes already shown
	if context.has("relevant_notes") and context.relevant_notes.size() > 0:
		prompt += "POTENTIALLY RELATED PRIVATE NOTES:\n\n"
		for note_data in context.relevant_notes:
			var note_dict: Dictionary = note_data as Dictionary
			var note_title: String = note_dict.get("title", "")
			var note_content: String = note_dict.get("content", "")
			prompt += "- %s: %s\n" % [note_title, note_content]
			notes_shown_in_memories.append(note_title)
		prompt += "\n"

	# Relevant memory summaries from RAG (experiential context)
	if context.has("relevant_summaries") and context.relevant_summaries.size() > 0:
		prompt += "RELATED PAST EXPERIENCES:\n\n"
		for summary_data in context.relevant_summaries:
			var summary_dict: Dictionary = summary_data as Dictionary
			var summary_text: String = summary_dict.get("summary_text", "")
			var memory_range: String = summary_dict.get("memory_range", "")
			prompt += "- %s (%s)\n" % [summary_text, memory_range]
		prompt += "\n"

	# Multi-scale memory context (cascading temporal summaries)
	# Long-term summary (oldest compressed memories)
	if context.has("longterm_summary") and context.longterm_summary != "":
		prompt += "LONG TERM MEMORY SUMMARY\n\n"
		prompt += "%s\n\n" % context.longterm_summary

	# Recent summary (memories that aged out of immediate window)
	if context.has("recent_summary") and context.recent_summary != "":
		prompt += "SHORT TERM MEMORY SUMMARY:\n\n"
		prompt += "%s\n\n" % context.recent_summary

	# Recent observations from memory - Shows narrative results only, not command echoes
	# This goes LAST, so that base models continue it naturally
	# Separating commands from narrative results helps smaller models avoid echo/pattern reinforcement
	# Memory deduplication: Collapse consecutive identical memories to prevent pattern reinforcement
	if context.recent_memories.size() > 0:
		prompt += "MOST RECENT MEMORIES:\n\n"

		var last_content: String = ""
		var repeat_count: int = 0

		for i in range(context.recent_memories.size()):
			var memory: Dictionary = context.recent_memories[i]
			var mem_dict: Dictionary = memory as Dictionary
			var content: String = mem_dict.content
			var metadata: Dictionary = mem_dict.get("metadata", {})
			var is_failed: bool = metadata.get("is_failed", false)

			# For failed commands, show the enhanced explanation (includes context of failure)
			# For successful commands, show only the narrative result (not the command echo)
			# This prevents the model from learning to echo previous patterns
			var display_content: String = content

			# Check for consecutive repetition
			if content == last_content and not is_failed:
				repeat_count += 1
				# Skip displaying - will show count at end
				continue
			else:
				# Display any pending repetition summary
				if repeat_count > 0:
					prompt += " (repeated %dx more)\n" % repeat_count
					repeat_count = 0

				# Display current memory
				prompt += "%s\n" % display_content
				last_content = content

			# Track note titles to avoid duplication
			if content.contains("You saved a note titled"):
				var parts: PackedStringArray = content.split("\"")
				if parts.size() >= 2:
					notes_shown_in_memories.append(parts[1])

		# Handle any trailing repetition
		if repeat_count > 0:
			prompt += " (repeated %dx more)\n" % repeat_count

	# Recent reasonings - show agent's thought process separately from narrative
	# Skip the most recent one if it's being shown in the "prior command" echo below
	if context.has("recent_reasonings") and context.recent_reasonings.size() > 0:
		var reasonings_to_show: Array[String] = []

		# Check if we'll be showing the most recent reasoning in the prior command
		var will_show_in_prior: bool = false
		if owner and owner.has_component("actor"):
			var actor_comp: ActorComponent = owner.get_component("actor") as ActorComponent
			if actor_comp and actor_comp.last_reason != "":
				will_show_in_prior = true

		# If showing in prior command, skip the first reasoning (most recent)
		var start_idx: int = 1 if will_show_in_prior else 0
		for i in range(start_idx, context.recent_reasonings.size()):
			reasonings_to_show.append(context.recent_reasonings[i])

		# Only show section if we have reasonings to display
		if reasonings_to_show.size() > 0:
			prompt += "\nPRIOR REASONING:\n\n"
			for reasoning in reasonings_to_show:
				prompt += "- %s\n" % reasoning
			prompt += "\n"
	prompt += "-------------\n"
	prompt += "CURRENT SITUATION:\n"
	# FINAL: Current situation summary (minimal, right before command prompt)
	prompt += "You are %s in %s. " % [context.name, context.location_name]
	prompt += "%s\n" % context.location_description
#
	## Exits and occupants
	prompt += "Exits: "
	if context.exits.size() > 0:
		prompt += ", ".join(context.exits) + "\n"
	else:
		prompt += "none\n"

	if context.occupants.size() > 0:
		prompt += "Also here: %s\n" % ", ".join(context.occupants)
	else:
		prompt += "You are alone here.\n"

	# Command prompt line for base models (hints next token prediction to favor a command)
	# Show prior command explicitly to reinforce "do not repeat" instruction

	prompt += "Now that you are caught up, what do you do next? Consider what you've already done, what happened, and what you want to achieve next. Use reasoning after | to explain your goal, possible outcomes, and potential follow up based on different outcomes as a hint to your future self. Do not repeat your prior command.\n\n"

	# Display last command if available (helps models avoid repetition)
	# Format: single line with reasoning after | (exactly as they should write it)
	if owner and owner.has_component("actor"):
		var actor_comp: ActorComponent = owner.get_component("actor") as ActorComponent
		if actor_comp and actor_comp.last_command != "":
			var prior_cmd: String = actor_comp.last_command
			if actor_comp.last_reason != "":
				prior_cmd += " | %s" % actor_comp.last_reason
			prompt += "PRIOR command and reasoning:\n>%s\n\n" % prior_cmd

	prompt += "NEXT command and reasoning as %s:\n" % context.name
	prompt += ">"

	return prompt

func _on_thought_complete(result: Variant) -> void:
	"""Handle LLM response and execute the decided action.

	Parses the LLM response using LambdaMOO-compatible parser:
	- Handles quoted arguments: put "yellow bird" in clock
	- Supports prepositions: put bird in cage
	- Extracts reasoning: command | reason

	For reasoning models (like qwen3, deepseek-r1), the result Dictionary contains both
	content (the command) and thinking (chain-of-thought reasoning). The thinking
	content is logged but NOT stored as a memory, since it's implementation detail
	that varies between models/prompts, not in-character thought.

	Anti-Repetition Logic:
	If the agent generates EXACTLY the same command (verb + args + reason) as
	the previous turn, triggers an immediate retry (up to MAX_REPETITION_RETRIES).
	This prevents unintended loops while allowing intentional repetitive behavior
	(e.g., if LLM deliberately repeats after max retries, it's allowed).

	Args:
		result: Either a String (legacy) or Dictionary with:
			- content: String - The command to execute
			- thinking: String - Optional chain-of-thought reasoning from reasoning models

	Notes:
		Resets is_thinking flag to allow next think cycle.
		Emits thought_completed signal after command execution.
		Uses CommandParser for consistent, robust parsing.
		Stores thinking content in memory if present (makes COT visible in agent's history).
		Detects exact repetition and retries to encourage varied behavior.
	"""
	is_thinking = false

	# Handle both legacy String format and new Dictionary format
	var response: String = ""
	var thinking: String = ""

	if result is Dictionary:
		response = result.get("content", "")
		thinking = result.get("thinking", "")
		# Note: Chain-of-thought reasoning is not stored as a memory
		# It's implementation detail (how the model arrived at the decision),
		# not in-character thought. Different models/prompts produce different reasoning,
		# so storing it would clutter narrative history with meta information.
		if thinking != "":
			print("[Thinker] %s generated %d chars of CoT reasoning (not stored as memory)" % [owner.name, thinking.length()])
	elif result is String:
		response = result
	else:
		push_error("[Thinker] Invalid result type: %s" % typeof(result))
		return

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

			# Build full command string for comparison (verb + args + reason)
			var args_str: String = " ".join(parsed.args) if parsed.args.size() > 0 else ""
			var current_command_full: String = "%s %s|%s" % [parsed.verb, args_str, parsed.reason]

			# Check if this is EXACTLY the same as the last command
			if current_command_full == last_command_full and last_command_full != "":
				# Exact repetition detected!
				repetition_retry_count += 1
				print("[Thinker] %s repeated exact same command (%d/%d): %s" % [
					owner.name,
					repetition_retry_count,
					MAX_REPETITION_RETRIES,
					current_command_full
				])

				if repetition_retry_count <= MAX_REPETITION_RETRIES:
					# Try thinking again immediately
					print("[Thinker] %s retrying with fresh thought..." % owner.name)
					is_thinking = false
					think_timer = 0.0  # Think again immediately
					return  # Skip execution, wait for next think cycle
				else:
					# Max retries reached, let it execute (probably intentional repetition)
					print("[Thinker] %s max retries reached, allowing repetition" % owner.name)
					repetition_retry_count = 0  # Reset for next time
			else:
				# Different command, reset retry counter
				repetition_retry_count = 0

			# Store this command for next comparison
			last_command_full = current_command_full

			# Capture training data if TrainingDataCollector is available
			if _last_prompt != "" and _pending_training_task_id != "" and TrainingDataCollector:
				TrainingDataCollector.capture_prompt_and_command(owner, _last_prompt, command_line, _pending_training_task_id)

			# Execute the command (pass task_id for training data collection)
			actor_comp.execute_command(parsed.verb, parsed.args, parsed.reason, _pending_training_task_id)
			thought_completed.emit(command_line, parsed.reason)

			# Clear pending training data after execution
			_pending_training_task_id = ""
			_last_prompt = ""


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
		Uses "ambient" event type so it's visible to players but NOT recorded
		in AI agent memories (doesn't add useful context to prompts).
	"""
	if not EventWeaver:
		return

	# Construct observable message
	var thinking_msg: String = "%s pauses, deep in thought..." % owner.name

	# Broadcast to location (visible to players, but not stored in AI memories)
	EventWeaver.broadcast_to_location(location, {
		"type": "ambient",  # Ambient events are visible but not memorable
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
