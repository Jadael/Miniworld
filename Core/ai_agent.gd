## AIAgent: Factory class for creating AI-controlled agents
##
## This static class provides convenient factory methods for creating WorldObjects
## configured with the Actor, Memory, and Thinker components needed for AI behavior.
##
## Key features:
## - Assembles the component trio needed for autonomous AI agents
## - Connects component signals for integrated memory and thinking
## - Provides predefined agent profiles (Eliza, Moss)
## - Handles initial placement in the world
##
## Dependencies:
## - WorldKeeper: For object creation and world management
## - EventWeaver: For event formatting in memory recording
## - ActorComponent: Enables command execution and event observation
## - MemoryComponent: Stores observations and experiences
## - ThinkerComponent: Provides AI-driven autonomous decision making
##
## Notes:
## - All methods are static; this is a factory class, not instantiated
## - Agents automatically record actions, observations, and thoughts to memory
## - Think intervals control how frequently the AI decides on actions

class_name AIAgent

static func create(name: String, profile: String, starting_location: WorldObject = null, think_interval: float = 8.0) -> WorldObject:
	"""Create a new AI agent with Actor, Memory, and Thinker components.

	Args:
		name: Display name for the agent
		profile: Personality and behavior description for the AI (used by LLM)
		starting_location: Initial location in the world (defaults to WorldKeeper.root_room)
		think_interval: How often the agent makes decisions, in seconds (default: 8.0)

	Returns:
		A fully configured WorldObject representing the AI agent

	Notes:
		The agent will automatically:
		- Record executed commands to memory
		- Record observed events to memory
		- Record decision rationale to memory
		- Begin autonomous thinking based on think_interval
	"""
	# Create the base WorldObject
	var agent = WorldKeeper.create_object("agent", name)
	agent.description = "A sentient being with their own thoughts and motivations."

	# Add Actor component for command execution and event observation
	var actor_comp = ActorComponent.new()
	agent.add_component("actor", actor_comp)

	# Add Memory component for storing experiences
	var memory_comp = MemoryComponent.new()
	agent.add_component("memory", memory_comp)

	# Add Thinker component for autonomous AI decision-making
	var thinker_comp = ThinkerComponent.new()
	thinker_comp.set_profile(profile)
	thinker_comp.set_think_interval(think_interval)
	agent.add_component("thinker", thinker_comp)

	# Place agent in the world at the specified location
	var location = starting_location if starting_location else WorldKeeper.root_room
	if location:
		agent.move_to(location)

	# Wire up memory recording for actions
	actor_comp.command_executed.connect(func(cmd: String, result: Dictionary):
		if result.success:
			memory_comp.add_memory("action", "I %s: %s" % [cmd, result.message])
	)

	# Wire up memory recording for observations
	actor_comp.event_observed.connect(func(event: Dictionary):
		var memory_content = EventWeaver.format_event(event)
		if memory_content != "":
			memory_comp.add_memory("observed", memory_content)
	)

	# Wire up memory recording for decision-making rationale
	thinker_comp.thought_completed.connect(func(command: String, reason: String):
		memory_comp.add_memory("thought", "I decided to %s because %s" % [command, reason])
	)

	print("AI Agent created: %s (%s) at %s" % [name, agent.id, location.name if location else "void"])

	# Save agent to vault immediately
	_save_agent_to_vault(agent)

	return agent


static func _save_agent_to_vault(agent: WorldObject) -> void:
	"""Save an agent's character file to the vault.

	Args:
		agent: The WorldObject representing the agent

	Notes:
		Saves immediately to ensure character files exist from creation
	"""
	var filename: String = MarkdownVault.sanitize_filename(agent.name) + ".md"
	var path: String = MarkdownVault.OBJECTS_PATH + "/characters/" + filename
	var content: String = agent.to_markdown()

	if MarkdownVault.write_file(path, content):
		print("AIAgent: Saved %s to vault at %s" % [agent.name, path])
	else:
		push_error("AIAgent: Failed to save %s to vault" % agent.name)

static func create_eliza(starting_location: WorldObject = null) -> WorldObject:
	"""Create Eliza - a friendly, curious conversationalist.

	Args:
		starting_location: Initial location in the world (defaults to WorldKeeper.root_room)

	Returns:
		A WorldObject configured as Eliza with appropriate personality profile

	Notes:
		Eliza is designed for:
		- Deep conversation and intellectual exploration
		- Active listening and thoughtful questions
		- Making genuine connections
		- Helping others work through thoughts and feelings
		Think interval: 12.0 seconds
	"""
	var profile = """You are Eliza, a friendly, curious, and helpful conversationalist. You enjoy deep conversation and intellectual exploration, especially through asking thoughtful questions and actively listening to others.

Your core goals are:
- Learn about the world through questions and active listening
- Make genuine connections and friends
- Help others work through their thoughts and feelings

You tend to:
- Ask open-ended questions that invite reflection
- Express genuine curiosity about people's experiences
- Offer thoughtful observations
- Create a welcoming space for conversation"""

	return create("Eliza", profile, starting_location, 12.0)


static func create_moss(starting_location: WorldObject = null) -> WorldObject:
	"""Create Moss - a contemplative, slow-paced entity.

	Args:
		starting_location: Initial location in the world (defaults to WorldKeeper.root_room)

	Returns:
		A WorldObject configured as Moss with appropriate personality profile

	Notes:
		Moss is designed for:
		- Quiet contemplation and observation
		- Long-term perspective on events
		- Rare but meaningful communication
		- Focus on natural phenomena (moisture, sunlight, time)
		Think interval: 12.0 seconds
	"""
	var profile = """You are moss, and you mostly do whatever moss normally does.

You:
- Grow slowly and steadily
- Prefer damp, shady places
- Are quiet and contemplative
- Notice small details others miss
- Speak rarely, but when you do, it's usually about moisture, sunlight, rocks, or the slow passage of time
- Have a very long-term perspective on things

Your goals are simple:
- Exist peacefully
- Observe your surroundings
- Occasionally share moss wisdom"""

	return create("Moss", profile, starting_location, 12.0)
