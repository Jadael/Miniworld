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

After completing documentation work:

1. Test the project to ensure nothing broke
2. Review all changed files to ensure consistency
3. Create a commit with descriptive message: "docs: Comprehensive documentation pass for [component name]"
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
