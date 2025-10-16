# Daemons

## Purpose
Daemons are autoloaded singleton managers that provide global services to the Miniworld system. Each daemon manages a specific aspect of the world's infrastructure and is accessible from anywhere via its global name.

## Contents

### Core Daemons
- **world_keeper.gd** - Object registry and lifecycle manager, maintains ID→WorldObject mapping
- **event_weaver.gd** - Event propagation and observation system, broadcasts events to interested observers
- **shoggoth.gd** - AI/LLM interface daemon, manages Ollama client and task queue for async inference
- **markdown_vault.gd** - Persistence system, serializes/deserializes world state to Obsidian-compatible markdown
- **ollama_client.gd** - HTTP client for Ollama API, handles streaming responses and embeddings

## Daemon Responsibilities

### WorldKeeper
**Purpose**: Single source of truth for all WorldObjects in existence

**Key Functions**:
- `register_object(obj)` - Adds object to global registry
- `get_object(id)` - Retrieves object by `#123` format ID
- `get_all_objects()` - Returns all registered objects
- `get_all_rooms()` - Returns all objects with LocationComponent

**Lifecycle**: Creates and registers objects, assigns unique IDs

### EventWeaver
**Purpose**: Event propagation without tight coupling

**Key Functions**:
- `broadcast_to_location(location, event)` - Sends event to all observers in a location
- `subscribe_to_events(actor, location)` - Actor starts observing a location
- `unsubscribe_from_events(actor, location)` - Actor stops observing

**Pattern**: Observers receive events via their ActorComponent, which calls `observe_event()`

### Shoggoth
**Purpose**: AI/LLM inference abstraction layer

**Key Features**:
- **Task Queue**: FIFO queue for async LLM requests, prevents overwhelming API
- **Callback Management**: Registered callbacks invoked when tasks complete (not temporary signal connections)
- **Just-in-Time Prompts**: Accepts Callable for prompt generation, invokes fresh when ready
- **Streaming Support**: Handles Ollama's streaming responses
- **Embeddings**: Generates vector embeddings for semantic memory search

**Key Functions**:
- `generate_async(prompt, system_prompt, callback)` - Queue chat completion task
- `generate_embedding(text, callback)` - Queue embedding generation task
- `is_busy()` - Check if currently processing a task

**Pattern**: See "Daemon Callback Management (Shoggoth Pattern)" in root CLAUDE.md

### MarkdownVault
**Purpose**: World persistence to human-readable markdown files

**Key Features**:
- Saves agents as `Agent Name.md` with frontmatter metadata
- Saves rooms as `Room Name.md` with YAML frontmatter
- Loads world state on startup
- Obsidian-compatible format for human editing

**Key Functions**:
- `save_world()` - Serializes all WorldObjects to vault
- `load_world()` - Deserializes vault into WorldObjects

### OllamaClient
**Purpose**: HTTP interface to Ollama API

**Key Features**:
- Streaming chat completions
- Embedding generation
- Connection management
- Error handling

## Daemon Patterns

### Autoload Configuration
All daemons are registered in `project.godot`:
```ini
[autoload]
MarkdownVault="*res://Daemons/markdown_vault.gd"
WorldKeeper="*res://Daemons/world_keeper.gd"
EventWeaver="*res://Daemons/event_weaver.gd"
Shoggoth="*res://Daemons/shoggoth.gd"
```

The `*` prefix makes them singletons accessible globally.

### Callback Registration (Shoggoth)
Instead of temporary signal connections:
```gdscript
# ✅ CORRECT: Register callback with daemon
var pending_callbacks: Dictionary = {}  # task_id → callback

func generate_async(prompt, system_prompt, callback):
    var task_id = _create_task(prompt, system_prompt)
    pending_callbacks[task_id] = callback
    return task_id

func _emit_task_completion(result):
    if pending_callbacks.has(task_id):
        pending_callbacks[task_id].call(result)
        pending_callbacks.erase(task_id)
```

### Event Broadcasting (EventWeaver)
Decoupled observation pattern:
```gdscript
# Actor subscribes to location events
EventWeaver.subscribe_to_events(actor, location)

# Something happens, EventWeaver notifies all subscribers
EventWeaver.broadcast_to_location(location, {
    "message": "A bird chirps in the tree."
})

# ActorComponent receives via observe_event()
func observe_event(event: Dictionary):
    print(event.message)
```

## Relationship to Project

Daemons provide the **infrastructure layer** that Core and UI depend on:

- **Core/WorldObject** uses WorldKeeper for registration and ID management
- **Core/ActorComponent** uses EventWeaver for observations
- **Core/ThinkerComponent** uses Shoggoth for LLM inference
- **Core/MemoryComponent** uses Shoggoth for embeddings
- **UI/GameController** uses MarkdownVault for save/load

Daemons are **stateless services** (except for registries/caches) that can be called from anywhere without tight coupling.

## Adding New Daemons

When creating a new daemon:

1. **Extend Node** (or RefCounted if no scene tree needed)
2. **Add to project.godot** autoload section
3. **Follow singleton patterns**:
   - No instance variables for callers
   - Global functions for services
   - Callback registration for async operations
4. **Document in this CLAUDE.md**

## Maintenance Instructions
When working in this directory, maintain this CLAUDE.md file. When adding new daemons or modifying existing patterns, update both this file and the relevant sections in the root CLAUDE.md.

Follow the recursive documentation pattern described in the root CLAUDE.md.
