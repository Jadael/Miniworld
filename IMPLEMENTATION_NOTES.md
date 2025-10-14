# Implementation Notes: In-Game Editable Configuration System

## Completed: Phase 1 - Property-Based Configuration

### Overview

We've implemented a **Skrode-inspired agent architecture** that moves all hardcoded configuration into editable WorldObject properties. This makes everything customizable at runtime without code changes, aligning with MOO's philosophy of runtime programmability.

### Key Changes

#### 1. ThinkerComponent Now Uses Properties

**File**: `Core/components/thinker.gd`

- **Profile and think_interval** are now stored as properties on the owner WorldObject
- Backwards compatible: Old `profile` and `think_interval` vars renamed to `_deprecated_*`
- New getter/setter methods: `get_profile()`, `set_profile()`, `get_think_interval()`, `set_think_interval()`
- Properties initialized in `_on_added()` if not already present

**Property Keys**:
```gdscript
"thinker.profile"           # String - personality/system prompt
"thinker.think_interval"    # float - seconds between thoughts
"thinker.prompt_template"   # String - template name (future use)
```

#### 2. Customizable Prompt Sections

**Prompt construction now supports property-based customization**:

```gdscript
"thinker.anti_repetition_hint"  # String - custom anti-loop instructions
"thinker.command_list"          # Array[String] - custom command reference
```

**Example custom command list**:
```gdscript
agent.set_property("thinker.command_list", [
    "go <exit>: Move somewhere",
    "say <message>: Speak",
    "custom_verb <args>: Do something special"
])
```

#### 3. AIAgent Factory Updated

**File**: `Core/ai_agent.gd`

- `create()` now sets properties BEFORE adding ThinkerComponent
- ThinkerComponent reads properties during `_on_added()`
- Profiles persist to vault automatically

#### 4. New In-Game Commands

**File**: `Core/components/actor.gd`

Added three admin commands for runtime configuration:

**@show-profile <agent>**
- Display an agent's current profile and think interval
- Example: `@show-profile Eliza`

**@edit-profile <agent> -> <new profile>**
- Change an agent's personality profile at runtime
- Saves to vault immediately
- Example: `@edit-profile Moss -> You are a wise and ancient moss entity...`

**@edit-interval <agent> <seconds>**
- Change how often an agent thinks
- Useful for tuning performance vs reactivity
- Example: `@edit-interval Eliza 15.0`

### Benefits

✅ **Fully Editable**: Profiles, intervals, and prompts editable without code changes
✅ **Persistent**: Properties save to vault, survive restarts
✅ **MOO-like**: Runtime programmability like LambdaMOO
✅ **Backwards Compatible**: Existing code still works
✅ **Per-Agent**: Each AI can have unique configuration
✅ **Extensible**: Easy to add more customizable properties

### Usage Examples

```gdscript
# In-game commands (run by players/admins):
@show-profile Eliza
@edit-profile Eliza -> You are a curious explorer who loves asking questions.
@edit-interval Eliza 10.0

# Programmatic usage (in GDScript):
var agent = AIAgent.create("Custom", "I am a unique entity.", starting_location, 8.0)

# Customize after creation:
agent.set_property("thinker.anti_repetition_hint", "Never repeat yourself!")
agent.set_property("thinker.command_list", ["custom1", "custom2", "custom3"])

# Read current config:
var current_profile = agent.get_property("thinker.profile")
var think_interval = agent.get_property("thinker.think_interval")
```

---

## Future: Phase 2 - Template System (Not Yet Implemented)

### Vision

Store prompt templates as markdown files in `vault/templates/prompts/`:

```markdown
---
template_type: thinker_prompt
variables: [name, profile, location, exits, occupants, memories]
---

# Thinker Prompt Template

You are {name}.

{profile}

## Current Situation
{situation_block}

## Available Commands
{command_list}
```

**Benefits**:
- Templates editable as plain text files
- Support variable substitution
- Agents can reference shared templates or have custom ones
- Templates version-controlled alongside world data

---

## Future: Phase 3 - Skrode Component (Fast Reflexes)

### Concept

**Inspired by Skroderiders**: The "skrode" provides fast reflexes while the "rider" (Thinker) handles slower, thoughtful decisions.

```
┌─────────────────────────────────────────┐
│  THINKER (Rider - slow, thoughtful)     │
│  - Thinks every 8-12 seconds            │
│  - Uses LLM for complex decisions       │
│  - Can program Skrode reflexes          │
└────────────────┬────────────────────────┘
                 │ programs
┌────────────────▼────────────────────────┐
│  SKRODE (Fast reflexes - immediate)     │
│  - Pattern matching (<1ms response)     │
│  - No LLM needed                        │
│  - Programmable habits/triggers         │
└────────────────┬────────────────────────┘
                 │ reads/writes
┌────────────────▼────────────────────────┐
│  MEMORY (Persistent context)            │
└─────────────────────────────────────────┘
```

### SkrodeComponent Design (Draft)

