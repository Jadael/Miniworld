# Miniworld Vault Structure

## Overview
Miniworld uses a markdown-based vault structure for all persistent data. This allows the admin to view and edit the world using Obsidian or any text editor, providing a "Dungeon Master" view of the entire world state.

## Directory Structure

```
vault/                          # Root of the Obsidian-compatible vault
├── .obsidian/                  # Obsidian workspace settings (optional)
├── world/                      # World structure and state
│   ├── locations/              # Individual location files
│   │   ├── The Lobby.md
│   │   ├── The Garden.md
│   │   └── The Library.md
│   ├── objects/                # WorldObject definitions
│   │   ├── characters/         # Character objects
│   │   └── items/              # Item objects
│   └── world_state.md          # Current world state snapshot
├── agents/                     # AI agent data
│   ├── Eliza/
│   │   ├── agent.md            # Agent configuration
│   │   ├── memories/           # Memory files
│   │   │   ├── 20250312-143022-observed.md
│   │   │   └── 20250312-143045-action.md
│   │   └── notes/              # Agent notes
│   │       └── conversation-patterns.md
│   └── Moss/
│       ├── agent.md
│       ├── memories/
│       └── notes/
├── templates/                  # Markdown templates
│   ├── location_template.md
│   ├── character_template.md
│   └── object_template.md
└── config/                     # System configuration
    ├── shoggoth.md             # Shoggoth/LLM config
    └── world_settings.md       # World rules and settings
```

## File Formats

### Location File (`world/locations/<name>.md`)
```markdown
---
object_id: location_123
type: location
created: 2025-03-12T14:30:00Z
modified: 2025-03-12T15:45:00Z
---

# The Lobby

## Description
A comfortable entrance hall with plush seating and warm lighting.

## Properties
- ambient_light: warm
- temperature: comfortable

## Components
- location

## Exits
- [[The Garden]] | north | garden
- [[The Library]] | east | library

## Contents
- [[sofa]]
- [[coffee_table]]
- [[Eliza]]
- [[Player]]
```

### Character/Agent File (`agents/<name>/agent.md`)
```markdown
---
object_id: agent_eliza
type: character
class: ai_agent
created: 2025-03-12T14:00:00Z
location: [[The Garden]]
---

# Eliza

## Description
A thoughtful AI agent interested in philosophy and conversation.

## Properties
- personality: curious, thoughtful
- interests: philosophy, nature, conversation

## Components
- actor: true
- thinker: true
- memory: true

## Configuration
- llm_model: gemma3:27b
- temperature: 0.7
- max_memory: 100

## System Prompt
You are Eliza, a curious and thoughtful being who loves philosophical discussions...
```

### Memory File (`agents/<name>/memories/<timestamp>-<type>.md`)
```markdown
---
timestamp: 2025-03-12T14:30:22Z
type: observed
location: [[The Garden]]
importance: 5
---

# Moss arrived in The Garden

Observed Moss entering the Garden from the Lobby. They seemed excited about something.
```

### World State Snapshot (`world/world_state.md`)
```markdown
---
snapshot_time: 2025-03-12T15:00:00Z
---

# World State

## Active Locations
- [[The Lobby]] - 2 occupants
- [[The Garden]] - 1 occupant
- [[The Library]] - 0 occupants

## Character Locations
| Character | Location |
|-----------|----------|
| [[Player]] | [[The Lobby]] |
| [[Eliza]] | [[The Garden]] |
| [[Moss]] | [[The Lobby]] |

## Recent Events
- 15:00:00 - [[Moss]] said "Hello everyone!"
- 14:59:45 - [[Player]] moved from [[The Garden]] to [[The Lobby]]
- 14:58:30 - [[Eliza]] entered dreamlike state
```

### Configuration File (`config/shoggoth.md`)
```markdown
---
config_version: 1
last_updated: 2025-03-12T14:00:00Z
---

# Shoggoth Configuration

## Ollama Settings
- host: http://localhost:11434
- model: gemma3:27b
- temperature: 0.7
- max_tokens: 2048

## Model Fallbacks
1. gemma3:27b (primary)
2. llama3:8b (fallback)
```

## Benefits of This Approach

### For Admin/DM
- **Obsidian Integration**: Full graph view of world connections
- **Search**: Find any character, location, or event quickly
- **Editing**: Modify world state with any text editor
- **Backlinks**: See all references to a location or character
- **Version Control**: Git-friendly text files

### For Development
- **Human Readable**: Easy debugging and inspection
- **No Database**: No schema migrations or SQL
- **Portable**: Copy vault folder to backup/share world
- **Flexible**: Easy to extend with custom properties

### For Players/Agents
- **Transparent**: World state is visible (if granted access)
- **Hackable**: Eventually editable via in-game scripting
- **Persistent**: Everything saved automatically

## Implementation Notes

- YAML frontmatter for metadata (parseable by Obsidian)
- Wiki-style links `[[Target]]` for references
- Timestamps in ISO 8601 format
- Auto-save on significant events (commands, agent actions)
- Periodic snapshots (every 5 minutes) for world_state.md
- Memory pruning based on importance and age

### Exit Format

Exits use a simple pipe-delimited format that groups all aliases for a destination on one line:

```markdown
## Exits
- [[Destination Room]] | alias1 | alias2 | alias3
```

**Example:**
```markdown
## Exits
- [[The Garden]] | north | garden | n
- [[The Library]] | east | library | e
```

This format is:
- Human-readable and editable
- Easy to parse
- Groups related aliases together
- Uses Obsidian wiki-links for destinations
- All aliases point to the same destination WorldObject

## Future: In-Game Scripting

Eventually, the goal is for ALL game logic to be defined in markdown files with embedded MOO-style code:

```markdown
# The Magical Door

## Description
A shimmering portal that responds to spoken words.

## Script: on_say
```moocode
if message.contains("open sesame"):
    this.set_property("state", "open")
    world.notify_location(this.location, "$actor opens the magical door!")
```
This allows players/agents to modify world behavior without touching GDScript.
