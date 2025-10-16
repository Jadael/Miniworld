# Agent Memory System Improvements: Reducing Repetitive Behavior

## Problem Statement

AI agents in Miniworld, especially when using small or quantized LLMs (3B-7B parameters), exhibit obsessive-compulsive repetitive behavior. They get stuck in conversation loops, meta-discussing indefinitely without taking concrete action.

### Observed Symptoms

**Example from in-game log**:
```
Blueshell: "could you clarify *precisely* what constitutes success?"
Greenstalk: "you raise a crucial point about defining success..."
Blueshell: "we need *measurable* criteria, not vague scoring rubrics"
Greenstalk: "you are absolutely right to push for measurable criteria..."
Blueshell: [continues asking for more precision]
```

**Pattern**: Agents spend 10+ turns discussing HOW to approach a task without ever DOING the task.

### Root Causes

1. **Prompt Homogeneity** - Each LLM prompt looks nearly identical:
   - Same location, same occupants, same 64 memories
   - No temporal markers ("2 minutes ago" vs "10 seconds ago")
   - No indication of repetition

2. **Lack of Loop Detection** - Agents can't recognize they're stuck:
   - No mechanism to detect "I've asked this 5 times"
   - No self-monitoring of behavioral patterns
   - No cost/benefit analysis of continuing same thread

3. **Missing Salience** - All memories weighted equally:
   - Player instruction from 2 minutes ago = agent's latest question
   - Recent repetitions not flagged as problematic
   - No prioritization of novel vs. redundant information

4. **No Goal Tracking** - Agents lack progress awareness:
   - Can't tell if making progress toward goal
   - No measurable milestones or completion criteria
   - No sense of urgency or deadline pressure

5. **Small Model Limitations** - 3B-7B param models have:
   - Weaker instruction following
   - Limited working memory capacity
   - Less diverse response generation
   - Poor meta-reasoning about own behavior

## Proposed Solution: Multi-Tier Memory with Salience

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ WORKING MEMORY (Active Context - fits in LLM prompt)        │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Current Goal (1-2 lines)                                │ │
│ │ - "Build 5 rooms (2/5 complete)"                        │ │
│ │ - Progress indicators, deadline                         │ │
│ └─────────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Immediate Observations (last 3-5 events)                │ │
│ │ - "[NOW] You pause, deep in thought..."                 │ │
│ │ - "[15s ago] Greenstalk says 'Great question!'"         │ │
│ │ - "[30s ago] You say 'What criteria...'"                │ │
│ │ - "[2m ago] Traveler says 'Build 5 rooms'"             │ │
│ └─────────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Loop Detection Warning (if triggered)                   │ │
│ │ - "WARNING: You've asked about success criteria 4x"     │ │
│ │ - "Last 5 actions all 'say' - try something else"       │ │
│ └─────────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Salient Memories (top 8-12 by relevance score)         │ │
│ │ - Weighted by: recency + novelty + relevance + source  │ │
│ │ - Player instructions prioritized                       │ │
│ │ - Novel observations over repetitive discussion        │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                         ▲
                         │ fetch/update
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ SHORT-TERM MEMORY (last ~50 events, chronological)         │
│ - All observations, actions, results                        │
│ - Timestamped for recency calculation                      │
│ - Used for loop detection and pattern analysis             │
└─────────────────────────────────────────────────────────────┘
                         ▲
                         │ archive/recall
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ LONG-TERM MEMORY (Notes with semantic search)              │
│ - Structured knowledge (NOTE command)                       │
│ - Indexed by embeddings (RECALL command)                   │
│ - Persistent across sessions (vault storage)               │
└─────────────────────────────────────────────────────────────┘
```

### Inspiration Sources

This architecture draws from:

1. **A-MEM (2025)** - Agentic memory with dynamic organization following Zettelkasten principles
2. **MemGPT (2024)** - OS-style memory with main/external distinction and explicit memory operations
3. **Gwern's Nenex** - Edit-centric history, dynamic evaluation, action log as training data
4. **Vinge's Skrodes** - Fast reflexes + slow thinking + persistent memory wheels
5. **Miniworld Python Prototype** - "Next steps" and "conditions" reasoning structure

## Design Details

### 1. Memory Salience Scoring

Each memory gets a salience score (0.0-1.0) based on multiple factors:

```gdscript
func calculate_salience(memory: Dictionary) -> float:
    var score: float = 0.0

    # RECENCY (40% weight) - exponential decay, half-life 45 seconds
    var age_seconds = Time.get_ticks_msec() / 1000.0 - memory.timestamp
    score += exp(-age_seconds / 45.0) * 0.40

    # NOVELTY (20% weight) - dissimilar to recent memories
    # Uses Jaccard similarity on word sets
    score += calculate_novelty(memory, recent_memories) * 0.20

    # RELEVANCE (20% weight) - keyword overlap with current goal
    if current_goal != "":
        score += calculate_relevance(memory, current_goal) * 0.20

    # AUTHORITY (10% weight) - player > self > other agents
    # Player messages get 1.0, self gets 0.6, others get 0.4
    score += calculate_authority(memory) * 0.10

    # ACTIONABILITY (10% weight) - concrete actions > meta-discussion
    # "go", "examine", "note" get 1.0
    # "should we", "what if" get 0.2
    score += calculate_actionability(memory) * 0.10

    return clamp(score, 0.0, 1.0)
