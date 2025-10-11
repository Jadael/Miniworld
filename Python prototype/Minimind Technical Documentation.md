# Miniworld Technical Documentation

## Table of Contents

1. [Introduction](#introduction)
2. [System Architecture](#system-architecture)
3. [Installation & Setup](#installation--setup)
4. [Agent Architecture](#agent-architecture)
5. [World and Environment](#world-and-environment)
6. [Turn-Based Interaction System](#turn-based-interaction-system)
7. [Command System](#command-system)
8. [Memory and Knowledge Management](#memory-and-knowledge-management)
9. [GUI Interface](#gui-interface)
10. [LLM Integration](#llm-integration)
11. [Technical Implementation Details](#technical-implementation-details)
12. [API Reference](#api-reference)
13. [Extensions and Customization](#extensions-and-customization)

## Introduction

Miniworld is a multi-agent simulation environment where AI agents (called "miniminds") interact with each other and the world. The system uses large language models (LLMs) to power believable AI agents that can navigate environments, interact through conversation, make observations, and maintain memories and notes.

The platform supports a turn-based interaction system where miniminds and a human player can take actions in a shared environment. Each minimind maintains its own knowledge base, has a unique personality, and can make autonomous decisions based on its memories, observations, and goals.

## System Architecture

Miniworld follows a modular architecture with the following key components:

![System Architecture](https://example.com/architecture.png)

### Core Components

1. **MinimindGUI**: Central UI controller that manages interaction between all components
2. **World**: Manages environment state, locations, characters, and objects
3. **Minimind**: Represents individual agent characters with memories and reasoning
4. **TurnManager**: Controls the turn-based interaction system
5. **CommandProcessor**: Processes commands from agents and players
6. **EventHandler**: Handles events and agent turns
7. **MarkdownVault**: Manages persistent storage in markdown format
8. **OllamaInterface**: Connects to Ollama API for LLM functionality

### Data Flow

1. User or agent issues a command
2. CommandProcessor processes the command and updates the World state
3. World notifies all observers (agents) in relevant locations
4. Agents store observations as memories
5. EventHandler manages agent turns using the LLM to generate actions
6. GUI updates to reflect changes

## Installation & Setup

### Prerequisites

- Python 3.8 or higher
- CustomTkinter library
- Ollama running locally with supported models

### Directory Structure

```
miniworld/
├── app.py                 # Main application entry point
├── command_processor.py   # Command processing logic
├── cot_perturb.py         # Chain-of-thought perturbation
├── event_handler.py       # Event handling system
├── gui_utils.py           # GUI utility functions
├── llm_interface.py       # Interface to Ollama API
├── main_gui.py            # Main GUI implementation
├── markdown_utils.py      # Markdown handling utilities
├── memory.py              # Memory management system
├── minimind.py            # Minimind agent implementation
├── turn_manager.py        # Turn-based system management
├── ui_panels.py           # UI panel definitions
├── utils.py               # Utility functions
├── vector_store.py        # Vector storage for embeddings
├── world.py               # World environment implementation
├── miniminds/             # Storage directory for miniminds
├── vault/                 # Storage for templates and settings
│   ├── templates/         # System templates
│   ├── settings/          # Configuration settings
│   └── world/             # World definitions
└── world/                 # World state storage
    ├── locations/         # Location definitions
    └── world_state.md     # Current world state
```

### Configuration

The system uses markdown files in the `vault/settings/` directory for configuration:

- `app_settings.md`: General application settings including memory counts and UI settings
- `llm_settings.md`: LLM configuration including model, temperature, and context tokens
- `commands.md`: Command definitions and descriptions
- `turn_rules.md`: Rules for the turn-based system including TU costs
- `command_aliases.md`: Aliases for commands (e.g., "check" -> "look")

### Installation Steps

1. Ensure Ollama is installed and running locally
2. Install required Python packages: `pip install customtkinter`
3. Clone the repository or download source files
4. Run `python app.py` to start the application

## Agent Architecture

Miniminds are autonomous AI agents powered by LLMs with:

1. **Profile**: Defines personality, traits, background, and goals
2. **Memory System**: Records observations and experiences
3. **Note System**: Allows agents to create and recall personal notes
4. **Vector Embeddings**: Enable semantic search of memories and notes
5. **Chain-of-Thought Reasoning**: For decision making with structured thinking

### Agent Lifecycle

1. Agent perceives environment and updates memories
2. Agent retrieves relevant memories and notes
3. Agent constructs a prompt with current context and history
4. LLM generates chain-of-thought reasoning and decides action
5. Agent executes action and updates memories

### Agent Prompt Structure

```
<think>
# Thinking as {{name}}

You are {{name}}. Think through your next action step by step, considering:
- Who you are (your profile)
- Your current situation and surroundings
- Your recent memories
- Your mental notes
- Your goals and motivations

## Your Profile
{{profile}}

## Current Situation
You are in {{location}}.
{{location_description}}
{{location_exits}}

{{location_characters}}

## Recent Experience
{{#if last_command}}
Your last action was: {{last_command}}
The result was: {{last_result}}
{{/if}}

{{#if memories}}
### Your Recent Memories
{{memories}}
{{/if}}

{{#if notes}}
### Your Mental Notes
{{notes}}
{{/if}}

Now, decide what to do next. Consider:
1. What are your immediate goals right now?
2. What information do you have that's relevant?
3. What action would be most logical given your character and situation?
4. Who is around you and how might you interact with them?
5. What might you want to make a note of or remember?
</think>

You are {{name}}. Thinking as {{name}}, staying true and faithful to how {{name}} would think, use your profile, memories, notes, and situation to decide your next action.

# Command Syntax
Your response must start with a single command on one line with NO preamble. The part after `|` should explain the context and desired outcome of WHY you're taking this action. DO NOT include any explanation, commentary, or text before your command.

Available commands:
GO TO [location] | [reason for going]
SAY [message] | [reason for saying]
SHOUT [message] | [reason for saying]
NOTE [title]: [single line of plaintext observations, implications, plans, follow-ups, related topics] | [reason for noting]
RECALL [query] | [reason for recalling]
LOOK | [reason for looking/passing]
```

### Chain-of-Thought Perturbation

To prevent agents from getting stuck in repetitive thinking patterns, Miniworld uses a chain-of-thought perturbation system:

1. Previous agent thoughts are stored
2. For subsequent turns, thoughts are perturbed by:
   - Sampling 70-90% of paragraphs/sentences
   - Shuffling their order slightly
   - Masking certain tokens (especially adjectives/adverbs)

This approach prevents the agent from falling into rigid patterns while maintaining the core of their reasoning process.

### Memory Formats

Agents store two main types of information:

#### Action Memories
```markdown
# Action Memory

🧠12345678:{👥John,💡went to the kitchen,📍Living Room,📅2023-01-01 12:00:00,❓Hungry,🔧walked}
```

Components:
- 👥 Who: Actor
- 💡 What: Action
- 📍 Where: Location
- 📅 When: Timestamp
- ❓ Why: Motivation
- 🔧 How: Method

#### Notes
```markdown
# Meeting Plans

📅 2023-01-01 12:00:00
👥 Present: John, Mary
📍 Living Room
🔧 Note on meeting plans
❓ Planning future event
💡 We should meet at 3pm tomorrow to discuss the project.
```

## World and Environment

The world in Miniworld consists of:

1. **Locations**: Distinct areas with descriptions and connections
2. **Characters**: Miniminds and the player
3. **Objects**: Interactive items in locations with states

### Location Structure

Locations are defined in markdown files with:

```markdown
# Description
A detailed description of the location.

# Connections
- Connected Location 1
- Connected Location 2

# Objects
- object1: state1
- object2: state2
```

### World State Management

The world state is stored in `world/world_state.md` and includes:
- Character locations
- Object states
- Timestamp of last update

Example world state:
```markdown
# World State
Timestamp: 2023-01-01 12:00:00

## Character Locations
- John: Living Room
- Mary: Kitchen
- Player: Living Room

## Object States
### Living Room
- sofa: clean
- bookshelf: dusty

### Kitchen
- stove: off
- refrigerator: contains food
```

### Observer System

The world implements an observer pattern where:
1. Characters register as observers
2. Events in the world notify relevant observers
3. Characters create memories from observations

## Turn-Based Interaction System

The turn-based system is managed by the `TurnManager`:

1. **Time Units (TU)**: Each action costs TU based on complexity
2. **Turn Order**: Determined by lowest TU count
3. **God Mode**: Optional mode where player actions cost 0 TU

### TU Cost Calculation

- Base cost: 1 TU
- SAY: Base + 1 TU per 3 words
- SHOUT: Base + 1 TU per 2 words
- NOTE: Base + 1 TU per 7 words
- RECALL: 2 TU
- DREAM: 5 TU (for deep introspection)

Example calculation:
```python
def calculate_tu_cost(self, command):
    """Calculate TU cost for a command based on rules"""
    # Base cost (ante)
    cost = self.base_cost
    
    # If scaling is disabled, return base cost for all commands
    if not self.scale_with_content:
        return cost
    
    # Extract command type and content
    command_lower = command.lower().strip()
    
    # SAY command: +1 for every X words (from settings)
    if command_lower.startswith("say "):
        message = command[4:].strip()
        word_count = len(message.split())
        cost += math.ceil(word_count / self.say_multiplier)
```

### Turn Flow

1. Get character with lowest TU
2. Execute character's turn (generate action using LLM)
3. Add TU cost to character's total
4. Normalize TU values (subtract minimum TU from all characters)
5. Move to next character

## Command System

Commands are the primary way characters interact with the world:

### Available Commands

1. **GO TO [location]**: Move to a connected location
2. **SAY [message]**: Communicate with characters in the same location
3. **SHOUT [message]**: Communicate with all characters in the world
4. **NOTE [title]: [content]**: Create a personal note
5. **RECALL [query]**: Search personal notes
6. **LOOK**: Observe the current location
7. **EMOTE [action]**: Express a physical action
8. **DREAM**: Enter a dreamlike state for memory synthesis

### Command Processing

The command processing flow:

1. Command is parsed and validated
2. Aliases are applied (e.g., "check" -> "look")
3. Appropriate handler is called based on command type
4. World state is updated
5. Observers are notified
6. Result is returned to the character

Example command handler:
```python
def handle_say_command(self, actor, message, original_reason=None):
    """Handle the 'say' command"""
    location = self.get_character_location(actor)
    if not location:
        return {"success": False, "message": "You are nowhere."}
    
    # Create the say message format for others
    say_msg = f"{actor} says: \"{message}\""
    
    # Create the say message format for self
    self_msg = f"You say: \"{message}\""
    
    # Notify all characters in the location
    self.notify_location(location, "speech", say_msg, {
        "actor": actor,
        "message": message,
        "location": location,
        "original_reason": original_reason
    })
    
    return {
        "success": True,
        "message": self_msg,
        "data": {
            "location": location,
            "message": message,
            "original_reason": original_reason
        }
    }
```

## Memory and Knowledge Management

Miniminds maintain two types of knowledge:

### Memory Storage

Memories are stored as markdown files in the agent's directory:
```
miniminds/[agent_name]/memories/
```

Each memory file is named with a timestamp and type:
```
20230101-120000-observed.md
```

### Note Storage

Notes are stored as markdown files in the agent's directory:
```
miniminds/[agent_name]/notes/
```

Each note is indexed with vector embeddings for semantic search.

### Vector Embeddings

Miniworld uses vector embeddings for semantic search of notes:

1. Title and content are embedded separately
2. Combined embedding is created with weighted average (0.3 title, 0.7 content)
3. Embeddings are stored in a JSON-based vector store

Example vector store implementation:
```python
class NoteVectorStore:
    """A simple vector store for Minimind notes"""
    
    def __init__(self, minimind_name):
        """Initialize the vector store for a specific minimind"""
        self.minimind_name = minimind_name
        self.minimind_path = os.path.join("miniminds", minimind_name)
        self.vector_db_path = os.path.join(self.minimind_path, "note_vectors.json")
        self.vectors = self._load_vectors()
        
    def get_similar_notes(self, query_vector, vector_type="combined", top_n=5, min_similarity=0.0):
        """Get the top N similar notes by cosine similarity"""
        if not self.vectors:
            return []
            
        # Calculate similarities
        results = []
        for note_id, data in self.vectors.items():
            if vector_type in data:
                note_vector = data[vector_type]
                similarity = self._cosine_similarity(query_vector, note_vector)
                
                # Only include results above minimum similarity if specified
                if similarity >= min_similarity:
                    results.append((note_id, similarity))
        
        # Sort by similarity (highest first)
        results.sort(key=lambda x: x[1], reverse=True)
        
        # Return top N results
        return results[:top_n]
```

### Memory Retrieval

Miniminds retrieve memories based on:
1. Recency: More recent memories prioritized
2. Relevance: Memories related to current situation
3. Importance: Memories marked as important

The system uses a weighted scoring function to balance these factors.

### Special Memory Functions

#### RECALL
When an agent uses the RECALL command, a semantic search is performed against their notes:

```python
def _handle_recall_command(self, minimind, query, reason=None, prompt=None, system_prompt=None, llm_response=None):
    """Handle the recall command to search for relevant notes"""
    # Create structured event
    structured_event = format_structured_event(
        "recall", 
        minimind.name, 
        f"tries to recall information about '{query}'",
        minimind.location,
        reason if reason else "Searching memory",
        None,
        "Memory recall"
    )
    
    # Log the action to world events
    add_world_event(self.gui, f"{minimind.name} tries to recall information about '{query}'", structured_event)
    
    # Get the query result
    result_message = minimind.query_notes(query)
```

#### DREAM
The DREAM command allows agents to synthesize their memories in a dreamlike state:

```python
def _handle_dream_command(self, minimind, reason=None, prompt=None, system_prompt=None, llm_response=None):
    """Handle the dream command for deeper memory synthesis and reflection"""
    # Get the memories count from settings or use default
    dream_memories_count = getattr(self.gui, 'dream_memories_count', 256)
    
    # Create structured event
    structured_event = format_structured_event(
        "dream", 
        minimind.name, 
        f"enters a dreamlike state, reflecting on past experiences",
        minimind.location,
        reason if reason else "Memory synthesis through dreaming",
        None,
        "Synthesizing memories into guidance"
    )
    
    # Get a larger set of memories than normal
    memories = minimind.get_memories(dream_memories_count)
    
    # Create the dream prompt with salted memories
    dream_prompt = self._create_dream_prompt(minimind, memories)
```

## GUI Interface

The GUI is built using CustomTkinter and consists of three main panels:

1. **Minimind Panel**: For managing miniminds
2. **Interaction Panel**: For player interaction and world events
3. **Debug Panel**: For viewing LLM prompts and responses

### Minimind Panel

- List of miniminds
- Buttons to create, edit, and view miniminds
- Access to memories and notes

### Interaction Panel

- World Events log (GM view)
- Turn order display
- Player View (MUD/MOO style interface)
- Command entry
- Controls for turn execution

### Debug Panel

- LLM settings (model, temperature, context)
- Memory and note count settings
- Prompt display
- Response display

## LLM Integration

Miniworld uses the Ollama API for language model capabilities:

### OllamaInterface

The OllamaInterface class connects to the Ollama API and provides:
- Query methods for non-streaming and streaming responses
- Embedding generation for semantic search
- Support for custom models and parameters

```python
class OllamaInterface:
    def __init__(self, model="deepseek-r1:14b", temperature=0.7, context_tokens=32768, 
                repeat_penalty=1.1, embedding_model="all-minilm", stop_tokens=None, system=""):
        """Initialize the Ollama API interface"""
        self.base_url = "http://localhost:11434/api"
        self.model = model
        self.embedding_model = embedding_model
        self.temperature = temperature
        self.context_tokens = context_tokens
        self.repeat_penalty = repeat_penalty
        # Default stop tokens for cutting off explanations
        self.stop_tokens = stop_tokens or ["Explanation:", "Let me explain:", "To explain my reasoning:"]
        
        # Default to empty system message
        self.system = system
```

### LLM Settings

- Model: Default `deepseek-r1:14b`
- Temperature: Default 0.8
- Context Tokens: Default 32768
- Repeat Penalty: Default 1.2
- Embedding Model: Default `all-minilm`

The system supports streaming responses from the LLM, with specialized handling for parsing and processing the agent's thought chain and action decision.

### Prompt Construction

The system constructs prompts for miniminds that include:
- Agent profile
- Current situation
- Recent memories
- Relevant notes
- Previous chain-of-thought (perturbed to reduce repetition)

Example prompt construction:
```python
def construct_prompt(self, location_data, max_memories=10, max_notes=5):
    """Construct a prompt for the LLM based on character state"""
    # Get current time for the prompt
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Get room exits
    connections = location_data.get("connections", [])
    
    # Get characters in the same location
    characters_here = location_data.get("characters", [])
    other_characters = [c for c in characters_here if c != self.name]
    
    # Format exits
    if connections:
        if len(connections) == 1:
            exits_text = f"You can GO TO {connections[0]} from here."
        else:
            conn_list = ", ".join(connections[:-1]) + " and " + connections[-1]
            exits_text = f"You can GO TO {conn_list} from here."
    else:
        exits_text = f"You see nowhere you can GO TO from here."
```

## Technical Implementation Details

### The App Entry Point

The `app.py` file serves as the main entry point for the application:

```python
def main():
    """Main application entry point"""
    # Ensure all directories exist
    ensure_directories()
    
    # Load settings from the vault
    settings = load_app_settings()
    
    # Extract LLM settings if available
    llm_settings = settings.get("llm", {})
    app_settings = settings.get("app", {})
    
    # Set appearance mode and color theme for CustomTkinter
    appearance = app_settings.get("appearance_mode", "dark")
    theme = app_settings.get("color_theme", "blue")
    
    ctk.set_appearance_mode(appearance)
    ctk.set_default_color_theme(theme)
    
    # Create root window
    root = ctk.CTk()
    root.title("Minimind")
    
    # Initialize app
    app = MinimindGUI(root, settings)
    
    # Start the main loop
    root.mainloop()
```

### Minimind Implementation

The `Minimind` class is the core implementation of an agent:

```python
class Minimind:
    def __init__(self, name, llm_interface=None):
        """Initialize a minimind with the given name"""
        self.name = name
        self.path = os.path.join("miniminds", name)
        self.location = None
        self.last_thought_chain = None  # For storing chain of thought
        self.last_command = None        # For storing last command
        self.last_command_result = None # For storing last command result
        self.last_command_reason = None # For storing reason for the last command
        self.llm_interface = llm_interface  # For generating embeddings
        
        # Initialize vector store
        self.vector_store = NoteVectorStore(name)
        
        # Ensure directories exist
        self._ensure_directories()
        
        # Load profile
        self.profile = self._load_profile()
        
        # Load templates from vault
        self.prompt_template = MarkdownVault.load_template("prompt_template")
        self.memory_format = MarkdownVault.load_template("memory_format")
        self.note_format = MarkdownVault.load_template("note_format")
        self.agent_system_prompt = MarkdownVault.load_template("agent_system_prompt")
```

### World Implementation

The `World` class manages the environment:

```python
class World:
    _instance = None
    
    @classmethod
    def get_instance(cls):
        """Get the singleton instance of the World"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
        
    def __init__(self):
        """Initialize the world state"""
        # Record as singleton instance
        World._instance = self
        
        self.locations = {}
        self.current_location = None
        # Dictionary to store observers (characters) who should receive notifications
        self.observers = defaultdict(list)
        
        # Load templates from vault
        self.location_template = MarkdownVault.load_template("location_template")
        self.world_state_template = MarkdownVault.load_template("world_state_template")
        
        # Load or create locations
        self.initialize_locations()
        
        # Try to load saved world state
        self.load_world_state()
```

## API Reference

### Minimind API

```python
# Create a new minimind
minimind = Minimind.create_new(name, llm_interface)

# Set minimind's location
minimind.set_location(location)

# Add a memory
minimind.add_observation_memory(actor, action, reason)
minimind.add_action_memory(action)
minimind.add_response_memory(action, response, reason)

# Create a note
minimind.create_note(title, content, reason)

# Get memories and notes
memories = minimind.get_memories(max_count=10)
notes = minimind.get_notes(max_count=5)

# Semantic search
relevant_notes = minimind.get_relevant_notes(query, max_count=5)
search_result = minimind.query_notes(query)

# Generate response
prompt = minimind.construct_prompt(location_data, memories_count, notes_count)
```

### World API

```python
# Get or create world singleton
world = World.get_instance()

# Process a command
result = world.process_command(actor, command, reason)

# Register observers
world.register_observer(character_name, callback)

# Location management
location_data = world.get_location_data(location)
world.add_character_to_location(character, location)
world.move_character(character, destination)

# Object management
world.add_object_to_location(location, object_name, object_state)
world.update_object_state(location, object_name, new_state)
```

### TurnManager API

```python
# Register characters
turn_manager.register_character(name, is_player=False)

# Get next character
next_character = turn_manager.get_next_character()

# Calculate TU cost
cost = turn_manager.calculate_tu_cost(command)

# Add TU to character
turn_manager.add_time_units(character, tu_cost)

# Get turn order
turn_order = turn_manager.get_turn_order()
```

## Extensions and Customization

### Adding New Commands

To add a new command:
1. Add command handler to `World` class
2. Update command processor to recognize the command
3. Add command to `vault/settings/commands.md`

Example:
```python
def handle_custom_command(self, actor, parameters, original_reason=None):
    """Handle a custom command"""
    location = self.get_character_location(actor)
    if not location:
        return {"success": False, "message": "You are nowhere."}
    
    # Process the command
    # ...
    
    # Create notification for observers
    custom_msg = f"{actor} performs a custom action."
    self.notify_location(location, "custom", custom_msg, {
        "actor": actor,
        "action": "performed custom action",
        "location": location,
        "original_reason": original_reason or "Custom action"
    })
    
    return {
        "success": True,
        "message": "You performed a custom action.",
        "data": {
            "location": location,
            "original_reason": original_reason
        }
    }
```

### Customizing Agent Prompts

Edit templates in `vault/templates/`:
- `prompt_template.md`: Agent decision making prompt
- `memory_format.md`: Memory formatting
- `note_format.md`: Note formatting
- `agent_system_prompt.md`: System prompt for agent

### Extending World Functionality

The world system can be extended by:
1. Adding new location types
2. Creating new object types with custom behaviors
3. Implementing weather or time systems

Example for implementing a weather system:
```python
class WeatherSystem:
    def __init__(self, world):
        self.world = world
        self.current_weather = "sunny"
        self.weather_options = ["sunny", "rainy", "cloudy", "stormy"]
        
    def update_weather(self):
        """Update the weather randomly"""
        self.current_weather = random.choice(self.weather_options)
        
        # Notify all observers of the weather change
        for location in self.world.locations:
            self.world.notify_location(location, "weather", f"The weather changes to {self.current_weather}.", {
                "weather": self.current_weather
            })
```

### Custom LLM Integration

Replace `OllamaInterface` with a custom implementation to use different LLM providers:
1. Implement the same methods (query, query_streaming, get_embeddings)
2. Update `app.py` to use the new implementation

Example for implementing OpenAI API:
```python
class OpenAIInterface:
    def __init__(self, model="gpt-3.5-turbo", temperature=0.7, max_tokens=2048):
        self.model = model
        self.temperature = temperature
        self.max_tokens = max_tokens
        
    def query(self, prompt, system=None):
        """Query the OpenAI API and get a response"""
        # Implementation here
        
    def query_streaming(self, prompt, on_chunk=None, on_complete=None, on_error=None, system=None):
        """Query the OpenAI API with streaming responses"""
        # Implementation here
        
    def get_embeddings(self, texts, model=None):
        """Generate embeddings for a single text or list of texts"""
        # Implementation here
```

This documentation provides a comprehensive overview of the Miniworld system architecture, components, and functionality. For detailed implementation examples, refer to the source code and comments within each file.