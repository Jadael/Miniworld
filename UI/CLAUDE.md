# UI

## Purpose
The UI directory contains all player-facing interface code for Miniworld. This includes the game view, command input, output display, and configuration panels. All UI is built using Godot's Control nodes for consistency with the engine's paradigms.

## Contents

### Core UI Scripts
- **game_ui.gd** - Main game interface container, manages layout and child controls
- **game_ui.tscn** - Scene file for the game interface layout
- **game_controller_ui.gd** - UI-specific controller logic, handles command input and output display

### Configuration UI
- **shoggoth_settings.gd** - Configuration panel for Ollama/LLM connection settings

### Root-Level Game Scripts
_(Note: These are currently in root but logically belong to UI)_
- **game_controller.gd** (root) - Core game loop and player/agent management
- **game_controller_ui.gd** (root) - Bridge between game logic and UI display

## UI Architecture

### Godot Control Nodes
All UI is built using Godot 4's Control nodes:
- **VBoxContainer** / **HBoxContainer** - Layout management
- **RichTextLabel** - Formatted text output with BBCode support
- **LineEdit** - Command input field
- **Button** - Action buttons

### Signal-Based Communication
UI communicates with game logic via signals:
```gdscript
# UI emits when player enters command
signal command_submitted(text: String)

# Game logic connects and handles
game_controller_ui.command_submitted.connect(_on_command_submitted)
```

### Separation of Concerns
- **game_ui.gd** - Pure UI layout and Control node management
- **game_controller_ui.gd** - Game logic ↔ UI bridge
- **game_controller.gd** - Core game state and tick processing

## Key UI Patterns

### Command Input Flow
1. Player types command in LineEdit
2. UI emits `command_submitted` signal
3. game_controller_ui parses command
4. ActorComponent executes command
5. Result formatted and displayed in RichTextLabel

### Output Formatting
Uses BBCode for rich text:
```gdscript
output_text.append_text("[b]You say:[/b] Hello!\n")
output_text.append_text("[color=gray]Moss nods thoughtfully.[/color]\n")
```

### Settings Panel
Shoggoth settings allow runtime configuration:
- Ollama server URL
- Model selection
- Connection testing
- Applied immediately (no restart needed)

## Relationship to Project

UI is the **presentation layer** that:
- Receives player input
- Displays game state and events
- Provides configuration interfaces
- Uses Core and Daemons but doesn't implement game logic

**UI depends on**:
- **Core/ActorComponent** - Executes player commands
- **Core/WorldObject** - Displays object state
- **Daemons/Shoggoth** - Settings configuration
- **Daemons/EventWeaver** - Receives observable events

**UI provides**:
- Player interaction interface
- Real-time output display
- Configuration panels

## Godot Editor Integration

All UI elements should be:
- **Designed in Godot Editor** - Use scene editor for layout, not code
- **Theme-aware** - Respect Godot's theming system
- **Accessible** - Proper focus management and keyboard navigation
- **Responsive** - Handle window resizing gracefully

When the director says they need to "look at" UI issues, they mean running the project in Godot Editor and visually inspecting the interface.

## Adding New UI Elements

When creating new UI:

1. **Use Godot Editor** - Design visually, not in code
2. **Create .tscn scene files** - Keep UI structure in scenes
3. **Script only for logic** - Attach GDScript for behavior, not layout
4. **Follow Control node patterns** - Containers, margins, anchors
5. **Test in Godot Editor** - The director will verify visual appearance

## Collaborative Testing Note

Remember: Claude Code cannot see or run the UI. When implementing UI changes:
- Add clear descriptions of what was changed
- Explain expected visual behavior
- The director will run and provide visual feedback
- Iterate based on director's observations

See "Collaborative Testing in Godot Editor" in root CLAUDE.md for full workflow.

## Maintenance Instructions
When working in this directory, maintain this CLAUDE.md file. When adding new UI panels or modifying interaction patterns, document them here.

Follow the recursive documentation pattern described in the root CLAUDE.md.
