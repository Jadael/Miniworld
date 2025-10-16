# Skrode Architecture: Fast Reflexes + Slow Thinking

## Inspiration: Vernor Vinge's Skroderiders

From *A Fire Upon The Deep*, the Skroderiders are intelligent plants uplifted by "skrodes" - wheeled platforms that provide:
- **Short-term memory** (prosthetic working memory)
- **Long-term storage** (persistent context and knowledge)
- **Mobility** (ability to act in the world)

Without the skrode, the "rider" (the plant intelligence) is thoughtful but has:
- No short-term memory
- Very slow to learn
- Even slower to forget
- Cannot act quickly on opportunities

**Our Adaptation**: AI agents are the "riders" (Thinkers) and need "skrodes" (fast reflexes + memory) to be effective.

---

## The Problem: Thoughtful But Slow

**Current Architecture**:
```
Player: say Hello!
[6-12 seconds pass while AI thinks...]
AI Agent: say Hello back!
```

**Issues**:
- AI agents think every 6-12 seconds
- Adding more agents = longer waits (queue depth)
- Can't respond instantly to simple situations
- Wastes LLM resources on routine actions

**Example**: If Moss wants to greet every newcomer, it needs to:
1. Observe "someone arrives" event
2. Wait 6-12 seconds for next think cycle
3. Build full context + memories
4. Send to LLM
5. Wait for LLM response
6. Parse and execute "say Welcome"

Total time: 8-15 seconds for a simple greeting!

---

## Solution: Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ RIDER (ThinkerComponent)                                    │
│ - Slow, thoughtful, uses LLM                                │
│ - Thinks every 8-12 seconds                                 │
│ - Makes complex decisions                                   │
│ - Programs the Skrode with new reflexes                     │
│ - Learns from experience                                    │
└──────────────────┬──────────────────────────────────────────┘
                   │ can program/configure
┌──────────────────▼──────────────────────────────────────────┐
│ SKRODE (SkrodeComponent)                                    │
│ - Fast reflexes, pattern matching                           │
│ - Responds instantly (<1ms)                                 │
│ - No LLM needed                                             │
│ - Executes installed "habits"                               │
│ - Simple condition → action rules                           │
└──────────────────┬──────────────────────────────────────────┘
                   │ both read/write
┌──────────────────▼──────────────────────────────────────────┐
│ MEMORY (MemoryComponent)                                    │
│ - Short-term: recent observations (64 events)              │
│ - Long-term: notes with semantic search                    │
│ - Object permanence: persistent goals and relationships    │
│ - Transcript: full history of actions and observations     │
└─────────────────────────────────────────────────────────────┘
```

---

## SkrodeComponent Design

### Core Concept: Pattern → Action

```gdscript
class_name SkrodeComponent extends ComponentBase

# Reflexes: lightweight pattern matching
var reflexes: Dictionary = {
    # pattern_name → action (String or Callable)
}

# Pattern matchers
var pattern_matchers: Dictionary = {
    "someone_arrives": func(event):
        return event.type == "movement" and event.action == "arrives",

    "someone_says_hello": func(event):
        return event.type == "speech" and "hello" in event.message.to_lower(),

    "item_dropped_here": func(event):
        return event.type == "item_dropped" and event.location == owner.get_location()
}

func _on_event_received(event: Dictionary) -> void:
    """Process event through reflexes instantly"""
    for pattern_name in reflexes:
        if _matches_pattern(pattern_name, event):
            _execute_reflex(reflexes[pattern_name], event)
            return  # Only first matching reflex fires

func _matches_pattern(pattern_name: String, event: Dictionary) -> bool:
    """Check if event matches pattern"""
    if pattern_matchers.has(pattern_name):
        var matcher = pattern_matchers[pattern_name]
        return matcher.call(event)
    return false