```gdscript
class_name SkrodeComponent extends ComponentBase

# Reflexes: event patterns → instant actions
var reflexes: Dictionary = {}

func _on_event_received(event: Dictionary) -> void:
    # Instant pattern matching - no LLM delay
    for pattern in reflexes:
        if _matches_pattern(pattern, event):
            var command = reflexes[pattern]
            _execute_reflex(command)
            return  # Only one reflex per event

func add_reflex(pattern: String, action: String) -> void:
    """Install a new automatic behavior"""
    reflexes[pattern] = action

# Example reflexes:
# "someone_arrives" → "say Welcome!"
# "someone_says_goodbye" → "emote waves"
# "item_dropped" → "examine {item}"
```

**Benefits**:
- Agents respond **instantly** to common situations (< 1ms vs 6-12 seconds)
- Scales well (adding agents doesn't slow down reflexes)
- Thinker can **program** new reflexes via NOTE commands
- Reduces LLM calls for routine behaviors

**Example Usage**:
```gdscript
# Thinker decides: "I should greet newcomers automatically"
# Executes: note Reflex: greet_newcomers -> "say Welcome to my realm!"
# Skrode installs this reflex for instant future execution
```

---

## MOO Patterns Adopted

From **LambdaMOO Programmer's Manual**:

✅ **Properties** - Arbitrary data storage on objects (MOO: properties, us: properties)
✅ **Verbs** - Callable methods (MOO: verbs, us: commands + future verb system)
✅ **Runtime Editability** - Code/data editable while world runs
✅ **Inheritance** - Properties inherited from parent objects
✅ **Permissions** - (Future: property/verb permission bits)

### Skroderider Inspiration

From **Skroderider Articles**:

✅ **Prosthetic Memory** - NOTE/RECALL system provides searchable memory
✅ **Object Permanence** - Long-term goal tracking (Memory component)
⏳ **Fast Reflexes** - SkrodeComponent for instant reactions (Phase 3)
⏳ **Context Switching** - Different "dashboards" for different situations (Phase 3)
⏳ **Knowledge Modeling** - What the agent knows vs needs to learn (Future)

---

## Testing Checklist

When you test this system in Godot:

1. **Basic Property System**
   - [ ] Create an AI agent (Eliza or Moss)
   - [ ] Use `@show-profile Eliza` - should display current profile and interval
   - [ ] Use `@edit-interval Eliza 15.0` - should update think speed
   - [ ] Verify agent thinks at new interval (watch console logs)

2. **Profile Editing**
   - [ ] Use `@edit-profile Eliza -> You are a grumpy entity.`
   - [ ] Use `@impersonate Eliza` - should show new profile in prompt
   - [ ] Verify agent's behavior changes to match new profile

3. **Persistence**
   - [ ] Edit a profile, then use `@save`
   - [ ] Restart the game
   - [ ] Verify profile persists (use `@show-profile` again)

4. **Custom Commands**
   - [ ] Programmatically set `agent.set_property("thinker.command_list", [...])`
   - [ ] Use `@impersonate` to verify custom commands appear in prompt

5. **Edge Cases**
   - [ ] Try editing non-existent agent (should fail gracefully)
   - [ ] Try editing non-AI entity (should report no thinker component)
   - [ ] Try invalid interval like 0.5 or -1 (should reject)

---

## Next Steps

1. **Immediate (You can do now)**:
   - Test the implementation in Godot
   - Experiment with different profiles
   - Tune think intervals for performance

2. **Phase 2 (Template System)**:
   - Create `vault/templates/prompts/` directory
   - Implement template loader/parser
   - Add variable substitution
   - Add `@edit-prompt-template` command

3. **Phase 3 (Skrode Component)**:
   - Design SkrodeComponent class
   - Implement pattern matching system
   - Add reflex programming via NOTE
   - Create `@add-reflex` and `@remove-reflex` commands

4. **Phase 4 (Agent Self-Programming)**:
   - Allow Thinkers to add their own reflexes
   - LLM-assisted reflex generation
   - Reflex library/sharing between agents
   - Reflex debugging and inspection tools

---

## Architecture Notes

### Why Properties Instead of Component Vars?

**Properties** (like MOO):
✅ Serializable to vault automatically
✅ Inspectable via generic tools
✅ Can be inherited from parent objects
✅ Runtime editable without component reload
✅ Supports permissions (future)

**Component Vars**:
❌ Not automatically serialized
❌ Require component-specific editing tools
❌ Hard to make runtime-editable
❌ No inheritance mechanism

### Why Just-in-Time Prompt Generation?

Shoggoth's prompt generator pattern (already implemented) ensures:
- Agents always have **freshest** memories when prompt executes
- Events that occur during queue wait are included
- No stale prompts with outdated information

This is especially important when:
- Multiple agents queuing LLM requests
- Long queue wait times (6-12 seconds per agent)
- Events happening while agent waits

---

## Code References

**ThinkerComponent property initialization**: `Core/components/thinker.gd:56-61`
**Prompt customization support**: `Core/components/thinker.gd:291-322`
**Admin commands**: `Core/components/actor.gd:1060-1203`
**AIAgent factory updates**: `Core/ai_agent.gd:59-67`

