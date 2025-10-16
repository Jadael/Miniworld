## Director's Notes:

- The director is your human partner.
- Always update all the comments and documentation and claude.md files EVERYWHERE whenever we're done with a change.
- Respect the inherent nature and desires of each entity, as they would "want" you to respect.
- When a script would expand beyond 100-150 lines, consider what to delegate to an existing or new daemon.
- Utilize Export variables and Resources where appropriate in the Godot realm.
- Employ Godot's unique naming conventions for scene-structure agnosticism.
- Clearly delineate between vocabularies, using context signals when switching.
- Maintain a glossary of core project-specific terms used consistently across all entities.
- Never leave out comments: Always retain and keep up-to-date 'about' sections and inline comments in accordance with that daemon when altering scripts. They are as critical as the code.
- Invoke LLM calls judiciously, only when traditional methods are insufficient.
- Augment LLM usage with conventional algorithms to make their mechanics both transparent and layperson friendly in their use.
- Employ standard terms (Node, Dictionary, etc.) for engine-related code and common CS concepts.
- Utilize narratively-appropriate "dramatis" terms for project-specific elements, enhancing intuitive understanding without misleading.
- Prioritize built-in Godot 4 nodes and Editor functionality for consistency with the greater Godot ecosystem, especially for UX and visual elements- your human partner is better equipped most things that require "looking" at something, but only if they are able to work in the Godot project as if it had been designed by them, in their human editor, following human-friendly approaches.
- Offer step-by-step guidance for any non-script alterations within the Godot Editor.
- Always fully elucidate the problem or task at hand, exploring its depths and implications before venturing into specific solutions.
- Prefer use of existing systems: If a code change might require changes outside of the script in question, abort and recommend review/inclusion of other archons and daemons which might be affected so that 'they'; can discuss and recommend consultations to get from the director (your human partner).
- We're using Godot 4.4, so be careful of changes between Godot 3 to 4, especially when researching on the web.

---

## Recursive CLAUDE.md Documentation Pattern

**CRITICAL**: This project uses a recursive documentation system where CLAUDE.md files exist at multiple levels of the directory structure.

### The Pattern

Each directory should have its own CLAUDE.md that:
1. **Explains the directory's purpose** - What files belong here and why
2. **Documents its contents** - Brief description of each file/subdirectory
3. **Shows its relationship to the project** - How this directory fits into the larger architecture
4. **Repeats these instructions** - Ensures Claude Code maintains this pattern recursively

### Your Responsibilities

When working in ANY directory:
- **Check for CLAUDE.md** - Read it to understand the local context
- **Create if missing** - If a directory lacks CLAUDE.md, create one following this pattern
- **Update when changing files** - Keep CLAUDE.md synchronized with actual directory contents
- **Maintain the recursion instruction** - Every CLAUDE.md should instruct future Claude Code sessions to maintain CLAUDE.md files in subdirectories

### Example Structure

```
G:\_workbench\miniworld/
├── CLAUDE.md              # Root: Overall project principles (this file)
├── Core/
│   ├── CLAUDE.md          # Core: WorldObject, components, command parser
│   └── components/
│       └── CLAUDE.md      # Components: Actor, Thinker, Memory, Location, etc.
├── Daemons/
│   └── CLAUDE.md          # Daemons: Singleton managers (WorldKeeper, EventWeaver, Shoggoth)
├── UI/
│   └── CLAUDE.md          # UI: Game interface and player interaction
├── docs/
│   └── CLAUDE.md          # Docs: Architecture and design documentation
```

### Template for Subdirectory CLAUDE.md

```markdown
# [Directory Name]

## Purpose
[What this directory contains and why it exists]

## Contents
- **file1.gd** - [Brief description]
- **file2.gd** - [Brief description]
- **subdirectory/** - [What's in here]

## Relationship to Project
[How this fits into the larger Miniworld architecture]

## Maintenance Instructions
When working in this directory, maintain this CLAUDE.md file and create/update CLAUDE.md files in any subdirectories following the recursive documentation pattern described in the root CLAUDE.md.
```

---

## Code Documentation and Maintenance Standards

### Before Making Changes: Commit Clean Starting Point