func _execute_reflex(action: Variant, event: Dictionary) -> void:
    """Execute a reflex action instantly"""
    var command: String = ""

    if action is String:
        # Simple string action
        command = action
    elif action is Callable:
        # Callable can use event data
        command = action.call(event)

    if command != "":
        # Execute through ActorComponent
        if owner.has_component("actor"):
            var actor = owner.get_component("actor")
            var parts = command.split(" ", true, 1)
            var cmd = parts[0]
            var args = parts[1].split(" ") if parts.size() > 1 else []
            actor.execute_command(cmd, args)
```

### Installing Reflexes

**Method 1: Programmatic (at creation)**:
```gdscript
var agent = AIAgent.create("Greeter", "A friendly greeter", location)

var skrode = SkrodeComponent.new()
skrode.add_reflex("someone_arrives", "say Welcome, traveler!")
skrode.add_reflex("someone_says_goodbye", "emote waves farewell")
agent.add_component("skrode", skrode)
```

**Method 2: In-Game Command**:
```
@add-reflex Greeter someone_arrives "say Welcome, traveler!"
@remove-reflex Greeter someone_says_goodbye
@list-reflexes Greeter
```

**Method 3: AI Self-Programming** (Phase 4):
```
# Thinker decides: "I should automatically greet newcomers"
# Executes internally:
actor.execute_command("@add-reflex", ["self", "someone_arrives", "say Hello there!"])

# Or via special NOTE syntax:
note Reflex: greet_newcomers -> someone_arrives | say Welcome!
```

---

## Benefits

### Performance
- **Instant responses** (<1ms vs 6-12 seconds)
- **Scales well** (10 agents with reflexes = still instant)
- **Reduces LLM load** (fewer requests for routine actions)
- **Parallel execution** (reflexes don't block Thinker cycles)

### Agent Intelligence
- **Habitual behaviors** (like real intelligence)
- **Learning** (Thinker can add reflexes based on experience)
- **Efficiency** (save deep thought for complex situations)
- **Consistency** (reflexes always fire the same way)

### Player Experience
- **Responsive NPCs** (feel alive, not laggy)
- **Believable characters** (mix of reflexes + thoughtfulness)
- **Predictable routines** (shopkeeper always greets customers)
- **Surprising insights** (Thinker occasionally overrides reflex)

---

## Example: Moss the Greeter

**Without Skrode** (current):
```
[Player arrives]
Moss: [waits 8 seconds for think cycle]
Moss: [builds context, sends to LLM, waits 4 seconds]
Moss: say Welcome to the garden.
[Total: 12 seconds]
```

**With Skrode** (future):
```
[Player arrives]
Moss: say Welcome to the garden. [<1ms via reflex]