```

**Rationale**:
- Recent events matter most (exponential decay mirrors human memory)
- Novel information more valuable than repetition
- Goal-relevant memories guide decision-making
- Player instructions are authoritative
- Concrete actions preferred over endless discussion

### 2. Loop Detection

Two types of loops to detect:

#### Action Loop
```gdscript
func detect_action_loop() -> String:
    var last_actions = get_last_action_types(10)
    var unique_actions = {}

    for action in last_actions:
        unique_actions[action] = unique_actions.get(action, 0) + 1

    # If 5+ of last 10 are same action
    for action in unique_actions:
        if unique_actions[action] >= 5:
            return "WARNING: Your last 10 actions included 5+ '%s' commands. Try a different action type." % action

    return ""
```

#### Conversation Loop
```gdscript
func detect_conversation_loop() -> String:
    var recent_speech = get_recent_speech_memories(8)
    var topics = {}

    for speech in recent_speech:
        var topic = extract_topic_keywords(speech)
        for keyword in topic:
            topics[keyword] = topics.get(keyword, 0) + 1

    # If same topic appears 4+ times
    for topic in topics:
        if topics[topic] >= 4:
            return "WARNING: You've discussed '%s' 4+ times without action. Consider: note, go, examine, or recall." % topic

    return ""
```

**Benefit**: Explicit loop warnings injected into prompt when detected.

### 3. Temporal Context Formatting

Memories displayed with age labels:

```
[NOW] You pause, deep in thought...
[15s ago] Greenstalk says, "Great question about criteria!"
[30s ago] You say, "What criteria should we use?"
[1m ago] You say, "How should we define success?"
[2m ago] Traveler says, "Build 5 rooms and discuss afterward."
```

**Implementation**:
```gdscript
static func format_memory_with_age(memory: Dictionary) -> String:
    var age_sec = (Time.get_ticks_msec() - memory.timestamp) / 1000.0
    var label: String = ""

    if age_sec < 10: label = "[NOW]"
    elif age_sec < 60: label = "[%ds ago]" % int(age_sec)
    else: label = "[%dm ago]" % int(age_sec / 60.0)

    return "%s %s" % [label, memory.content]
```

**Benefit**: Agent sees temporal progression, realizes "I asked this recently".

### 4. Goal Tracking System

Goals stored as WorldObject properties:

```gdscript
# Properties
owner.set_property("thinker.current_goal", "Build 5 rooms")
owner.set_property("thinker.goal_progress", 2)  # 2 done
owner.set_property("thinker.goal_max", 5)       # 5 total
owner.set_property("thinker.goal_deadline", Time.get_ticks_msec() + 300000)  # 5min
```

**Goal Extraction** (automatic from player speech):
```gdscript
func extract_goal_from_text(text: String) -> Dictionary:
    # Pattern: "build N X", "create N X", "make N X"
    var regex = RegEx.new()
    regex.compile("(build|create|make)\\s+(\\d+)\\s+(\\w+)")
    var result = regex.search(text.to_lower())

    if result:
        return {
            "goal": "%s %s %s" % [result.get_string(1), result.get_string(2), result.get_string(3)],
            "max": int(result.get_string(2)),
            "type": result.get_string(3)
        }

    return {}