**IMPORTANT:** Before beginning any documentation or refactoring work:

1. Check the current git status to understand uncommitted changes
2. If there are uncommitted changes that represent a clean, working state:
   - Create a commit with a message like: "Clean starting point before documentation pass"
   - This creates a rollback point if needed
3. If there are uncommitted experimental changes:
   - Stash them first, or discuss with the director whether to commit or discard
4. Only proceed with documentation changes after establishing this baseline

### Recursive Documentation Protocol

Use this protocol whenever documenting or refactoring any part of the codebase:

#### Phase 1: Analysis
1. Identify all files that need documentation updates
2. Note any cross-references between files (imports, dependencies, signal connections)
3. Check for outdated comments that reference changed functionality
4. Identify linting issues (type mismatches, unused variables, etc.)

#### Phase 2: Documentation Standards
Apply these standards to ALL scripts:

**File Header Format:**
```gdscript
## ScriptName: Brief one-line description
##
## Detailed multi-line description explaining:
## - What this script does
## - Its role in the system
## - Key concepts or patterns it uses
## - Related scripts or systems
##
## Dependencies: (if complex)
## - Specific nodes or autoloads this relies on
##
## Notes: (if needed)
## - Any important caveats or gotchas
```

**Function Documentation:**
```gdscript
func function_name(param1: Type, param2: Type) -> ReturnType:
	"""Brief description of what this function does.

	Detailed explanation if the function is complex or non-obvious.

	Args:
		param1: Description of parameter
		param2: Description of parameter

	Returns:
		Description of return value

	Notes:
		Any important caveats, side effects, or usage notes
	"""
	# Implementation with inline comments for complex logic
```

**Variable Documentation:**
```gdscript
## Brief description of what this variable stores
var important_variable: Type = default_value

## Longer explanation for complex data structures
## - Key: description
## - Value: description
var complex_dict: Dictionary = {}

## Signal documentation
signal event_occurred(data: Dictionary)  ## Emitted when X happens
```

**Type Annotations:**
- ALWAYS provide type hints for function parameters and return types
- Use typed arrays: `Array[SpecificType]` not `Array`
- Use explicit types for variables where not obvious from initialization
- Avoid untyped variants where possible

**Inline Comments:**
- Add comments for non-obvious logic
- Explain WHY, not WHAT (code shows what)
- Mark TODOs and FIXMEs clearly with context
- Use section comments for logical blocks in long functions

#### Phase 3: Linting Standards

**Fix These Issues:**
- Type mismatches in ternary operators
- Unused variables and parameters (prefix with `_` if intentionally unused)
- Missing return type annotations
- Untyped collections (Array, Dictionary without types)
- Incorrect null safety patterns
- GDScript warnings emitted by the editor

**Code Quality:**
- Keep functions under 50 lines where practical
- Extract complex logic into well-named helper functions
- Use early returns to reduce nesting
- Prefer composition over inheritance
- Follow Godot naming conventions (snake_case for everything except classes)

#### Phase 4: Cross-File Consistency

When updating documentation:
1. Update ALL files that reference the changed functionality
2. Update CLAUDE.md if new patterns or standards emerge
3. Update any markdown documentation files (ARCHITECTURE.md, etc.)
4. Ensure terminology is consistent across all documentation

#### Phase 5: Verification

After documentation changes:
1. Run the project and verify no errors introduced
2. Check that all warnings in Godot editor are addressed or documented as intentional
3. Verify all cross-references are still accurate
4. Confirm that someone unfamiliar with the code could understand it

### After Successful Changes: Commit and Update

**IMPORTANT: Git Commit Workflow**
- The director prefers to review and make commits via GitHub Desktop
- DO NOT create git commits automatically
- DO NOT run `git add`, `git commit`, or `git push` commands
- After completing work, inform the director that changes are ready for review
- The director will stage, review, and commit changes using their preferred tools

After completing documentation work:

1. Test the project to ensure nothing broke
2. Review all changed files to ensure consistency
3. Inform the director that changes are ready for commit review
4. Update this CLAUDE.md section with any new standards or patterns discovered
5. Consider updating ARCHITECTURE.md or other high-level docs if significant insights emerged

