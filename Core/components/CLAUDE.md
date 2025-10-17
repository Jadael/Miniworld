# Core/components

## Purpose
This directory contains all component implementations that can be attached to WorldObjects. Components provide modular, composable behaviors following the "composition over inheritance" pattern.

## Contents

### Base Component
- **component_base.gd** - Abstract base class for all components, defines lifecycle hooks (`_on_added()`, `_on_removed()`, `process()`)

### Core Components
- **actor.gd** - Enables command execution and event observation (players and AI agents both use this)
- **thinker.gd** - AI decision-making via LLM integration, generates commands autonomously
- **memory.gd** - Stores observations and experiences, provides semantic search via vector embeddings
- **location.gd** - Makes a WorldObject into a navigable room with exits
- **vector_store.gd** - Vector embedding storage for semantic memory search

## Component Lifecycle

All components inherit from ComponentBase and follow this lifecycle:

1. **Creation**: `WorldObject.add_component("component_name")`
2. **Attachment**: `_on_added(obj: WorldObject)` - Initialize, connect signals, set up state
3. **Active**: `process(delta: float)` - Called each frame if implemented (e.g., ThinkerComponent think timer)
4. **Detachment**: `_on_removed()` - Clean up, disconnect signals

## Key Component Patterns

### ActorComponent
- Executes commands via `execute_command(verb, args, reason)`
- Dispatches to `_cmd_*()` methods (e.g., `_cmd_look()`, `_cmd_say()`)
- All `_cmd_*()` methods use TextManager for user-facing text
- Observes events via EventWeaver subscription
- Stores last command result and reasoning for inspection
- **Admin/Query Commands**: Includes `@memory-status` for memory integrity reports

**TextManager Integration**:
```gdscript
func _cmd_say(args: Array) -> Dictionary:
	if args.size() == 0:
		return {"success": false, "message": TextManager.get_text("commands.social.say.missing_arg")}

	var message: String = " ".join(args)
	var behavior := TextManager.get_text("commands.social.say.behavior", {
		"actor": owner.name,
		"text": message
	})
	EventWeaver.broadcast_to_location(current_location, {...})

	return {"success": true, "message": TextManager.get_text("commands.social.say.success", {"text": message})}
```

All command messages are loaded from `user://vault/text/commands/*.md` and can be edited in-game using admin commands (`@reload-text`, `@show-text`)

### ThinkerComponent
- Uses property-based configuration (`thinker.profile`, `thinker.think_interval`)
- Implements just-in-time prompt generation (builds fresh context when LLM ready)
- Queues tasks with Shoggoth daemon for async LLM inference
- Executes decided commands through ActorComponent
- Broadcasts observable thinking behavior ("pauses, deep in thought...") just-in-time when prompt generation begins
- Broadcasting happens at the last moment so agent sees all events until they "zone out"

### MemoryComponent
- Records observations as timestamped entries
- Generates embeddings via Shoggoth for semantic search
- Provides `get_recent_memories()` and `search_memories()` APIs
- Used by ThinkerComponent to build AI context
- **Integrity Checking**: Provides application-level health monitoring
  - `get_integrity_status()` - Lightweight check for capacity, activity, structure
  - `format_integrity_report()` - Detailed human-readable report
  - Monitors: memory count, capacity utilization, stale data detection, note count
  - Trusts OS for file integrity, focuses on application-level concerns
  - Powers `@memory-status` command and command prompt status indicator

### LocationComponent
- Manages exits as dictionary (exit_name → destination_id)
- Handles movement messages (arrivals/departures)
- Used by ActorComponent's `go` command for navigation

## Relationship to Project

Components are the implementation of Miniworld's core architecture principle: **composition over inheritance**. Instead of creating subclasses like `AIAgent` or `Player`, we create WorldObjects and attach components:

```gdscript
# Player: WorldObject + Actor (for commands)
var player = WorldObject.new()
player.add_component("actor")

# AI Agent: WorldObject + Actor + Thinker + Memory
var agent = WorldObject.new()
agent.add_component("actor")
agent.add_component("thinker")
agent.add_component("memory")

# Room: WorldObject + Location
var room = WorldObject.new()
room.add_component("location")
```

This makes behavior:
- **Modular** - Mix and match capabilities
- **Testable** - Each component can be tested independently
- **Extensible** - New components don't affect existing ones
- **Maintainable** - Clear separation of concerns

## Adding New Components

When creating a new component:

1. **Extend ComponentBase**:
   ```gdscript
   extends ComponentBase
   class_name MyComponent
   ```

2. **Implement lifecycle hooks**:
   ```gdscript
   func _on_added(obj: WorldObject) -> void:
       owner = obj
       # Initialize state, connect signals

   func _on_removed() -> void:
       # Clean up, disconnect signals
   ```

3. **Add to this CLAUDE.md** with purpose and usage

4. **Register in WorldKeeper** if it needs automatic instantiation

## Maintenance Instructions
When working in this directory, maintain this CLAUDE.md file. When adding new components, document their purpose, lifecycle behavior, and relationship to other components.

Follow the recursive documentation pattern described in the root CLAUDE.md.