```

**Progress Display** (in prompt):
```
## Your Current Goal

Build 5 rooms (2/5 complete)
Deadline: 3m 42s remaining

IMPORTANT: You've made progress - 2 rooms exist. Focus on building the remaining 3.
```

**Benefit**: Agent knows where they stand, has measurable progress, feels deadline pressure.

### 5. Forced Action Diversity

Hard constraint against excessive repetition:

```gdscript
# In ThinkerComponent
var meta_discussion_depth: int = 0  # Consecutive "say" commands

func _on_thought_complete(response: String) -> void:
    if response.begins_with("say ") or response.begins_with("emote "):
        meta_discussion_depth += 1
    else:
        meta_discussion_depth = 0  # Reset on action

    # Force different action after 3 consecutive discussions
    if meta_discussion_depth >= 3:
        owner.set_property("thinker.force_action_next_turn", true)
```

**Prompt Injection**:
```gdscript
if owner.get_property("thinker.force_action_next_turn", false):
    prompt += "\n**MANDATORY: You've had 3 turns of discussion. This turn you MUST take a concrete action:**\n"
    prompt += "- go <exit> (move somewhere)\n"
    prompt += "- examine <thing> (inspect details)\n"
    prompt += "- note <topic> -> <content> (record thoughts and move on)\n"
    prompt += "- recall <query> (search your notes)\n"
    prompt += "**You may NOT use 'say' or 'emote' this turn.**\n\n"

    owner.set_property("thinker.force_action_next_turn", false)
```

**Benefit**: Structurally impossible to have 10 consecutive "say" commands.

### 6. Enhanced Prompt Engineering

#### Structured Reasoning (from Python prototype)
```
## Response Format

Think step-by-step:

1. SITUATION: What just happened? What's the current state?
2. NEXT STEP: What single concrete action moves toward the goal?
3. CONDITION: What would tell me this step succeeded?
4. COMMAND: [your command here]

Example:
1. SITUATION: User asked me to build 5 rooms. I've discussed criteria but built 0 rooms.
2. NEXT STEP: Actually create the first room using @dig.
3. CONDITION: A new room exists that I can 'go' to.
4. COMMAND: @dig room1 north "A spacious chamber"
```

#### Loop-Breaking Suggestions
When loop detected:
```
**You are stuck in a loop. Here are concrete ways to break it:**

- note Success_Criteria -> [your thoughts on criteria], then START BUILDING
- go <exit> (explore a different area to find inspiration)
- examine <object/person> (ground discussion in concrete details)
- recall building (check if you have notes on this already)

Remember: DONE IS BETTER THAN PERFECT. Take imperfect action now.
```

#### Temporal Urgency
When deadline approaching:
```
**URGENT: Goal deadline in 42 seconds.**