[8 seconds later, Moss's Thinker kicks in]
Moss: [thinks: "That was the player's second visit. I should ask about their journey"]
Moss: say How was your journey? [thoughtful question via Thinker]
```

**Configuration**:
```gdscript
# Moss's reflexes (fast)
reflexes = {
    "someone_arrives": "say Welcome to the garden.",
    "someone_examines_me": "emote rustles softly in the breeze"
}

# Moss's profile (slow, thoughtful)
profile = """You are moss, a contemplative being.
You greet visitors automatically (your reflex handles that).
Focus on deeper observations: notice patterns, ask meaningful questions,
share insights about the slow passage of time."""
```

---

## Pattern Library

### Social Patterns
```gdscript
"someone_arrives"        # Someone enters location
"someone_leaves"         # Someone exits location
"someone_says_hello"     # Greeting detected in speech
"someone_says_goodbye"   # Farewell detected in speech
"addressed_by_name"      # Someone says your name
```

### Object Patterns
```gdscript
"item_dropped_here"      # Item dropped in location
"item_taken"             # Item picked up
"someone_examines_me"    # Someone examines this agent
"someone_examines_X"     # Someone examines specific object
```

### Environmental Patterns
```gdscript
"location_empty"         # Agent now alone
"location_crowded"       # 3+ actors present
"new_exit_created"       # Exit added to location
"time_is_X"              # Specific time (future: day/night)
```

### State Patterns
```gdscript
"low_memory"             # Few recent memories (agent confused?)
"repetitive_action"      # Agent repeating same command
"stuck_in_loop"          # Haven't moved in X cycles
"goal_achieved"          # Completed a tracked goal
```

---

## Integration with Thinker

### Thinker Can Override Reflexes

```gdscript
# In ThinkerComponent:
func _think() -> void:
    # Check if Skrode already handled situation
    if owner.has_component("skrode"):
        var skrode = owner.get_component("skrode")
        if skrode.recently_fired():
            # Skip this think cycle, reflex handled it
            print("[Thinker] Skrode handled situation, conserving LLM")
            is_thinking = false
            return

    # Normal thought process continues...
```

### Thinker Can Program Reflexes

```gdscript
# Example LLM output:
# "I should automatically greet newcomers to be more welcoming"
# Parser detects intent to install reflex
# Executes: @add-reflex self someone_arrives "say Welcome!"

# Or via NOTE command (AI can use this):
# note Reflex: auto_greet -> someone_arrives | say Hello there!
```

---

## Future: Context-Sensitive Reflexes

### Conditional Reflexes

```gdscript
reflexes = {
    "someone_arrives": {
        "condition": func(event): return Time.get_hour() < 12,
        "action": "say Good morning!",
        "else": "say Good day!"
    }
}
```

### Stateful Reflexes

```gdscript
# Moss only greets each person once per session
var greeted_today: Array = []

reflexes = {
    "someone_arrives": func(event):
        var visitor = event.actor
        if visitor in greeted_today:
            return ""  # No greeting
        else:
            greeted_today.append(visitor)
            return "say Welcome, %s!" % visitor.name
}
```

---

## Implementation Phases

### Phase 1: ✅ Complete (Property-Based Config)
- Profiles and settings now editable via properties
- Admin commands for runtime editing
- Persistence to vault

### Phase 2: ⏳ Next (Template System)
- Markdown-based prompt templates
- Variable substitution
- Shareable/reusable templates

### Phase 3: ⏳ Future (Skrode Component)
- Implement SkrodeComponent
- Pattern matching system
- Reflex installation commands
- Integration with Thinker

### Phase 4: ⏳ Advanced (Self-Programming)
- Thinker can install reflexes via LLM
- Reflex debugging and inspection
- Reflex library sharing
- Performance monitoring

---

## Code Structure

```
Core/
  components/
    thinker.gd          # Slow, thoughtful (8-12 sec cycles)
    skrode.gd           # Fast reflexes (<1ms)
    memory.gd           # Persistent storage
    actor.gd            # Command execution

Patterns/
  social_patterns.gd    # "someone_arrives", etc.
  object_patterns.gd    # "item_dropped", etc.
  state_patterns.gd     # "low_memory", "stuck_in_loop"

Commands/
  @add-reflex           # Install new reflex
  @remove-reflex        # Remove reflex
  @list-reflexes        # Show all reflexes
  @test-reflex          # Manually trigger reflex
```

---

## Questions to Explore

1. **How should reflexes interact with Memory?**
   - Should reflexes record to memory?
   - Should they check memory before firing?

2. **How to prevent reflex loops?**
   - Agent A's reflex triggers → Agent B's reflex triggers → repeat
   - Cooldown timers? Execution limits?

3. **How to make reflexes debuggable?**
   - Log all reflex firings?
   - Show "why didn't my reflex fire?" diagnostics?

4. **Should reflexes be serialized?**
   - Save to vault like other properties?
   - Or rebuilt each session from agent's NOTE?

5. **How complex should pattern matching be?**
   - Simple string matching?
   - Regex support?
   - Fuzzy matching?
   - LLM-assisted matching for ambiguous cases?

---

## Summary

The Skrode architecture provides:
- **Fast reflexes** for routine situations (instant)
- **Slow thinking** for complex decisions (8-12 seconds)
- **Persistent memory** for context and learning
- **Self-programming** capability for agents to adapt

This mirrors how biological intelligence works:
- Reflexes (pull hand from fire)
- Habits (morning coffee routine)
- Thoughtful decisions (career planning)
- Memory (learning from experience)

The result: AI agents that feel **alive, responsive, and intelligent** rather than slow and laggy.

