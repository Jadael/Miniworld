## AIAgent: Helper class for creating AI-controlled agents
##
## Creates a WorldObject with Actor, Memory, and Thinker components

class_name AIAgent

static func create(name: String, profile: String, starting_location: WorldObject = null, think_interval: float = 8.0) -> WorldObject:
	"""
	Create a new AI agent

	Args:
		name: Agent's name
		profile: Personality/behavior description
		starting_location: Where to spawn (defaults to root_room)
		think_interval: How often to think in seconds

	Returns:
		The created WorldObject with all AI components
	"""
	# Create the agent object
	var agent = WorldKeeper.create_object("agent", name)
	agent.description = "A sentient being with their own thoughts and motivations."

	# Add Actor component
	var actor_comp = ActorComponent.new()
	agent.add_component("actor", actor_comp)

	# Add Memory component
	var memory_comp = MemoryComponent.new()
	agent.add_component("memory", memory_comp)

	# Add Thinker component
	var thinker_comp = ThinkerComponent.new()
	thinker_comp.set_profile(profile)
	thinker_comp.set_think_interval(think_interval)
	agent.add_component("thinker", thinker_comp)

	# Place in world
	var location = starting_location if starting_location else WorldKeeper.root_room
	if location:
		agent.move_to(location)

	# Connect actor signals for memory recording
	actor_comp.command_executed.connect(func(cmd: String, result: Dictionary):
		if result.success:
			memory_comp.add_memory("action", "I %s: %s" % [cmd, result.message])
	)

	actor_comp.event_observed.connect(func(event: Dictionary):
		var memory_content = EventWeaver.format_event(event)
		if memory_content != "":
			memory_comp.add_memory("observed", memory_content)
	)

	# Connect thinker signal
	thinker_comp.thought_completed.connect(func(command: String, reason: String):
		memory_comp.add_memory("thought", "I decided to %s because %s" % [command, reason])
	)

	print("AI Agent created: %s (%s) at %s" % [name, agent.id, location.name if location else "void"])

	return agent

## Predefined agent profiles

static func create_eliza(starting_location: WorldObject = null) -> WorldObject:
	"""Create Eliza - a friendly, curious conversationalist"""
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
	"""Create Moss - contemplative and slow-paced"""
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
