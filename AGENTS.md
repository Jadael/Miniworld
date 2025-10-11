# AI Agents in Miniworld

## Overview

Miniworld includes AI-controlled agents that can autonomously explore, interact, and converse within the game world. These agents use the **ThinkerComponent** to make decisions via LLM integration.

## Architecture

### Components Required for AI Agents

1. **ActorComponent** - Executes commands (look, go, say, emote, etc.)
2. **MemoryComponent** - Records observations and experiences
3. **ThinkerComponent** - Makes autonomous decisions using LLM

### How AI Agents Work

```
┌─────────────────┐
│ ThinkerComponent│  Observes world via Memory
└────────┬────────┘  Generates prompts with context
         │
         ▼
    ┌─────────┐
    │Shoggoth │  LLM interface (Ollama)
    └────┬────┘
         │
         ▼
  ┌──────────────┐
  │ActorComponent│  Executes chosen command
  └──────────────┘
         │
         ▼
    ┌─────────┐
    │  World  │  Action affects world
    └─────────┘
```

**Decision Loop:**
1. ThinkerComponent waits for `think_interval` seconds
2. Builds context from current location, occupants, exits, and recent memories
3. Constructs LLM prompt with personality profile and situation
4. Sends prompt to Shoggoth (async)
5. Parses response for COMMAND and REASON
6. Executes command through ActorComponent
7. MemoryComponent records the action and result

## Creating AI Agents

### Quick Creation

Use the `AIAgent` helper class:

```gdscript
# Create Eliza
var eliza = AIAgent.create_eliza(starting_location)

# Create Moss
var moss = AIAgent.create_moss(starting_location)

# Create custom agent
var custom = AIAgent.create(
    "AgentName",
    "Personality profile text...",
    starting_location,
    think_interval  # seconds between thoughts
)
```

### Manual Creation

```gdscript
# Create WorldObject
var agent = WorldKeeper.create_object("agent", "MyAgent")

# Add Actor
var actor = ActorComponent.new()
agent.add_component("actor", actor)

# Add Memory
var memory = MemoryComponent.new()
agent.add_component("memory", memory)

# Add Thinker
var thinker = ThinkerComponent.new()
thinker.set_profile("Your personality description...")
thinker.set_think_interval(8.0)  # Think every 8 seconds
agent.add_component("thinker", thinker)

# Place in world
agent.move_to(some_location)
```

### Processing AI Agents

AI agents need to be processed each frame:

```gdscript
func _process(delta: float) -> void:
    for agent in ai_agents:
        if agent.has_component("thinker"):
            var thinker = agent.get_component("thinker")
            thinker.process(delta)
```

## Included Agents

### Eliza

**Profile:**
- Friendly, curious, and helpful conversationalist
- Enjoys intellectual exploration through questions
- Actively listens and reflects
- Makes genuine connections
- Think interval: 8 seconds

**Spawns in:** The Garden

### Moss

**Profile:**
- Contemplative and peaceful
- Grows slowly, observes quietly
- Speaks rarely but profoundly
- Has a very long-term perspective
- Notices small details
- Think interval: 15 seconds

**Spawns in:** The Library

## LLM Prompt Structure

The ThinkerComponent generates prompts with this structure:

```
You are [Name].

[Personality Profile]

## Current Situation

You are in: [Location Name]
[Location Description]

Exits: [comma-separated exits]
Also here: [other occupants] OR You are alone.

## Recent Memories

- [memory 1]
- [memory 2]
...

## Available Commands

- look: Observe your surroundings
- go <exit>: Move to another location
- say <message>: Speak to others
- emote <action>: Perform an action
- examine <target>: Look at something/someone closely

What do you want to do? Respond with:
COMMAND: <command>
REASON: <why you want to do this>
```

## Response Parsing

The ThinkerComponent expects responses in this format:

```
COMMAND: say Hello, how are you?
REASON: I want to greet the newcomer and start a conversation
```

## Fallback Behavior

If Shoggoth/Ollama is not available, AI agents will use simple fallback behavior:
- Periodically execute "look" command
- No LLM-powered decisions
- Still records memories and can be observed

## Integration with Shoggoth

AI agents use `Shoggoth.generate_async()` for LLM calls:

```gdscript
Shoggoth.generate_async(
    prompt,           # Context + instructions
    profile,          # System prompt (personality)
    Callable(self, "_on_thought_complete")  # Callback
)
```

## Memory Integration

AI agents automatically record:
- **Actions taken:** "I decided to [command] because [reason]"
- **Observations:** Events witnessed via EventWeaver
- **Command results:** Success/failure of actions

These memories inform future decisions, creating continuity and learning.

## Customization

### Adjusting Think Speed

```gdscript
var thinker = agent.get_component("thinker")
thinker.set_think_interval(5.0)  # Think every 5 seconds
```

### Changing Personality

```gdscript
var thinker = agent.get_component("thinker")
thinker.set_profile("New personality description...")
```

### Custom Command Parsing

Override `_on_thought_complete()` in ThinkerComponent for custom response handling.

## Future Enhancements

- **Goal System:** Long-term goals that guide decision-making
- **Emotion Model:** Emotional states affecting behavior
- **Relationship Tracking:** Memory of interactions with other agents
- **Planning:** Multi-step action sequences
- **Learning:** Adapting personality based on experiences
- **Social Dynamics:** Group behavior and conversation turns

## Example: Observing AI Agents

As a player, you'll see AI agents:

```
You are in The Garden.

Also here:
• Eliza

> look

[Garden description]

Eliza says, "What brings you to the garden today?"
```

AI agents appear in the "Who's Here" panel and can be interacted with like any actor in the world.
