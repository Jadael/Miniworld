# Miniworld

A LambdaMOO-inspired multi-agent simulation built in Godot 4.4, featuring composition-based object design and interactive text gameplay.

## Quick Start

1. **Open in Godot 4.4**
2. **Run** `game_ui.tscn` (F5)
3. **Type commands** in the input box at the bottom
4. **Explore the world!**

The game features a dedicated UI with:
- **Event Scroll** (center) - Main game output
- **Location Panel** (top right) - Current room description and exits
- **Who's Here** (bottom right) - Other characters in the room
- **Command Input** (bottom) - Type your commands here

Press **`~`** for the developer console (debugging/admin commands)

## Basic Commands

### Navigation
```
look (l)         - Look around your current location
go <exit>        - Move to another room (e.g., "go north")
where            - Show your current location
```

### Social
```
say <message>    - Speak to others in the room (or use ')
emote <action>   - Perform an action (or use :)
examine <target> - Examine something or someone (or use ex)
who              - List all characters in the world
```

### World Building
```
rooms              - List all rooms in the world
@dig <name>        - Create a new room
@exit <name> to <room> - Create an exit connecting two rooms
@teleport <room>   - Jump to any room (@tp for short)
```

**Examples:**
```
@dig The Café
@exit door to The Café
@exit door to #4
@teleport The Garden
```

## Input Controls

- **Up/Down Arrows** - Navigate command history
- **Enter** - Submit command
- **~** - Open dev console (for debugging/admin)
- **F1** - Help (planned)

## Architecture Highlights

### **MOO-Inspired Design**
- Everything is a `WorldObject` with unique `#ID`
- Composition over inheritance (components add capabilities)
- Uniform interaction (players and AI use same systems)
- Event-driven architecture

### **Core Components**
- **LocationComponent** - Makes objects into rooms with exits
- **ActorComponent** - Enables command execution
- **MemoryComponent** - Automatic event recording

### **Daemons (Singletons)**
- **WorldKeeper** - Object database and lifecycle management
- **EventWeaver** - Event propagation to observers
- **Shoggoth** - LLM interface (currently disabled, awaiting ollama_client.gd)

### **File Structure**
```
Core/
├── world_object.gd         # Base class for everything
└── components/             # Capability components
    ├── location.gd
    ├── actor.gd
    └── memory.gd

Daemons/
├── world_keeper.gd         # Object registry
└── event_weaver.gd         # Event system

UI/
├── game_ui.gd              # UI controller
└── game_ui.tscn            # UI scene layout

game_controller_ui.gd       # Game logic controller
game_ui.tscn                # Main scene
```

## AI Agents

Two AI agents are included from the Python prototype:

**Eliza** - A friendly, curious conversationalist who:
- Asks thoughtful questions and listens actively
- Seeks to learn about the world
- Makes genuine connections
- Spawns in The Garden

**Moss** - A contemplative entity who:
- Exists peacefully and observes
- Speaks rarely but profoundly
- Has a very long-term perspective
- Spawns in The Library

AI agents use the **ThinkerComponent** to make autonomous decisions via LLM (when Shoggoth/Ollama is configured).

**To enable AI agents:** See `OLLAMA_SETUP.md` for installation instructions. Once Ollama is running with a model, AI agents will think and act autonomously every 12 seconds.

## Current Status

✅ **Complete:**
- MOO-like object system
- Component composition architecture
- Text-based player interface
- Event propagation and observation
- Memory system
- Console integration
- AI agents with Thinker component (Eliza and Moss)

⏳ **Next Steps:**
- Ollama integration for LLM-powered AI decisions
- Visual room display (Palace-style)
- In-game scripting/building commands (@dig, @create)
- Multiplayer networking

## Technical Documentation

See `MINIWORLD_ARCHITECTURE.md` for detailed architecture documentation.

## Python Prototype

The `Python prototype/` folder contains the original implementation this Godot version was migrated from.

## Philosophy

**Composition over Inheritance** - Capabilities via components
**Uniform Objects** - Same systems for all entities
**Event-Driven** - Observers react to world changes
**Future-Ready** - Designed for in-game scripting and multiplayer
**MOO-Inspired** - Classic text MUD architecture with modern tools

## UI Features

**Game Interface:**
- Clean, panel-based layout
- Real-time location updates
- Dynamic occupant list
- Scrolling event history
- Command shortcuts (' for say, : for emote, l for look)

**Dev Console (~ key):**
- Full command history
- Tab autocomplete
- Script execution
- Math calculator
- Debug commands

---

*Type your first command to begin!*
