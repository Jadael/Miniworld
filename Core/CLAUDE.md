# Core

## Purpose
The Core directory contains the fundamental building blocks of Miniworld's MOO-style object system. This is where WorldObjects live, how they compose behaviors through components, and how commands are parsed.

## Contents
- **world_object.gd** - Base class for all entities in the world (MOO-style object system with properties, components, and containment)
- **command_parser.gd** - LambdaMOO-compatible command parser with quote-aware tokenization, preposition parsing, and object resolution
- **command_metadata.gd** - Centralized registry of all commands with metadata for the help system
- **ai_agent.gd** - Manages AI agent lifecycle, vault persistence, and memory recording
- **components/** - Modular behaviors that attach to WorldObjects (Actor, Thinker, Memory, Location, etc.)

## Relationship to Project
Core implements the fundamental architecture patterns:
- **Composition over Inheritance** - WorldObjects gain capabilities by adding components
- **Property-Based Configuration** - Runtime-editable settings stored as properties
- **MOO Semantics** - LambdaMOO-compatible command parsing and object resolution
- **Component System** - All behaviors (acting, thinking, remembering, containing) are modular components

The Core system is used by:
- **Daemons** (WorldKeeper manages WorldObjects, EventWeaver uses components)
- **UI** (game controllers create and interact with WorldObjects)
- **AI Agents** (use Actor, Thinker, Memory components for autonomous behavior)

## Key Patterns

### WorldObject Architecture
Every entity in Miniworld is a WorldObject that can:
- Store arbitrary properties (`set_property()`, `get_property()`)
- Have components attached (`add_component()`, `has_component()`)
- Exist in a containment hierarchy (`move_to()`, `get_location()`, `get_contents()`)
- Have unique IDs for reference (`#123` format)

### Component Lifecycle
Components follow a standard lifecycle:
1. Created via `WorldObject.add_component("component_name")`
2. `_on_added(obj)` called when attached
3. `process(delta)` called each frame if component implements it
4. `_on_removed()` called when detached

### Command Flow
1. Player/AI inputs command string
2. `CommandParser.parse()` tokenizes and resolves objects
3. `ActorComponent.execute_command()` dispatches to `_cmd_*()` method
4. Command result returned and broadcast to observers
5. Memory component records action and result

## Maintenance Instructions
When working in this directory, maintain this CLAUDE.md file and create/update CLAUDE.md files in any subdirectories following the recursive documentation pattern described in the root CLAUDE.md.

When adding new components, update the components/CLAUDE.md file with the component's purpose and role.
