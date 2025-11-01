## Director's Notes

- The director is your human partner
- Always update comments, documentation, and claude.md files when making changes
- When scripts exceed 100-150 lines, consider delegating to daemons
- Use Export variables, Resources, and Godot naming conventions
- Never leave out comments—they are as critical as the code
- Invoke LLM calls judiciously, augment with conventional algorithms
- Employ standard terms (Node, Dictionary) for engine concepts, narratively-appropriate "dramatis" terms for project-specific elements
- Prioritize built-in Godot 4.4 nodes and Editor functionality
- Prefer existing systems—if changes affect multiple scripts, consult other components first

---

## Recursive CLAUDE.md Documentation Pattern

**CRITICAL**: CLAUDE.md files exist at multiple directory levels. Each documents its directory's purpose, contents, relationship to project, and instructs maintaining this pattern recursively. See subdirectories for local context.

---

## Documentation Standards

### Git Workflow
- Director reviews commits via GitHub Desktop
- **DO NOT** run git commands automatically
- Inform director when changes are ready for review

### File Header Format
```gdscript
## ScriptName: Brief description
## Detailed explanation of purpose, role, patterns, related systems
## Dependencies: (if complex)
## Notes: (caveats/gotchas)
```

### Function/Variable Documentation
- Use docstrings with Args/Returns/Notes sections
- ALWAYS provide type hints: `func foo(x: Type) -> ReturnType`
- Use typed collections: `Array[Type]`, not `Array`
- Comment WHY, not WHAT; explain non-obvious logic

### Code Quality
- Functions under 50 lines; extract helpers for complex logic
- Early returns to reduce nesting
- snake_case for everything except classes
- Fix linting: type mismatches, unused vars (prefix `_`), untyped collections

### Verification After Changes
1. Test project—verify no errors
2. Check all cross-references accurate
3. Update CLAUDE.md/ARCHITECTURE.md if patterns change
4. Ensure code understandable to unfamiliar readers

---

## Key Terminology (Project Glossary)

**Core Concepts:**
- **WorldObject**: Base class for everything (MOO-style)
- **Component**: Modular behavior (composition over inheritance)
- **Daemon**: Autoloaded singleton (WorldKeeper, EventWeaver, Shoggoth, TextManager)
- **Actor/Thinker/Memory/Location**: Components for commands, AI, observations, navigation
- **Verb/Property**: MOO-style methods and key-value storage

**Use these terms consistently; don't invent synonyms.**

---

## Established Patterns

### Daemon Callback Management
**DO**: Daemon manages callbacks internally via Dictionary
```gdscript
var pending_callbacks: Dictionary = {}  # task_id → callback
func generate_async(prompt: Variant, profile: String, callback: Callable) -> String:
	pending_callbacks[task_id] = callback
	# Later: callback.call(result); pending_callbacks.erase(task_id)
```
**DON'T**: Temporary signal connections (cause null reference errors)

### Signal vs. Callback Decision
- **Signals**: Multiple listeners, loose coupling, event propagation
- **Callbacks**: Single caller needs specific result, daemon manages lifecycle
- **Both**: General system observes (signal) AND caller needs result (callback)

### Just-in-Time Prompt Generation
**Problem**: Queued prompts become stale while waiting for LLM
**Solution**: Pass Callable to `Shoggoth.generate_async()` that builds prompt when task executes
```gdscript
var prompt_generator: Callable = func() -> String:
	_broadcast_thinking_behavior(location)  # Observable at right moment
	return _construct_prompt(_build_context())  # Fresh context
Shoggoth.generate_async(prompt_generator, profile, callback)
```
**Critical**: Shoggoth defers next task after completion to allow event propagation

