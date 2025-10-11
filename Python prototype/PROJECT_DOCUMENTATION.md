# Miniworld Project Documentation

## Overview

Miniworld is a sophisticated multi-agent simulation environment that enables AI agents (called "miniminds") to interact with each other, a human player, and a shared virtual world. The system leverages large language models (LLMs) to create believable, autonomous AI agents that can engage in natural conversations, make observations, maintain memories, and pursue goals within a turn-based framework.

## Project Structure

```
Miniworld/
├── Core Application Files
│   ├── app.py                 # Main application entry point (106 lines)
│   ├── main_gui.py            # Primary GUI controller (486 lines)
│   ├── minimind.py            # Minimind agent implementation (1,094 lines)
│   ├── world.py               # World environment system (1,213 lines)
│   └── turn_manager.py        # Turn-based interaction system (350 lines)
│
├── System Components
│   ├── command_processor.py   # Command processing logic (675 lines)
│   ├── event_handler.py       # Event management system (434 lines)
│   ├── llm_interface.py       # Ollama LLM integration (320 lines)
│   ├── memory.py              # Memory management system (389 lines)
│   └── vector_store.py        # Vector embeddings storage (119 lines)
│
├── Utilities & UI
│   ├── gui_utils.py           # GUI utility functions (257 lines)
│   ├── ui_panels.py           # UI panel definitions (299 lines)
│   ├── markdown_utils.py      # Markdown processing utilities (400 lines)
│   ├── cot_perturb.py         # Chain-of-thought perturbation (130 lines)
│   └── utils.py               # General utility functions (60 lines)
│
├── Core Architecture
│   └── core/
│       ├── agent.py           # Base agent class (127 lines)
│       ├── player.py          # Human player implementation
│       ├── event_bus.py       # Event system infrastructure
│       └── event_dispatcher.py # Event dispatching logic
│
├── Configuration & Templates
│   └── vault/
│       ├── settings/          # System configuration files
│       │   ├── app_settings.md
│       │   ├── llm_settings.md
│       │   ├── commands.md
│       │   ├── turn_rules.md
│       │   └── command_aliases.md
│       └── templates/         # System templates
│           ├── agent_system_prompt.md
│           ├── prompt_template.md
│           ├── memory_format.md
│           ├── note_format.md
│           └── location_template.md
│
├── Runtime Data
│   ├── miniminds/            # Active minimind agent data
│   ├── backup_minds/         # Backup minimind profiles & memories
│   ├── backup_locations/     # Backup location definitions
│   ├── world/                # Current world state
│   └── agents/               # Player agent data
│
└── Archive
    └── archive/              # Archived components and documentation
```

**Total Lines of Code: 6,332 lines across 15 Python files**

## System Architecture

### Core Components

#### 1. Application Entry Point (`app.py`)
- Initializes the application environment
- Loads configuration from markdown files in the vault
- Sets up CustomTkinter GUI framework
- Creates player agent and launches main GUI

#### 2. Agent System
- **Base Agent Class** (`core/agent.py`): Defines common functionality for all agents
- **Player Class** (`core/player.py`): Represents the human player as an agent
- **Minimind Class** (`minimind.py`): AI agent implementation with LLM-powered reasoning

#### 3. World Environment (`world.py`)
- Manages locations, objects, and environmental state
- Implements observer pattern for event notifications
- Handles command execution and state changes
- Maintains persistent world state in markdown format

#### 4. Turn Management (`turn_manager.py`)
- Controls turn-based interaction flow
- Manages time units (TU) and action costs
- Supports both memory-based and time-based turn modes
- Handles agent scheduling and turn progression

#### 5. Command Processing (`command_processor.py`)
- Parses and validates user/agent commands
- Maps commands to world actions
- Manages command aliases and synonyms
- Integrates with world state updates

#### 6. Event System
- **Event Handler** (`event_handler.py`): Manages agent turns and responses
- **Event Bus** (`core/event_bus.py`): Core event infrastructure
- **Event Dispatcher** (`core/event_dispatcher.py`): Routes events to appropriate handlers

#### 7. Memory & Knowledge Management
- **Memory System** (`memory.py`): Manages agent memories and experiences
- **Vector Store** (`vector_store.py`): Handles semantic search using embeddings
- **Markdown Utils** (`markdown_utils.py`): Processes markdown-based data storage

#### 8. LLM Integration (`llm_interface.py`)
- Connects to Ollama API for local LLM inference
- Supports streaming responses and embeddings
- Configurable model parameters and stop tokens
- Thread-safe request management

### Key Features

#### Multi-Agent Simulation
- AI agents (miniminds) with unique personalities and goals
- Human player participation as an equal agent
- Persistent agent memories and knowledge bases
- Agent-to-agent and agent-to-world interactions

#### Turn-Based System
- Structured turn progression with time unit costs
- Memory-based or time-based turn modes
- Action scheduling and priority management
- Turn state persistence

#### Natural Language Processing
- LLM-powered agent reasoning and decision making
- Chain-of-thought processing with perturbation
- Natural language command parsing
- Contextual response generation

#### Persistent World State
- Markdown-based world and agent data storage
- Automatic backup systems for agents and locations
- Template-driven content generation
- Configuration through markdown files

#### Extensible Architecture
- Modular component design
- Plugin-like command system
- Customizable agent templates
- Configurable LLM parameters

## Configuration System

The system uses a vault-based configuration approach with markdown files:

### Settings Files (`vault/settings/`)
- **app_settings.md**: UI appearance, window size, default counts
- **llm_settings.md**: Model selection, temperature, context tokens
- **commands.md**: Available commands and descriptions
- **turn_rules.md**: Turn system rules and time unit costs
- **command_aliases.md**: Command shortcuts and synonyms

### Templates (`vault/templates/`)
- **agent_system_prompt.md**: Base prompt for agent reasoning
- **prompt_template.md**: Template for agent interaction prompts
- **memory_format.md**: Structure for agent memory entries
- **note_format.md**: Format for agent notes
- **location_template.md**: Template for world locations

## Dependencies

The project uses the following key dependencies:
- **CustomTkinter**: Modern GUI framework
- **requests**: HTTP client for Ollama API
- **numpy**: Numerical computing for embeddings
- **threading**: Concurrent operation support
- **Standard Library**: os, json, datetime, uuid, re

## Data Flow

1. **Command Input**: User or agent issues a command through the GUI
2. **Command Processing**: CommandProcessor validates and interprets the command
3. **World Update**: World state is modified based on the command
4. **Event Notification**: All observers in relevant locations are notified
5. **Memory Storage**: Agents store observations and experiences as memories
6. **Turn Management**: TurnManager handles agent turn progression
7. **LLM Processing**: Agents use LLM to reason and generate responses
8. **UI Update**: GUI reflects all changes and updates displays

## Technical Highlights

- **Agent-Oriented Architecture**: Unified agent abstraction for both AI and human participants
- **Markdown-Driven Configuration**: Human-readable configuration and data storage
- **Vector Similarity Search**: Semantic memory retrieval using embeddings
- **Thread-Safe LLM Integration**: Concurrent LLM requests with proper synchronization
- **Event-Driven Design**: Loose coupling through comprehensive event system
- **Template System**: Flexible content generation through markdown templates

This architecture provides a robust foundation for multi-agent simulation with natural language interaction, persistent memory systems, and extensible world modeling capabilities.