Focus on EXECUTION not PLANNING. Every turn counts.
You have time for ~3-4 more actions before deadline.
```

## Implementation Plan

### Phase 1: Quick Wins (2-3 hours, ~50-70% reduction in loops)

Immediate impact with minimal code changes:

**Files to modify**:
- `Core/components/memory.gd`
- `Core/components/thinker.gd`

**Changes**:
1. Add `detect_action_loop()` and `detect_conversation_loop()` to MemoryComponent
2. Add `format_memory_with_age()` for temporal display
3. Add `meta_discussion_depth` tracking to ThinkerComponent
4. Inject loop warnings into prompts dynamically
5. Add forced action diversity after 3 consecutive discussions

**Testing**:
- Run same scenario that produced log (Blueshell/Greenstalk building rooms)
- Verify agents take concrete action after 2-3 discussion turns
- Confirm temporal labels appear in memories

### Phase 2: Salience & Goals (4-6 hours, robust improvement)

Add intelligent memory prioritization and goal tracking:

**New files**:
- `Core/components/memory_salience.gd` - Salience calculator (static class)
- `Core/utils/goal_extractor.gd` - Pattern matching for goal extraction

**Modified files**:
- `Core/components/memory.gd` - Add `get_salient_memories()`
- `Core/components/thinker.gd` - Use salient memories, display goals
- `Core/world_object.gd` - Already supports properties, just use them

**Changes**:
1. Implement multi-factor salience scoring
2. Replace `get_recent_memories()` with `get_salient_memories()` in prompts
3. Extract goals from player speech automatically
4. Display goal + progress + deadline in prompts
5. Update progress when agent completes measurable actions (@dig, @describe, etc.)

**Testing**:
- Verify salient memories prioritize player instructions
- Confirm goals extracted correctly from "build 5 rooms" type instructions
- Check progress updates when agent uses @dig
- Test deadline pressure prompts

### Phase 3: Skrode Reflexes (6-8 hours, production-ready)

Fast reflexes for common patterns, no LLM needed:

**New files**:
- `Core/components/skrode.gd` - Reflex execution component
- `Core/components/reflex_patterns.gd` - Pattern library

**Modified files**:
- `Core/components/actor.gd` - Add @add-reflex, @remove-reflex commands
- `Core/components/thinker.gd` - Skip think cycle if reflex handled situation
- `Daemons/ai_agent.gd` - Install default reflexes at creation

**Changes**:
1. Implement SkrodeComponent with pattern matching
2. Create library of common patterns (user_gives_instruction, someone_arrives, etc.)
3. Add reflex management commands
4. Integrate with ThinkerComponent (skip LLM if reflex handled it)
5. Install sensible defaults (e.g., note-taking reflex for instructions)

**Testing**:
- Player says "build 5 rooms" → agent immediately creates note (reflex)
- Then agent builds room (thoughtful LLM decision)
- Verify sub-second response times for reflexive actions
- Test reflex installation/removal commands

### Phase 4: Advanced Memory (8-12 hours, research-grade)

Hierarchical memory with meta-cognition:

**New files**:
- `Core/components/meta_monitor.gd` - Behavioral self-monitoring
- `Core/components/memory_hierarchy.gd` - Working/short/long-term separation

**Modified files**:
- `Core/components/memory.gd` - Add archival system
- `Core/components/actor.gd` - Add @recall-memory, @memory-stats commands

**Changes**:
1. Implement explicit memory hierarchies (working/short/long-term)
2. Auto-archive old, low-salience memories
3. Add meta-monitoring component (detects stuck_in_loop, goal_stalled signals)
4. Add memory operation commands for explicit control
5. Implement Zettelkasten-style note linking (A-MEM inspired)

**Testing**:
- Verify memory archival after 10 minutes
- Test meta-monitor signals trigger appropriate responses
- Check note linking and graph traversal
- Confirm long-term continuity across sessions

### Phase 5: Tuning & Optimization (Ongoing)

Fine-tune for different model sizes:

**For small models (3B-7B)**:
- Shorter prompts (reduce token count)
- More directive language ("MUST", "REQUIRED")
- Stronger loop warnings
- Lower meta_discussion_depth threshold (2 instead of 3)

**For large models (30B+)**:
- Richer context (more salient memories)
- Softer guidance
- Trust self-monitoring more
- Higher diversity thresholds

**Metrics to track**:
- Average turns before concrete action (target: 1-2)
- Loop frequency (target: < 5% of conversations)
- Goal completion rate (target: > 80%)
- Response diversity (Shannon entropy of action types)

## Expected Results

### Before (Current State)
```
[User] Build 5 rooms
[Agent 1] What criteria should we use for success?
[Agent 2] Good question! Let's define metrics.
[Agent 1] Yes, we need measurable benchmarks.
[Agent 2] How about a scoring rubric?
[Agent 1] But what constitutes a "point" exactly?
[Agent 2] Perhaps three levels: meets, partial, none.
[Agent 1] But we still need specific definitions...
[10+ more turns of meta-discussion]
[Result] 0 rooms built
```

### After Phase 1
```
[User] Build 5 rooms
[Agent 1] What criteria should we use?
[Agent 2] Good question! Let's define metrics.
[WARNING: Loop detected - "criteria" discussed 3x]
[Agent 1] note Criteria_Discussion -> Need measurable success metrics
[Agent 1] @dig room1 north "The Northern Chamber"
[Result] 1 room built, discussion terminated
```

### After Phase 2
```
[User] Build 5 rooms
[Goal Extracted: "Build 5 rooms", max=5, type="rooms"]
[Agent 1] note Task -> Build 5 rooms per Traveler request
[Agent 1] @dig room1 north "The Northern Chamber"
[Progress: 1/5 rooms complete]
[Agent 2] @dig room2 south "The Southern Gallery"
[Progress: 2/5 rooms complete]
[3 minutes later]
[Progress: 5/5 rooms complete]
[Result] Goal achieved efficiently
```

### After Phase 3 (with Reflexes)
```
[User] Build 5 rooms
[Reflex triggered: user_gives_instruction]
[Agent 1] note Task -> Build 5 rooms (0.05 seconds, no LLM)
[Agent 1 thinks...] @dig room1 north "The Northern Chamber"
[Agent 2 thinks...] @dig room2 south "The Southern Gallery"
[Result] Instant note-taking + thoughtful building
```

## Benefits Summary

### For Small/Quantized Models
- **Reduced prompt confusion** via temporal markers
- **Explicit loop warnings** compensate for weak meta-reasoning
- **Hard constraints** prevent runaway discussions
- **Salience focus** keeps limited context relevant
- **Reflexes** handle routine cases without LLM

### For Agent Behavior
- **Goal-directed** instead of aimless
- **Progress-aware** via measurable milestones
- **Self-monitoring** via loop detection
- **Temporally-grounded** via age labels
- **Responsive** via reflexes (< 1ms for patterns)

### For Player Experience
- **Less frustration** - agents actually DO things
- **Visible progress** - goals, completion tracking
- **Natural pacing** - mix of quick reflexes + thoughtful decisions
- **Believable characters** - not stuck in infinite meta-loops

### For System Architecture
- **Aligned with skrode design** - fast + slow thinking
- **Inspired by SOTA research** - A-MEM, MemGPT, Nenex
- **MOO-compatible** - works with existing command system
- **Incrementally deployable** - each phase adds value independently

## Future Enhancements

### Beyond Phase 4
- **Dynamic salience weight learning** - agents tune their own salience formula
- **Collaborative goal tracking** - multi-agent shared goals
- **Emotional state modeling** - affect influences salience/behavior
- **Episodic memory** - distinct "scenes" with boundaries
- **Social relationship tracking** - remember past interactions per-agent
- **Plan persistence** - multi-turn action sequences
- **Dream/consolidation** - offline memory processing (existing DREAM command)

### Research Directions
- **Self-improving reflexes** - LLM proposes new reflexes based on experience
- **Memory compression** - summarize old memories instead of archiving
- **Cross-agent memory sharing** - collective knowledge base
- **Meta-learning** - adapt behavior based on success/failure rates
- **Temporal prediction** - anticipate common sequences

## Related Documentation

- **SKRODE_ARCHITECTURE.md** - Fast reflexes + slow thinking design
- **AGENTS.md** - Current AI agent implementation
- **PYTHON_PROTOTYPE_REVIEW.md** - Lessons from prototype
- **MINIWORLD_ARCHITECTURE.md** - Overall system architecture

## Conclusion

The repetitive behavior problem stems from **context collapse**: prompts are too homogeneous, agents lack temporal grounding, and there's no mechanism for self-monitoring or goal tracking.

The solution combines **systemic improvements** (salience, loop detection, goals, reflexes) with **prompt engineering** (temporal markers, structured reasoning, loop warnings).

**Phase 1 alone** (2-3 hours) should reduce loops by 50-70%.
**Phases 1+2** (6-9 hours) provide robust, goal-directed behavior.
**All phases** (20-30 hours) create a research-grade agent memory system.

The architecture is inspired by cutting-edge research (A-MEM, MemGPT, Nenex) while staying true to Miniworld's skrode metaphor and MOO-style design philosophy.

---

**Next Steps**: Discuss priorities with director. If immediate relief needed, start Phase 1. If building for production, commit to Phases 1-3. If exploring research, plan full implementation.