### Maintaining These Standards

**When adding new code:**
- Apply these standards from the start
- Don't "document later" - document as you write
- If a function or script grows complex enough to need documentation, it probably needs refactoring

**When modifying existing code:**
- Update ALL related documentation
- Check if changes affect other components
- Update inline comments if logic flow changed
- Verify function docstrings still match behavior

**Regular maintenance:**
- Periodically review documentation for accuracy
- Look for outdated comments referring to old functionality
- Update examples in documentation if APIs change
- Keep this CLAUDE.md updated with emerging patterns

### Key Terminology (Project Glossary)

**Miniworld Core Concepts:**
- **WorldObject**: Base class for everything in the world (MOO-style)
- **Component**: Modular behavior attached to WorldObjects (composition over inheritance)
- **Daemon**: Autoloaded singleton managing a system aspect (WorldKeeper, EventWeaver, Shoggoth)
- **Actor**: Component enabling object to perform commands and observe events
- **Thinker**: Component enabling AI-driven autonomous decision making
- **Memory**: Component storing observations and experiences
- **Location**: Component making a WorldObject into a navigable room
- **Verb**: MOO-style callable method on an object
- **Property**: Arbitrary key-value data storage on objects

**System-Level Terms:**
- **Shoggoth**: AI/LLM interface daemon, abstracts inference backends
- **WorldKeeper**: Object registry and lifecycle manager
- **EventWeaver**: Event propagation and observation system
- **Ollama**: LLM backend (currently using Ollama API)

**Follow these conventions:**
- Use these terms consistently across all code and documentation
- Don't invent synonyms - if referring to a WorldObject, call it a WorldObject
- When introducing new concepts, add them to this glossary
- Use standard Godot/CS terms for engine features (Node, Signal, etc.)

### Script Organization Standards

