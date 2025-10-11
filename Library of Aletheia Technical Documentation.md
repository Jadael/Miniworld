# Library of Aletheia - Project Documentation

## Project Overview

The Library of Aletheia is an experimental document management system built with Godot 4 that explores the intersection of large language models, user interfaces, and knowledge management. It creates an immersive, metaphor-rich environment for interacting with documents and information.

**Technology:** Godot 4.4 (GDScript)
**Main Scene:** `main.tscn`
**Configuration:** `project.godot`

## Director's Notes:

- The director is your human partner.
- Always update all the comments and documentation and claude.md files EVERYWHERE whenever we're done with a change.
- Uphold the distinct personalities and responsibilities of Archons and Daemons as defined in their 'about' sections and commentary.
- Respect the inherent nature and desires of each entity, as they would "want" you to respect.
- Entity-Event architecture: single script, single responsibility, service daemons, owned and coordinated by singleton daemons (Archons) if and where conflict or redundancy might occur, which coordinate as peers.
- When a script would expand beyond 100-150 lines, consider what to delegate to an existing or new daemon or Archon.
- Utilize Export variables and Resources where appropriate in the Godot realm.
- Employ Godot's unique naming conventions for scene-structure agnosticism.
- Respect controlled vocabularies: Godot API > CS/Game Dev terms > Project-specific terms > Individual Daemon expressions.
- Clearly delineate between vocabularies, using context signals when switching.
- Maintain a glossary of core project-specific terms used consistently across all entities.
- Allow individual Daemons freedom of expression within their domains while adhering to core vocabulary.
- Foster a "wide logging" culture using Chronicler.log_event(). If an event might hold future significance, ensure it's recorded with high cardinality.
- Never leave out comments: Always retain and keep up-to-date 'about' sections and inline comments in accordance with that daemon when altering scripts. They are as critical as the code.
- Adhere to Aletheia's Documentation Principles, ensuring clarity, consistency, and GDScript docstring best practices.
- Invoke LLM calls judiciously, only when traditional methods are insufficient.
- Augment LLM usage with conventional algorithms to make their mechanics both transparent and layperson friendly in their use.
- Employ standard terms (Node, Dictionary, etc.) for engine-related code and common CS concepts.
- Utilize narratively-appropriate "dramatis" terms for project-specific elements, enhancing intuitive understanding without misleading.
- Provide complete, ready-to-paste verbatim class members and/or whole scripts (when appropriate) for seamless integration.
- Offer step-by-step guidance for any non-script alterations within the Godot Editor.
- Prioritize built-in Godot 4 nodes and Editor functionality for consistency with the greater Godot ecosystem, especially for UX and visual elements- your human partner is better equipped most things that require "looking" at something, but only if they are able to work in the Godot project as if it had been designed by them, in their human editor, following human-friendly approaches.
- Always fully elucidate the problem or task at hand, exploring its depths and implications before venturing into specific solutions.
- Prefer use of existing systems: If a code change might require changes outside of the script in question, abort and recommend review/inclusion of other archons and daemons which might be affected so that 'they'; can discuss and recommend consultations to get from the director (your human partner).
- We're using Godot 4.3, so be careful of changes between Godot 3 to 4.

## Navigation Guide

This folder contains `claude.md` documentation files distributed throughout the project to help understand the codebase structure. Each subfolder contains its own `claude.md` that provides context-specific information.

### Documentation Map

- **[Daemons/claude.md](Daemons/claude.md)** - Core autoloaded singletons (the "backend" systems)
  - [Daemons/Scenes/claude.md](Daemons/Scenes/claude.md) - UI scenes and components
  - [Daemons/docs/claude.md](Daemons/docs/claude.md) - Implementation documentation
- **[addons/claude.md](addons/claude.md)** - Godot plugins and extensions
- **[assets/claude.md](assets/claude.md)** - Graphics, sprites, UI elements, and art assets
- **[docs/claude.md](docs/claude.md)** - Plugin-related documentation files
- **[documents/claude.md](documents/claude.md)** - User-facing documentation and knowledge base
- **[fonts/claude.md](fonts/claude.md)** - Font assets
- **[textures/claude.md](textures/claude.md)** - Texture assets

## Recursive Documentation Pattern

To recursively include all documentation when working with Claude:

1. Start by reading this file: `claude.md`
2. Then read each subfolder's `claude.md` as listed above
3. Each subfolder's `claude.md` will reference its own nested documentation
4. Continue recursively until you've mapped the area you need