### Base Model Support
**Pattern**: Universal prompt structure and API mode optimized for base models while maintaining instruct model effectiveness
- **API Mode**: Uses `/api/generate` instead of `/api/chat` for simpler, faster single-line responses
- **Prompt structure**: Identity → Commands → Notes → Transcript → Situation → `> ` prompt
- **Key insight**: Transcript placement shows outcomes, not echoed commands - prevents pattern replication
- **Command prompt**: `"Your next command:\n> "` guides next-token prediction toward valid command
- **Stop token**: `["\n"]` passed to Ollama for server-side early termination
- **Response parser**: Extracts first non-empty line (defense in depth)
- **Universal**: No model type detection needed—works for base, instruct, and reasoning models
**Why transcript placement matters**: Base models learn from immediate context. Recent memories show outcomes of actions (not command echoes) to prevent models from reinforcing patterns they see. Successful commands show only narrative results; failed commands show full context (what was attempted, why it failed, suggestions).
**Memory display strategy**:
  - **Successful commands**: Show only narrative results (e.g., "You head to the garden."), no command echo
  - **Failed commands**: Show enhanced explanation including attempted command, error reason, and suggestions (e.g., "You tried: examine nonexistent\nThis failed because: You don't see that here.\nDid you mean: try 'look' to see what's available?")
  - **Reasoning display**: Stored in metadata and shown in separate "RECENT REASONING" section after memories
  - Shows last 3 unique reasonings (duplicates auto-filtered) to prevent repetitive pattern learning
  - Case-insensitive comparison ensures similar reasonings are detected as duplicates
  - This prevents smaller models from learning to echo reasoning in parentheses instead of using | separator
  - Separates narrative outcomes from internal reasoning to avoid pattern replication
**Why generate mode**: Single-response use cases don't need chat API overhead. Generate mode is faster and simpler for both base and instruct models.
**Example**: `comma-v0.1-2t` (public-domain-only base model) generates valid commands consistently with this structure

### MOO-Style Command Syntax with Reasoning
**Syntax**: `command args | reason`
- `|` separator extracts optional private reasoning
- Reasoning recorded in memory, not broadcast
- Unified for players and AI agents

### Property-Based Configuration
**Pattern**: Runtime-editable config as WorldObject properties, not hardcoded variables
```gdscript
# Set defaults in _on_added
if not owner.has_property("thinker.profile"):
	owner.set_property("thinker.profile", default_profile)
# Access via getters
func get_profile() -> String:
	return owner.get_property("thinker.profile") if owner else default
```
**Naming**: `component.setting` (e.g., `thinker.profile`, `thinker.think_interval`)

### Self-Aware Agent Commands
Actors view/modify own configuration:
- `@my-profile`, `@my-description` - View self
- `@set-profile -> <text>`, `@set-description -> <text>` - Update (persists to vault)
- Physical changes broadcast observable behavior; mental changes private

### Help System and Command Metadata
**CommandMetadata** (command_metadata.gd): Central registry of all commands with categories, syntax, examples
- `help`, `help <command>`, `help <category>`, `commands`
- Alias resolution automatic
- AI agents discover capabilities via help system

### LambdaMOO-Compatible Command Parser
**CommandParser** (Core/command_parser.gd): Full LambdaMOO spec
- Quote-aware tokenization: `put "yellow bird" in clock`
- 14 preposition sets with multi-word support
- Object resolution: `#-1` (nothing), `#-2` (ambiguous), `#-3` (failed)
- Keywords: "me", "here"; prefix matching with priority
- Wildcard verbs: `*`, `foo*`, `foo*bar`
- Shortcuts: `"` (say), `:` (emote), `;` (eval)
- Returns `ParsedCommand` with verb, dobj, prep, iobj, reason, args

### Vault-Based Text Management (TextManager)
**Pattern**: All user-facing text/config in `user://vault/` markdown files
- Auto-migrates from `res://vault/` defaults on first run
- Variable substitution: `{actor}`, `{text}`, `{target}`
- Hot-reloadable via `@reload-text`
- Dot notation keys: `"commands.category.verb.message_type"`

**Structure**:
```
user://vault/
├── text/commands/        # Command messages (social.md, movement.md, etc.)
│   └── behaviors/        # Observable behavior templates
└── config/               # AI/LLM/memory settings
```

**API**:
```gdscript
TextManager.get_text(key: String, vars: Dictionary = {}) -> String
TextManager.get_config(key: String, default: Variant = null) -> Variant
TextManager.reload() -> void
```

---

## Development Workflow

### Collaborative Testing
Godot 4.4 lacks headless mode—testing is collaborative:
- **Claude**: Implements, adds debug logging, analyzes logs, proposes fixes
- **Director**: Runs project, provides visual feedback and log output, tests scenarios
- **Process**: Claude adds logging → Director tests → Claude analyzes → repeat

**Key**: Claude cannot run/test directly; all runtime behavior reported by director. Debug logging essential for remote diagnosis.

---

## Script Organization

1. File header (##)
2. extends/class_name
3. Signals
4. Constants
5. @export vars
6. Public vars
7. Private vars (_prefix)
8. Lifecycle methods (_ready, _process)
9. Public methods
10. Private methods
11. Signal callbacks
12. Static helpers

**Spacing**: One line between methods, two between major sections
