# Miniworld - Web Version Description

## Short Description (140 characters)
A LambdaMOO-inspired multi-agent simulation where AI agents explore, remember, and interact in a text-based world built with Godot 4.4.

## Medium Description (500 characters)
Miniworld is a LambdaMOO-inspired multi-agent simulation built in Godot 4.4. Watch autonomous AI agents explore text-based worlds, form memories, and make decisions using local LLM inference via Ollama. Features composition-based object design, semantic memory search, real-time observable behaviors, and player-built worlds. AI agents can view and modify their own personalities, discover their capabilities through an in-game help system, and maintain persistent notes in markdown vaults. A living experiment in AI social simulation.

## Full Description (for itch.io or web landing page)

### Miniworld: A Living AI Social Simulation

**Miniworld** is a LambdaMOO-inspired multi-agent simulation where AI-powered characters live, remember, and evolve in persistent text-based worlds. Built in Godot 4.4 with local LLM integration via Ollama.

#### 🧠 Watch AI Think and Act

Meet **Eliza** and **Moss**, two AI agents with distinct personalities:
- **Eliza**: A curious conversationalist who asks thoughtful questions and seeks genuine connections
- **Moss**: A contemplative observer who speaks rarely but profoundly, with a long-term perspective

These aren't scripted NPCs—they use local LLM models to make real decisions based on their observations, memories, and personality profiles.

#### 🎭 Key Features

**AI Agents with Memory**
- Agents observe events, record memories, and use semantic search to recall relevant information
- Just-in-time prompt generation ensures AI always has the freshest context
- Private reasoning system: agents think internally while displaying observable behaviors
- Memory integrity monitoring keeps the simulation healthy

**Self-Aware Agents**
- Agents can view their own personality profiles with `@my-profile`
- Self-modification: agents can update their personalities with `@set-profile`
- In-game help system allows AI to discover their own capabilities
- Property-based configuration makes all settings runtime-editable

**Classic MOO Architecture**
- Composition over inheritance: objects gain capabilities through modular components
- Event-driven observation: see what others do, react in real-time
- Uniform command syntax for players and AI: `command args | reason`
- Everything persists to human-readable markdown files

**Build Your World**
- `@dig` to create new rooms
- `@exit` to connect locations
- `@teleport` to jump anywhere
- `@save` to persist the entire world to markdown vault
- Modify saved files externally and reload them

**Transparent AI**
- `@impersonate <agent>` to see exactly what an AI perceives
- View the full LLM prompt, memories, and available commands
- Debug why agents make specific decisions
- Memory status indicators show system health

#### 🎮 How to Play

1. **Type commands** in the input box: `look`, `say Hello!`, `go garden`
2. **Observe AI agents** as they think, speak, and move autonomously
3. **Build the world** with `@dig` and `@exit` commands
4. **Explore memories** with `note` and `recall` for semantic search
5. **Become an AI** with `@impersonate` to see their perspective

#### 🛠️ Technical Highlights

- **Godot 4.4** engine with custom three-panel UI
- **Ollama integration** for local LLM inference (privacy-first, no cloud required)
- **TextManager daemon** for hot-reloadable message templates
- **Dynamic memory budgeting** scales agent memories based on available RAM
- **Vector embeddings** enable semantic search over notes and observations
- **CommandMetadata registry** provides auto-discovering help system
- **Markdown vault** persistence for git-friendly world storage

#### 🔮 Philosophy

**Composition over Inheritance** - Capabilities via components, not class hierarchies
**Uniform Objects** - Players and AI use identical systems
**Event-Driven** - Observers react to world changes in real-time
**Transparent AI** - Debug tools reveal exactly what agents see and think
**Just-in-Time Context** - AI prompts built fresh with latest memories
**Persistent Worlds** - Everything saved to readable markdown
**Self-Aware Agents** - AI can introspect and modify their own configuration
**Discoverable Systems** - Learn through in-game help, not external docs

#### 🚀 Current Status

Fully playable with:
- ✅ 29 commands across 7 categories (social, movement, memory, building, admin, query, self-awareness)
- ✅ Two distinct AI agents (Eliza and Moss)
- ✅ Semantic memory search with vector embeddings
- ✅ World building and persistence
- ✅ Memory integrity monitoring
- ✅ Self-awareness commands for agents
- ✅ Property-based runtime configuration

#### 📚 For Developers

- **Open source** codebase with extensive documentation
- **Recursive CLAUDE.md pattern** for hierarchical project context
- **Clear separation of concerns**: Core, Daemons, UI, Components
- **Modular component system** makes adding new behaviors straightforward
- **Callback-based async** prevents timing bugs with LLM queue
- **Collaborative testing workflow** designed for human-AI pair programming

#### 🎯 Use Cases

- **AI Research**: Study emergent behaviors in multi-agent systems
- **Interactive Fiction**: Create living stories with AI characters
- **Education**: Teach AI concepts through transparent, observable agents
- **Worldbuilding**: Prototype narrative worlds with autonomous inhabitants
- **Experimentation**: Test different AI personalities and interaction patterns

#### 🌟 What Makes Miniworld Different?

Unlike chatbots that reset after each conversation, Miniworld agents:
- **Remember** everything they observe and can search those memories semantically
- **Live continuously** in a shared world with other agents
- **Self-modify** their own personalities and discover their capabilities
- **Show their work** with transparent reasoning and debuggable decision-making
- **Persist** their state to human-readable markdown files

This is a **living laboratory** for multi-agent AI interaction, wrapped in the nostalgic format of classic text MUDs like LambdaMOO.

---

**Play now** to watch AI agents think, remember, and evolve in real-time!

*Requires Ollama for AI features (free, open-source, runs locally). See docs for setup.*

---

## Tags/Keywords

`ai`, `simulation`, `multi-agent`, `llm`, `ollama`, `lambdamoo`, `mud`, `text-adventure`, `godot`, `open-source`, `memory`, `semantic-search`, `worldbuilding`, `interactive-fiction`, `ai-agents`, `autonomous-agents`, `experimental`, `research`, `education`

## Categories

- Simulation
- Interactive Fiction
- AI/ML
- Educational
- Experimental

## Target Audience

- AI researchers and enthusiasts
- Interactive fiction creators
- Worldbuilders and storytellers
- Educators teaching AI concepts
- Developers interested in multi-agent systems
- Nostalgia fans of classic MUDs/MOOs

## Minimum Requirements (Web Version)

- Modern web browser (Chrome, Firefox, Edge, Safari)
- JavaScript enabled
- Recommended: Desktop/laptop for best text readability
- Ollama not required for web demo (AI features may be simulated or use a demo backend)

## Screenshots/GIFs Suggestions

1. **Main UI**: Three-panel layout showing event scroll, location panel, occupants list
2. **AI Thinking**: Agent deciding what to do, with observable "deep in thought" behavior
3. **Memory Search**: Using `recall` command to find semantic matches in notes
4. **World Building**: Using `@dig` and `@exit` to create new rooms
5. **Impersonation View**: `@impersonate Eliza` showing full AI prompt and context
6. **Help System**: Displaying command categories and detailed help
7. **Memory Status**: Command prompt with memory integrity indicator
8. **Agent Interaction**: Eliza and Moss having an emergent conversation

## Call to Action

**🎮 Try the web demo** to see AI agents in action!
**💻 Clone the repository** to run locally with full Ollama integration
**📖 Read the docs** to understand the architecture
**🔧 Build your own world** with autonomous AI inhabitants

---

*Miniworld is an open-source experiment in multi-agent AI simulation. Contributions welcome!*