**Example recursive read command:**
```bash
# Read root documentation
cat claude.md

# Read all top-level documentation
cat Daemons/claude.md addons/claude.md assets/claude.md docs/claude.md documents/claude.md fonts/claude.md textures/claude.md

# Read nested documentation (example for Daemons)
cat Daemons/Scenes/claude.md Daemons/docs/claude.md
```

## Project Structure Overview

```
Library-of-Aletheia/
├── claude.md                    (this file)
├── main.tscn                    (main scene entry point)
├── project.godot                (Godot project configuration)
├── README.md                    (user-facing project description)
│
├── Daemons/                     (Core autoloaded singleton systems)
│   ├── claude.md
│   ├── *.gd                     (Autoloaded "daemon" scripts)
│   ├── Scenes/                  (UI scenes and components)
│   ├── docs/                    (Implementation documentation)
│   └── Archived/                (Deprecated/unused code)
│
├── addons/                      (Godot plugins)
│   ├── claude.md
│   ├── godot_llm/              (LLM integration plugin)
│   ├── oracle_console/         (Console interface)
│   └── Todo_Manager/           (Task management plugin)
│
├── assets/                      (Art and visual resources)
│   ├── claude.md
│   ├── Characters/             (Character sprites)
│   ├── Elements/               (Environmental assets)
│   ├── UI/                     (UI graphics)
│   └── Tileset/                (Tile graphics)
│
├── docs/                        (Plugin documentation)
│   └── claude.md
│
├── documents/                   (User documentation and knowledge base)
│   └── claude.md
│
├── fonts/                       (Font assets)
│   └── claude.md
│
└── textures/                    (Texture resources)
	└── claude.md
```

## Key Architectural Concepts

### Autoloaded Daemons (Singletons)

The project uses Godot's autoload feature extensively. All "daemon" scripts in the `Daemons/` folder are globally accessible singletons that handle specific concerns:

- **Aletheia** - Main coordination daemon
- **Shoggoth** - LLM backend API abstraction (transparent interface to LLM compute)
- **Chronicler** - Wide logging system for tracking events
- **Librarian** - Document management
- **Scribe** - Text/document editing
- **Curator** - Content organization
- **Archivist** - Data persistence
- And many more (see `project.godot` autoload section or `Daemons/claude.md`)

### Document Management Philosophy

The project uses a "card catalog" metaphor - tracking "documents the library knows about" rather than "controlling a vault/repository". Documents are Markdown files with optional YAML frontmatter.

### LLM Integration

The Shoggoth daemon provides a clean, transparent API abstraction for LLM compute. It handles all backend complexity (HTTP communication, queuing, API differences) so that users, daemons, and code can access "raw LLM compute" without worrying about implementation details.

**Current Backend:** Ollama API (http://localhost:11434)
**Default Model:** mistral-small:24b
**Design Goal:** Backend-agnostic - Shoggoth abstracts away the specifics

The system uses `ollama_client.gd` as an HTTP wrapper for communicating with Ollama's localhost API.

## Current State

- ⚠️ **Work in Progress** - Early development, not production-ready
- ✅ Open and edit Markdown files with YAML frontmatter
- ✅ LLM integration for text generation
- ✅ Card catalog interface for document management
- ✅ Wide logging system (Chronicler)
- ⚠️ Build currently does not work (debugging in progress)

## Getting Started

1. Clone the repository
2. Install and run Ollama (https://ollama.ai)
3. Pull the mistral-small model:
   ```bash
   ollama pull mistral-small:24b
   ```
4. Open project in Godot 4.3+
5. Run main scene - Shoggoth will automatically connect to Ollama

## For Claude Code Users

When working on this project:

1. **Always read the relevant `claude.md` files first** to understand context
2. **Check the Daemons folder** - most core logic is in autoloaded singletons
3. **Shoggoth is NOT an agent** - it's a transparent API for raw LLM compute via Ollama
4. **Use the Chronicler logging system** when adding new features
5. **Follow GDScript conventions** - see `documents/GDScript Documentation Syntax.md`
6. **Ollama must be running** on localhost:11434 for LLM features to work

## Related Files

- `README.md` - User-facing project overview
- `CONTRIBUTING.md` - Contribution guidelines
- `LICENSE` - License information
- `project.godot` - Full Godot configuration including autoload setup