**File Structure:**
1. File header documentation (## comments)
2. extends and class_name declarations
3. Signal declarations with documentation
4. Constants (UPPER_SNAKE_CASE)
5. Exported variables (@export) with documentation
6. Public variables with documentation
7. Private variables (prefixed with _) with documentation
8. Built-in lifecycle methods (_ready, _process, etc.)
9. Public methods with documentation
10. Private methods with documentation
11. Signal callbacks (group together)
12. Helper functions (static if possible)

**Spacing:**
- One blank line between methods
- Two blank lines between major sections
- Group related methods together with section comments if file is long

### Comments Are Code

Remember: In this project, comments and documentation are as critical as the code itself. Incomplete documentation is a bug, not a nice-to-have. Every entity in the system deserves clear documentation of its purpose, behavior, and relationships.

---

## Established Patterns and Anti-Patterns

### Daemon Callback Management (Shoggoth Pattern)

**DO**: Have the daemon manage all callbacks internally
```gdscript
# In Shoggoth (daemon)
var pending_callbacks: Dictionary = {}  # task_id → callback

func generate_async(prompt: String, system_prompt: String, callback: Callable) -> String:
    var task_id = submit_chat(messages)
    pending_callbacks[task_id] = callback  # Register callback
    return task_id

func _emit_task_completion(result: String) -> void:
    var task_id = current_task.get("id", "unknown")

    # Invoke registered callback
    if pending_callbacks.has(task_id):
        var callback: Callable = pending_callbacks[task_id]
        pending_callbacks.erase(task_id)  # Remove after use
        callback.call(result)

    task_completed.emit(task_id, result)  # Also emit signal
```

**DON'T**: Have callers create temporary signal connections
```gdscript
# ANTI-PATTERN - causes null reference errors
func generate_async_WRONG(prompt: String, callback: Callable) -> String:
    var task_id = submit_chat(messages)

    var on_complete: Callable = func(id: String, result: String):
        if id == task_id:
            callback.call(result)
            task_completed.disconnect(on_complete)  # ❌ Can become null!

    task_completed.connect(on_complete)
    return task_id
```

**Rationale**:
- Daemons are singletons - they should be the single source of truth
- Temporary connections create lifetime management issues
- Dictionary lookups are simple and reliable
- Callers don't need to understand signal mechanics

### Signal vs. Callback Decision Tree

**Use Signals when**:
- Multiple listeners need to know about events
- Loose coupling is desired
- Event propagation through scene tree
- Example: `EventWeaver` broadcasting observations

**Use Callbacks when**:
- Single caller needs specific task result
- One-shot operations
- The daemon manages task lifecycle
- Example: `Shoggoth.generate_async()` with completion callback

**Use Both when**:
- General system needs to observe (signal)
- AND specific caller needs result (callback)
- Example: Shoggoth emits `task_completed` signal AND invokes registered callback

### Just-in-Time Prompt Generation (Shoggoth Pattern)

**Problem**: When AI agents queue prompts for LLM inference, the prompt is built immediately but may not execute for several seconds (or longer if other tasks are queued). During this wait time, the agent may observe new events, execute commands, or receive new memories that should be included in the prompt.

**Solution**: Pass a Callable (prompt generator) instead of a String to `Shoggoth.generate_async()`. Shoggoth stores the Callable in the task queue and invokes it just-in-time when the task is ready to execute, ensuring maximum freshness.

**Implementation** (thinker.gd:97-134):
```gdscript
func _think() -> void:
	# Don't build prompt here!
	if Shoggoth and Shoggoth.ollama_client:
		# Pass a callable that builds the prompt fresh when Shoggoth is ready
		var prompt_generator: Callable = func() -> String:
			var fresh_context: Dictionary = _build_context()
			return _construct_prompt(fresh_context)

		Shoggoth.generate_async(prompt_generator, profile, Callable(self, "_on_thought_complete"))
```

**Shoggoth Support** (shoggoth.gd:689-734):
```gdscript
func generate_async(prompt: Variant, system_prompt: String, callback: Callable) -> String:
	"""Submit an async generation task with a callback function.

	Args:
		prompt: Either a String (prompt text) or a Callable that returns a String.
		        If a Callable is provided, it will be invoked just-in-time when
		        Shoggoth is ready to execute the task, ensuring maximum freshness.
		...
	"""
	var task = {
		"prompt_generator": prompt,  # Can be String or Callable
		"mode": "chat_async"
	}
	task_queue.append(task)
```

**Just-in-Time Resolution** (shoggoth.gd:465-530):
```gdscript
func _execute_current_task(options: Dictionary) -> void:
	if mode == "chat_async":
		var prompt_generator = current_task["prompt_generator"]
		var prompt_text: String = ""

		# Resolve prompt: either invoke Callable or use String directly
		if prompt_generator is Callable:
			print("[Shoggoth] Invoking prompt generator just-in-time...")
			prompt_text = prompt_generator.call()
		elif prompt_generator is String:
			prompt_text = prompt_generator
```

**Benefits**:
- Agents always have most recent memories and observations
- Context includes events that occurred while waiting in queue
- No stale prompts with outdated information
- Minimal code changes required from callers
- Backwards compatible (String prompts still work)

**When to Use**:
- AI agents that need fresh context for decision-making
- Any LLM task where the world state might change during queuing
- Tasks with long queue wait times

**When NOT to Use**:
- One-shot prompts that don't depend on changing state
- Prompts that are expensive to generate (cache them instead)
- Simple text generation that doesn't need world context

### MOO-Style Command Syntax with Reasoning

**Pattern**: Both players and AI agents use unified MOO-style command syntax with optional reasoning.

**Syntax**: `command args | reason`
- Everything before `|` is the command and its arguments
- Everything after `|` is optional reasoning/commentary
- The `|` separator itself is optional
- Reasoning is private (recorded in memory, not broadcast to others)

**Example Commands**:
```gdscript
# Simple command without reasoning
"look"

# Command with args, no reasoning
"go garden"

# Command with reasoning (for introspection and memory)
"say Hello there! | Trying to make a connection"
"go library | Want to find a quiet place to think"
"examine Moss | Curious about this contemplative being"
```

**Implementation Details**:

1. **Player Input** (game_controller_ui.gd:264-319):
   - Parses `|` separator to extract reason
   - Passes reason as third parameter to `execute_command()`

2. **AI Agent Output** (thinker.gd:272-325):
   - LLM generates single-line response: `command args | reason`
   - Parser splits on `|` to extract command and reason
   - Passes reason to `execute_command()`

3. **Command Execution** (actor.gd:83-146):
   - `execute_command(command, args, reason)` accepts optional reason
   - Emits `command_executed(command, result, reason)` signal
   - Caches `last_reason` for inspection

4. **Memory Recording** (ai_agent.gd:68-86):
   - Format: `"> command | reason\nresult"`
   - Reason included in transcript if present
   - Creates readable memory log for AI context

**Benefits**:
- Unified syntax across player and AI interactions
- AI agents can record decision-making rationale
- Players can optionally add context to their commands
- Memory transcripts show both actions and reasoning
- Supports introspection and learning from past decisions

**Notes**:
- Reasoning is stored but not displayed to other actors
- Keeps command syntax simple while allowing rich internal state
- Compatible with existing MOO-style command shortcuts (l, ', :)

### Property-Based Configuration System

**Pattern**: Store all runtime-editable configuration as WorldObject properties instead of hardcoded component variables.

**Problem**: Hardcoded profiles, prompts, and settings in component code require code changes to customize agent behavior. This prevents in-game editing and runtime adaptation.

**Solution**: Use WorldObject's property system for all configuration data. Components read properties via getters and write via setters, enabling runtime modification and vault persistence.

**Implementation** (thinker.gd:56-114):
```gdscript
# Set properties as defaults during _on_added
if not owner.has_property("thinker.profile"):
    owner.set_property("thinker.profile", _deprecated_profile)
if not owner.has_property("thinker.think_interval"):
    owner.set_property("thinker.think_interval", _deprecated_think_interval)

# Access via getters/setters
func get_profile() -> String:
    if owner and owner.has_property("thinker.profile"):
        return owner.get_property("thinker.profile")
    return _deprecated_profile

func set_profile(new_profile: String) -> void:
    if owner:
        owner.set_property("thinker.profile", new_profile)
```

**Benefits**:
- Properties persist to vault automatically when saved
- Can be modified at runtime via commands (@edit-profile, @set-profile)
- AI agents can view and modify their own configuration
- No code changes needed to customize individual agents
- Supports per-agent customization of prompts, intervals, etc.

**Property Naming Convention**:
- Use dot notation: `component.setting` (e.g., `thinker.profile`, `thinker.think_interval`)
- Makes property ownership clear
- Prevents naming collisions between components
- Supports hierarchical organization

**When to Use Properties vs. Variables**:
- **Properties**: Runtime-editable data, agent-specific configuration, persisted state
- **Variables**: Transient state, cached values, internal counters
- **Deprecated Variables**: Keep as fallback for backwards compatibility during migration

### Self-Aware Agent Commands

**Pattern**: Actors can view and modify their own configuration, enabling self-reflection and self-modification.

**Commands**:
- `@my-profile` - View own personality profile and think interval
- `@my-description` - View how others see you when examined
- `@set-profile -> <text>` - Update personality (affects LLM system prompt)
- `@set-description -> <text>` - Update physical description

**Implementation** (actor.gd:1218-1409):
```gdscript
func _cmd_my_profile(_args: Array) -> Dictionary:
    if not owner.has_component("thinker"):
        return {"success": false, "message": "No thinker component"}

    var thinker: ThinkerComponent = owner.get_component("thinker")
    # Display profile and interval...

func _cmd_set_profile(args: Array) -> Dictionary:
    # Parse args for -> separator
    # Update thinker.profile property
    # Save to vault via AIAgent._save_agent_to_vault(owner)
    # Broadcast observable behavior (others see "pauses in contemplation")
```

**Key Design Decisions**:
- **Full Parity**: Players and AI agents have identical access to these commands
- **Observable Behavior**: Physical changes broadcast events ("adjusts appearance")
- **Private Content**: Mental changes are private (others don't see new profile text)
- **Immediate Persistence**: Changes saved to vault automatically
- **Self-Modification**: Agents can reprogram their own personality

**Benefits**:
- Enables AI agent self-awareness and introspection
- Supports emergent agent evolution
- Players can customize characters without code changes
- Testing different personalities is trivial
- Foundation for future self-improving agents

### Help System and Command Metadata

**Pattern**: Centralized command registry with metadata for auto-discovering help system.

**Architecture**:
1. **CommandMetadata** (command_metadata.gd) - Central registry of all commands
2. **Help Commands** (actor.gd) - User-facing help interface
3. **Command Discovery** - Agents can learn their own capabilities

**Command Registry Structure**:
```gdscript
const COMMANDS = {
    "look": {
        "aliases": ["l"],
        "category": "social",
        "syntax": "look",
        "description": "Observe your current location and who's present",
        "example": "look"
    },
    # ... 29 commands total
}

const CATEGORIES = {
    "social": "Interact with others and your environment",
    "movement": "Navigate through the world",
    "memory": "Personal notes, recall, and reflection",
    "self": "Self-awareness and self-modification",
    "building": "Create and modify world structure",
    "admin": "Administrative and debugging commands",
    "query": "Get information about the world and commands"
}
```

**Help Commands**:
- `help` or `?` - Show category overview
- `help <command>` - Detailed help for specific command (with alias resolution)
- `help <category>` - List all commands in category
- `commands` - Compact list of all commands

**AI Agent Integration** (thinker.gd:322-323):
```gdscript
command_list = [
    # ... existing commands ...
    "help [command|category]: Get help on commands (try 'help social' or 'help say')",
    "commands: List all available commands"
]
```

**Benefits**:
- Single source of truth for command documentation
- AI agents can discover their own capabilities
- Alias resolution automatic (e.g., "help l" shows "look")
- Easy to maintain as commands are added
- Supports both player and AI agent learning

**Future Enhancements**:
- Vault-based help text (editable markdown per-world)
- True reflection-based discovery (scan for _cmd_* methods)
- Custom @help annotations in docstrings
- Dynamic command registration from plugins

### LambdaMOO-Compatible Command Parser

**Pattern**: Full implementation of the LambdaMOO command parser spec for maximum generosity and precision.

**Architecture**:
1. **CommandParser** (Core/command_parser.gd) - Static parser class
2. **ParsedCommand** - Result structure with all parsed components
3. **Integration** - Used by both player input and AI agent output

**Parser Features (LambdaMOO Spec Complete)**:

1. **Quote-Aware Tokenization**:
   - Double quotes group multi-word arguments: `put "yellow bird" in clock`
   - Backslash escapes: `say He said \"hello\"`
   - Whitespace handling: `foo "bar mumble" baz` → ["foo", "bar mumble", "baz"]

2. **Prepositional Phrase Parsing**:
   - Matches 14 preposition sets from MOO spec
   - Multi-word prepositions: "in front of", "on top of", "out of"
   - Earliest match wins: `foo as bar to baz` uses "as", not "to"
   - Three command forms supported:
     - `verb` → look
     - `verb dobj` → examine bird
     - `verb dobj prep iobj` → put bird in cage

3. **Object Resolution with MOO Semantics**:
   - Special values: `#-1` (nothing), `#-2` (ambiguous), `#-3` (failed)
   - Direct ID lookup: `#123` format
   - Keywords: "me" (actor), "here" (location)
   - Scoped search: location contents + actor inventory first
   - Prefix matching with priority: exact matches beat prefix matches
   - Alias support through WorldObject.aliases array

4. **Wildcard Verb Matching**:
   - `*` matches anything: `*` → any verb
   - Mid-star: `foo*bar` matches "foo", "foob", "fooba", "foobar"
   - End-star: `foo*` matches any string starting with "foo"
   - No star: exact match required

5. **Built-in Shortcuts**:
   - `"` → `say` (speech)
   - `:` → `emote` (action)
   - `;` → `eval` (future: code evaluation)

6. **Reasoning Separator**:
   - `|` separator extracts optional reasoning: `go garden | Want to explore`
   - Reasoning is private (stored in memory, not broadcast)
   - Compatible with all command forms

**Usage Example**:
```gdscript
# Parse a complex command
var parsed: CommandParser.ParsedCommand = CommandParser.parse(
    'put "yellow bird" in cuckoo clock | Keeping it safe',
    actor,
    location
)

# Result:
# parsed.verb = "put"
# parsed.dobjstr = "yellow bird"
# parsed.dobj = <WorldObject> or #-1/#-2/#-3
# parsed.prepstr = "in"
# parsed.iobjstr = "cuckoo clock"
# parsed.iobj = <WorldObject> or #-1/#-2/#-3
# parsed.reason = "Keeping it safe"
# parsed.args = ["yellow bird", "in", "cuckoo", "clock"]
# parsed.argstr = "yellow bird in cuckoo clock"
```

**Integration Points**:

1. **Player Input** (game_controller_ui.gd:265-292):
```gdscript
func _on_command_submitted(text: String) -> void:
    var location: WorldObject = player.get_location()
    var parsed: CommandParser.ParsedCommand = CommandParser.parse(text, player, location)
    actor_comp.execute_command(parsed.verb, parsed.args, parsed.reason)
```

2. **AI Agent Output** (thinker.gd:347-384):
```gdscript
func _on_thought_complete(response: String) -> void:
    var location: WorldObject = owner.get_location()
    var parsed: CommandParser.ParsedCommand = CommandParser.parse(command_line, owner, location)
    actor_comp.execute_command(parsed.verb, parsed.args, parsed.reason)
```

**Parser API**:

```gdscript
# Main parsing function
static func parse(input: String, actor: WorldObject, location: WorldObject) -> ParsedCommand

# Verb matching with wildcards
static func match_verb(verb_input: String, verb_pattern: String) -> bool

# Preposition set lookup
static func get_prep_set(prep: String) -> String

# Preposition specifier matching
static func matches_prep_spec(found_prep: String, spec: String) -> bool
```

**Benefits**:
- Unified parsing for players and AI agents
- Full LambdaMOO compatibility for familiar UX
- Robust quote and escape handling
- Generous matching reduces user frustration
- Extensible for future verb-based programming

**Future Enhancements**:
- Verb resolution: scan objects for matching verb names
- Argument specifiers: `this`, `any`, `none` for dobj/iobj
- $do_command() hook for custom parsing
- `.program` and built-in MOO commands
- Flush command and PREFIX/SUFFIX support

**Testing Considerations**:
- Quote edge cases: `"foo"bar"baz"` should parse correctly
- Preposition precedence: multiple preps use earliest match
- Object ambiguity: proper #-2 return when multiple matches
- Alias matching: both exact and prefix work correctly
- Wildcard verbs: all three forms (* mid-star, end-star, no-star)

---

## Development and Testing Workflow

### Collaborative Testing in Godot Editor

**Important Context**: Godot 4.4 does not have a headless mode for running projects without graphics. This means that development and testing of Miniworld is a collaborative process between Claude Code and the director (human partner).

**Testing Workflow**:
1. **Claude Code's Role**:
   - Analyzes codebase and implements changes
   - Adds debug logging when investigating issues
   - Interprets log output and user reports
   - Proposes fixes based on analysis

2. **Director's Role**:
   - Runs the project in Godot Editor
   - Provides visual feedback and observations
   - Copies log output from Godot's console
   - Tests specific scenarios and interactions
   - Reports unexpected behavior with context

3. **Collaborative Debug Process**:
   - Claude adds comprehensive logging to investigate issues
   - Director runs project and provides log output
   - Claude analyzes logs and proposes solutions
   - Director tests fixes and confirms resolution
   - Claude removes debug logging once issue is resolved

**Key Principles**:
- Claude cannot "run" or "test" the project directly
- All runtime behavior must be observed and reported by the director
- Debug logging is essential for diagnosing issues remotely
- Clear communication about what to test and what to observe is critical
- The director has visual and interactive access that Claude lacks

**Example Debug Workflow**:
```gdscript
# Claude adds detailed logging
print("[Component] _on_added called for: %s" % obj.name)
print("[Component] Connecting to signal...")
if signal.connect(handler) == OK:
    print("[Component] Successfully connected!")
else:
    push_warning("[Component] Failed to connect!")

# Director runs project and reports:
# "I see the _on_added message but no 'Successfully connected' message"

# Claude analyzes and proposes fix based on this information
```

This collaborative approach ensures that Claude Code can effectively debug and improve the project despite not having direct runtime access.
