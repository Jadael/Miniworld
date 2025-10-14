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

### Mental Commands
```
think <thought>          - Record internal reasoning/observations (private)
dream                    - Review mixed memories for insights (AI-powered)
note <title> -> <content> - Create persistent notes in personal wiki
recall <query>           - Search notes semantically for information
```

### World Building
```
rooms              - List all rooms in the world
@dig <name>        - Create a new room
@exit <name> to <room> - Create an exit connecting two rooms
@teleport <room>   - Jump to any room or character's location (@tp for short)
@save              - Save world state to markdown vault
@impersonate <agent> - See game from AI agent's perspective (debug)
```

**Examples:**
```
@dig The Café
@exit door to The Café
@exit door to #4
@teleport The Garden
@tp Eliza
note Moss Observations -> Contemplative being, likes philosophy
recall skroderiders
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
- **ActorComponent** - Enables command execution with optional reasoning
- **MemoryComponent** - Automatic event recording with markdown vault persistence
- **ThinkerComponent** - AI-powered autonomous decision-making for agents
- **VectorStoreComponent** - Semantic search and note-taking capabilities

### **Daemons (Singletons)**
- **WorldKeeper** - Object database, lifecycle management, and markdown vault persistence
- **EventWeaver** - Event propagation to observers
- **Shoggoth** - LLM interface with task queue management (Ollama backend)
- **MarkdownVault** - Persistent storage of world state and agent notes

### **File Structure**
```
Core/
├── world_object.gd         # Base class for everything
├── ai_agent.gd             # Helper class for creating AI agents
└── components/             # Capability components
    ├── component_base.gd   # Base class for all components
    ├── location.gd         # Rooms and exits
    ├── actor.gd            # Command execution
    ├── memory.gd           # Event recording and notes
    ├── thinker.gd          # AI decision-making
    └── vector_store.gd     # Semantic search

Daemons/
├── world_keeper.gd         # Object registry and persistence
├── event_weaver.gd         # Event propagation system
├── markdown_vault.gd       # Persistent storage layer
└── ollama_client.gd        # Ollama API integration

UI/
├── game_ui.gd              # UI controller
├── game_ui.tscn            # UI scene layout
└── shoggoth_settings.gd    # LLM configuration UI

shoggoth.gd                 # LLM interface daemon
game_controller_ui.gd       # Game logic controller
demo_world.gd               # World initialization
```

## AI Agents

Two AI agents are included from the Python prototype:

**Eliza** - A friendly, curious conversationalist who:
- Asks thoughtful questions and listens actively
- Seeks to learn about the world
- Makes genuine connections
- Spawns in The Garden
- Thinks every 8 seconds

**Moss** - A contemplative entity who:
- Exists peacefully and observes
- Speaks rarely but profoundly
- Has a very long-term perspective
- Spawns in The Library
- Thinks every 15 seconds

AI agents use the **ThinkerComponent** with **just-in-time prompt generation** to make autonomous decisions via LLM. This ensures agents always have the freshest memories and observations when making decisions, even if their task has been queued for several seconds.

**To enable AI agents:** See `OLLAMA_SETUP.md` for installation instructions. Once Ollama is running with a model (default: `gemma3:4b`), AI agents will think and act autonomously. Use the `@impersonate <agent>` command to see exactly what an agent perceives and what prompt they receive.

**Command Syntax:** Both players and AI agents use unified MOO-style command syntax: `command args | reason`. Everything after the `|` is optional reasoning that's recorded in memory but not visible to other actors. See `AGENTS.md` for detailed documentation.

## Current Status

✅ **Complete:**
- MOO-like object system with composition-based components
- Text-based player interface with dedicated UI panels
- Event propagation and observation system (EventWeaver)
- Memory system with markdown vault persistence
- AI agents with ThinkerComponent (Eliza and Moss)
- Ollama integration for LLM-powered AI decisions
- Just-in-time prompt generation for AI agents
- MOO-style command syntax with optional reasoning (`command | reason`)
- Mental commands (think, dream, note, recall)
- Semantic search over notes via vector embeddings
- World building commands (@dig, @exit, @teleport)
- World persistence to markdown files (@save)
- Debug tools (@impersonate to view AI perspective)
- Console integration for debugging

⏳ **In Progress:**
- Observer messages for "private" verbs (think, dream, note, recall)
- Improved AI behavior patterns to reduce repetition

🔮 **Future Ideas:**
- Visual room display (Palace-style or isometric)
- In-game scripting language for custom object behaviors
- Multiplayer networking
- Permission system (ownership, private rooms)
- More sophisticated AI goal/planning systems
- Relationship tracking and social dynamics

## Technical Documentation

- **`MINIWORLD_ARCHITECTURE.md`** - Detailed architecture documentation
- **`AGENTS.md`** - AI agent system and ThinkerComponent documentation
- **`BUILDING.md`** - World building guide with @dig, @exit, @teleport commands
- **`OLLAMA_SETUP.md`** - Instructions for setting up Ollama LLM backend
- **`CLAUDE.md`** - Development standards and patterns for contributors
- **`VAULT_STRUCTURE.md`** - Markdown vault persistence format
- **`PERSISTENCE_IMPLEMENTATION.md`** - Technical details of save/load system

## Python Prototype

The `Python prototype/` folder contains the original implementation this Godot version was migrated from.

## Philosophy

**Composition over Inheritance** - Capabilities via components, not class hierarchies
**Uniform Objects** - Players and AI agents use the same systems and commands
**Event-Driven** - Observers react to world changes through EventWeaver
**MOO-Inspired** - Classic text MUD architecture with modern AI and persistence
**Transparent AI** - Debug tools to understand what AI agents see and think
**Just-in-Time Context** - AI agents get fresh prompts with latest memories
**Persistent World** - Everything saved to readable markdown files
**Player-Built Worlds** - Everyone can shape the world with building commands

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

## Key Features Deep Dive

### MOO-Style Command Syntax with Reasoning

Both players and AI use the same command format: `command args | reason`

```
say Hello there! | Trying to make a connection
go garden | Want to find a quiet place to think
note Important Insight -> The skroderiders represent community memory
```

Everything after `|` is **private reasoning** - recorded in your memory but not visible to other actors. This allows AI agents to maintain internal decision-making logs that inform future choices.

### Just-in-Time Prompt Generation

When AI agents queue LLM requests, their prompts aren't built immediately. Instead, they pass a **callable** (function) that Shoggoth invokes just before execution. This ensures agents always have the most recent memories and observations, even if their task waited in queue for several seconds.

### Semantic Note System

The `note` and `recall` commands use **vector embeddings** to create a personal wiki with semantic search:

```
note Moss Observations -> Contemplative being in library, likes philosophy
recall philosophy
# Finds the Moss note even though you searched for "philosophy" not "Moss"
```

Notes are stored in markdown files with metadata and indexed using Ollama's embedding models.

### Persistent World State

The `@save` command persists the entire world to markdown files:
- Each WorldObject becomes a markdown file with YAML frontmatter
- Component data stored as structured metadata
- Human-readable and git-friendly
- Can be edited externally and reloaded

### AI Agent Introspection

Use `@impersonate <agent>` to see exactly what an AI agent perceives:
- Current location and surroundings
- Recent memories and observations
- Full LLM prompt with instructions
- Available commands and context

Perfect for debugging why agents make certain decisions.

---

*Type your first command to begin! Try `look` or `who` to get started.*
