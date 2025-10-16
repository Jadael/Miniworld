# Miniworld Architecture

## Overview

Miniworld is a LambdaMOO-inspired multi-agent simulation built in Godot 4.4. It uses composition over inheritance, treating everything in the world as a `WorldObject` that gains capabilities through components.

## Core Philosophy

1. **Everything is an Object**: Rooms, players, AI agents, items - all are `WorldObject` instances
2. **Composition over Inheritance**: Capabilities are added via components, not class hierarchies
3. **Uniform Interaction**: Players and AI agents use the same command/verb system
4. **Event-Driven**: Actions broadcast events that observers can react to
5. **Scriptable Future**: Designed to support in-game programming (future enhancement)

## Architecture

### Core Classes

#### WorldObject (`Core/world_object.gd`)
The foundation of everything. Every entity inherits from this.

**Properties:**
- `id`: Unique identifier (MOO-style #123 format)
- `name`: Display name
- `description`: Text description
- `components`: Dictionary of attached components
- `properties`: Arbitrary data storage
- `verbs`: Callable methods (commands)
- `parent`/`contents`: Containment hierarchy

**Key Methods:**
- `add_component()` / `get_component()`: Manage components
- `call_verb()`: Execute a verb on this object
- `move_to()`: Change containment
- `get_location()`: Find which room you're in

### Daemons (Autoloaded Singletons)

#### WorldKeeper (`Daemons/world_keeper.gd`)
The object database. Manages all WorldObjects.

**Responsibilities:**
- Object registry (lookup by ID, name)
- Object lifecycle (creation/destruction)
- Global queries (find by type, location, flag, component)
- Persistence (save/load world state)

**Special Objects:**
- `#0`: The Nexus (primordial container - root of all objects)
- `#1`: Genesis Chamber (default starting room)

**Key Methods:**
- `create_object()` / `destroy_object()`
- `get_object(id)` / `find_object_by_name()`
- `create_room()` / `get_all_rooms()`
- `save_world()` / `load_world()`

#### EventWeaver (`Daemons/event_weaver.gd`)
Event propagation system. Notifies observers of actions.

**Responsibilities:**
- Broadcast events to locations
- Notify actors of observed events
- Format events as text

**Key Methods:**
- `broadcast_to_location(location, event)`
- `broadcast_to_actor(actor, event)`
- `broadcast_global(event)`

#### Shoggoth (`shoggoth.gd`)
LLM interface daemon (already exists). Handles AI inference.

**Usage:**
- Submit prompts via `submit_task()` or `submit_chat()`
- Listen for `task_completed` signal
- Backend: Ollama API (localhost:11434)

### Components

Components add capabilities to WorldObjects via composition.

#### ComponentBase (`Core/components/component_base.gd`)
Base class for all components.

**Lifecycle:**
- `_on_added(owner)`: Called when attached
- `_on_removed(owner)`: Called when detached

#### LocationComponent (`Core/components/location.gd`)
Makes an object into a room.

**Features:**
- Manages exits (connections to other rooms)
- Describes room contents
- Sets `is_room` flag

**Methods:**
- `add_exit(name, destination)` / `remove_exit(name)`
- `get_exit(name)` / `get_exits()`
- `get_contents_description()`

#### ActorComponent (`Core/components/actor.gd`)
Makes an object able to perform actions.

**Features:**
- Execute commands (look, go, say, emote, examine)
- Observe events in current location
- Track command history

**Commands:**
- `look`: Describe current location
- `go <exit>`: Move to another room
- `say <message>`: Speak to others in room
- `emote <action>`: Perform an action
- `examine <target>`: Inspect something

**Methods:**
- `execute_command(command, args)`
- `observe_event(event)`

#### MemoryComponent (`Core/components/memory.gd`)
Gives an object memory and note-taking.

**Features:**
- Records observations automatically
- Stores arbitrary memories
- Note-taking system
- Memory retrieval

**Methods:**
- `add_memory(type, content, metadata)`
- `get_recent_memories(count)`
- `add_note(title, content)` / `get_note(title)`
- `format_memories_as_text()` / `format_notes_as_text()`

## Event System

### Event Flow

1. **Actor executes command** → ActorComponent
2. **Command modifies world** → Updates objects/locations
3. **Event broadcast** → EventWeaver.broadcast_to_location()
4. **Actors observe** → ActorComponent.observe_event()
5. **Memory records** → MemoryComponent._on_event_observed()

### Event Structure

```gdscript
{
	"type": "speech" | "emote" | "action" | "movement",
	"actor": WorldObject,      # Who did it
	"location": WorldObject,   # Where it happened
	"message": String,         # Human-readable description
	# Type-specific fields...
}
```

### Event Types

- **speech**: Someone said something
- **emote**: Someone performed an action
- **action**: Generic action (look, examine)
- **movement**: Someone arrived/departed

## Creating Objects

### Basic Object
```gdscript
var obj = WorldKeeper.create_object("object", "A Thing")
obj.description = "A nondescript thing."
```

### Room
```gdscript
var room = WorldKeeper.create_room("My Room", "A cozy space.")
var loc_comp = LocationComponent.new()
room.add_component("location", loc_comp)
loc_comp.add_exit("north", other_room)
```

### Actor (Player or AI)
```gdscript
var actor = WorldKeeper.create_object("actor", "Bob")

# Add capabilities
var actor_comp = ActorComponent.new()
actor.add_component("actor", actor_comp)

var memory_comp = MemoryComponent.new()
actor.add_component("memory", memory_comp)

# Place in world
actor.move_to(room)

# Execute commands
actor_comp.execute_command("look")
actor_comp.execute_command("say", ["Hello!"])
```

## Command System

Commands are executed through the ActorComponent:

```gdscript
var actor_comp = actor.get_component("actor")
var result = actor_comp.execute_command("go", ["north"])

if result.success:
	print(result.message)
else:
	print("Error: ", result.message)
```

## Next Steps

### Immediate (Text MVP)
- [x] WorldObject and component system
- [x] Location and Actor components
- [x] Event propagation
- [x] Basic commands (look, go, say, emote)
- [x] Memory system
- [ ] Console integration for text interface
- [ ] Thinker component (AI decision-making)
- [ ] Integration with Shoggoth for AI agents

### Future Enhancements
- [ ] Visual room display (Palace-style avatars)
- [ ] In-game scripting/programming
- [ ] Verb system expansion (custom verbs)
- [ ] Object builders (@dig, @create commands)
- [ ] Permissions/ownership system
- [ ] Save/load system refinement
- [ ] Multiplayer/networking

## File Structure

```
Miniworld/
├── Core/
│   ├── world_object.gd           # Base class for everything
│   └── components/
│       ├── component_base.gd     # Base component class
│       ├── location.gd           # Room capabilities
│       ├── actor.gd              # Command execution
│       ├── memory.gd             # Memory and notes
│       └── thinker.gd            # AI decision-making (TODO)
├── Daemons/
│   ├── world_keeper.gd           # Object database
│   └── event_weaver.gd           # Event propagation
├── UI/
│   └── console_interface.gd     # Text UI (TODO)
├── Python prototype/             # Original Python implementation
├── demo_world.gd                 # Test/demo scene
├── main.tscn                     # Main scene
└── project.godot                 # Godot configuration
```

## Testing

Run `main.tscn` to see the demo:
- Creates two rooms (Lobby and Garden)
- Creates a player with Actor and Memory components
- Executes test commands
- Shows memory system working
- Displays world tree

Press SPACE to restart the demo.

## Differences from Python Prototype

| Python | Godot |
|--------|-------|
| Inheritance-based agents | Component composition |
| Dict-based locations | WorldObject + LocationComponent |
| Event bus + dispatcher | EventWeaver daemon |
| Tkinter GUI | Godot UI / Console addon |
| Markdown for storage | JSON (expandable to .tres) |
| OllamaInterface class | Shoggoth daemon |

## MOO Inspirations

- **Object #ID system**: Every object has a unique #number ID
- **Verb system**: Objects have callable methods (verbs)
- **Containment hierarchy**: Everything is in something (even rooms in the nexus)
- **Uniform objects**: No distinction between player, NPC, item at the object level
- **Properties**: Arbitrary data storage on objects
- **Future scripting**: Designed to support in-game programming

## Philosophy Notes

This architecture prioritizes:
1. **Flexibility**: Easy to add new capabilities via components
2. **Uniformity**: Same systems for all entities
3. **Extensibility**: Designed for future in-game scripting
4. **Composition**: Avoid deep inheritance trees
5. **Godot-native**: Uses Godot's strengths (signals, nodes, resources)

The goal is a foundation that can grow from text MUD to visual multiplayer world to programmable metaverse, all while maintaining the core MOO-like principles.
