# Agent Memory System Improvements V2: In-Game Configuration

## Design Principles

**Core Philosophy**: Everything that affects agent behavior should be:
1. **Configurable in-game** via commands (not hardcoded)
2. **Accessible to agents** for self-modification
3. **Understandable by humans** (including children)
4. **Stored as data** (properties, templates, notes) not code

**Litmus Test**: If a human child can't understand and adjust it, redesign it.

## Problem Statement

AI agents exhibit repetitive "obsessive" behavior - getting stuck in discussion loops without taking concrete action. This is especially pronounced with small/quantized models (3B-7B parameters).

**Example**:
```
User: Build 5 rooms
Agent 1: What criteria should we use?
Agent 2: Good question! Let's define metrics.
Agent 1: We need measurable benchmarks.
Agent 2: How about a scoring rubric?
[10+ more turns, 0 rooms built]
```

**Root Cause**: Agents lack tools to:
- Recognize they're looping
- Adjust their own thinking patterns
- Track progress toward goals
- Prioritize important information

## Solution: Self-Configurable "Skrodes"

### Metaphor: Tuning Your Mind

Just like you can adjust your glasses or tune a radio, agents (and players) can adjust their thinking apparatus. These settings are stored as **WorldObject properties** - part of the world, not the code.

### Three Layers of Configuration

```
┌─────────────────────────────────────────────────────────────┐
│ 1. MEMORY CONFIGURATION                                     │
│    "What do I pay attention to?"                            │
│    - Style: recent, balanced, goal_focused, exploratory     │
│    - Window size: how many memories to consider             │
│    - Temporal labels: show ages or not                      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 2. THINKING STYLE                                           │
│    "How do I make decisions?"                               │
│    - Action bias: doer (0.9) vs philosopher (0.3)          │
│    - Novelty seeking: routine (0.2) vs explorer (0.8)      │
│    - Loop tolerance: low/medium/high                        │
│    - Reflection frequency: low/medium/high                  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 3. PROMPT TEMPLATE                                          │
│    "How is my thinking structured?"                         │
│    - Markdown file in vault/prompt_templates/              │
│    - Variable substitution: {agent_name}, {goal}, etc.     │
│    - Conditional sections: {#if loop_detected}...{/if}     │
└─────────────────────────────────────────────────────────────┘
```

All three layers are **agent-modifiable** and **human-readable**.

## In-Game Commands (For Agents and Players)

### 1. Memory Configuration

#### View memory settings
```
@my-memory

> Your memory settings:
> Style: balanced
> Window: 12 memories
> Temporal labels: on (you see "[2m ago]" timestamps)
>
> Currently showing 12 of 48 stored memories.
> Favoring: 50% recent, 50% novel
```

#### Change memory style
```
@set-memory style -> goal_focused

> Memory style changed to "goal_focused"
> Description: Prioritize memories related to your current goal
> You'll now see 10 memories, weighted 70% goal-relevance, 30% recency.
```

#### Available memory styles
```
@list-memory-styles

> Available memory styles:
>
> recent: Focus on what just happened (8 memories, 80% recency)
>   Good for: Fast-paced situations, quick reactions
>
> balanced: Mix of recent and important (12 memories, 50/50)
>   Good for: General use, most agents
>
> goal_focused: Related to your current goal (10 memories, 70% goal)
>   Good for: Task completion, staying on track
>
> exploratory: Unusual and surprising things (15 memories, 70% novelty)
>   Good for: Exploration, discovery, learning
>
> social: What people say and do (12 memories, 60% people)
>   Good for: Social agents, greeters, guides
```

#### Adjust window size
```
@set-memory window -> 8

> Memory window reduced to 8.
> You'll see fewer memories but think faster (shorter prompts).
```

#### Inspect why a memory was chosen
```
@why-remember 5

> Memory #5: "[2m ago] Traveler says 'Build 5 rooms'"
>
> Included because:
> - Recent (2 minutes old)
> - From player (high authority)
> - Contains goal keywords: "build", "rooms"
> - Current style (goal_focused) prioritizes goal-related memories
```

### 2. Thinking Style Configuration

#### View thinking style
```
@my-style

> Your thinking style: philosopher
>
> Action bias: 0.3 (low - you prefer discussion over action)
> Novelty seeking: 0.5 (balanced)
> Loop tolerance: high (you enjoy thorough exploration)
> Reflection frequency: high (you think deeply)
>
> Strengths: Deep insights, thorough analysis
> Weaknesses: Can get stuck discussing, slow to act
```

#### Change thinking style (preset)
```
@set-thinking-style -> builder

> Thinking style changed to "builder"
>
> Action bias: 0.9 (high - you strongly prefer actions)
> Novelty seeking: 0.4 (slightly routine)
> Loop tolerance: low (you move on quickly)
> Reflection frequency: low (you act first, reflect later)
>
> You'll now focus on DOING over DISCUSSING.
```

#### Available thinking styles
```
@list-thinking-styles

> Available thinking styles:
>
> philosopher: Thoughtful, asks questions, reflects deeply
>   Action bias: low | Loop tolerance: high | Good for: Deep conversations
>
> builder: Action-oriented, gets things done, minimal discussion
>   Action bias: high | Loop tolerance: low | Good for: Task completion
>
> explorer: Curious, seeks novelty, tries new things
>   Action bias: medium | Novelty seeking: high | Good for: Discovery
>
> guide: Helpful, responsive, waits for others to lead
>   Action bias: medium | Loop tolerance: low | Good for: Assisting players
>
> balanced: All-around (default)
>   Action bias: medium | All balanced | Good for: General use
```

#### Fine-tune individual properties
```
@set-style action_bias -> 0.7

> Action bias set to 0.7 (high)
> You'll now prefer doing over discussing.

@set-style loop_tolerance -> low

> Loop tolerance set to low.
> You'll recognize repetition quickly and change tactics.
```

#### Children's version (same commands, friendly output)
```
@my-style

> You're a "balanced" thinker!
> You like to DO things AND talk about them.

@set-style -> builder

> Now you're a BUILDER! You like doing more than talking!
```

### 3. Loop Awareness (Self-Monitoring)

#### Check for loops
```
@am-i-looping?

> Analyzing recent behavior...
>
> Last 10 actions: say, say, say, emote, say, say, go, say, say, note
> Action diversity: LOW (60% were 'say')
>
> Topic repetitions:
> - "criteria" (5 mentions in last 6 speeches)
> - "success" (4 mentions in last 6 speeches)
>
> **Assessment: YES, you appear to be in a discussion loop.**
>
> Suggestions to break the loop:
> - go <exit> (change environment)
> - note Criteria_Discussion -> [summarize your thoughts] (externalize and move on)
> - examine <object> (ground discussion in concrete details)
> - @set-style action_bias -> high (adjust yourself to prefer action)
```

#### Children's version
```
@am-i-stuck?

> Hmm... you've said similar things 5 times!
>
> You're talking about "how to do it" a lot.
> Want to try DOING something instead?
>
> Try:
> - go somewhere new
> - build something
> - write a note about your ideas
```

### 4. Goal Management

#### View current goal
```
@my-goal

> Current goal: Build 5 rooms
> Progress: 2/5 complete (40%)
>
> Completed:
> - room1 (The Northern Chamber)
> - room2 (The Southern Gallery)
>
> Remaining: 3 more rooms
>
> Notes: Focus on variety in descriptions
```

#### Set a goal
```
@set-goal -> Build 5 rooms with unique themes

> Goal set: Build 5 rooms with unique themes
> Progress tracking: 0/5 complete
>
> I'll remind you of this goal and track your progress.
```

#### Update progress (usually automatic, but can be manual)
```
@goal-progress + 1

> Progress updated: 3/5 complete (60%)
> Great work! 2 more to go!
```

#### Mark goal complete
```
@goal-done

> Goal complete! 5/5 rooms built!
>
> Summary of what you accomplished:
> - Built 5 unique rooms
> - Added varied descriptions
> - Connected them logically
>
> What's your next goal?
```

#### Goal suggestions (when stuck)
```
@suggest-goal

> Based on your recent behavior, you might want to set a goal:
>
> - You've been discussing "criteria" a lot. Set a goal to build 1 room?
> - You seem interested in architecture. Set a goal to design a themed area?
> - You haven't moved in a while. Set a goal to explore 3 new locations?
```

### 5. Template Management

#### View current template
```
@my-template

> Current prompt template: balanced_thinker.md
>
> Description: General-purpose thinking with balanced memory
> Suitable for: Most situations, default behavior
>
> Sections included:
> - Identity and profile
> - Current situation
> - Recent memories (with timestamps)
> - Available commands
> - Response format
```

#### List available templates
```
@list-templates

> Available prompt templates:
>
> balanced_thinker.md (current)
>   Balanced memory, standard format
>   Good for: General use
>
> builder_focused.md
>   Emphasizes action, short on discussion
>   Good for: Task completion, building
>
> social_agent.md
>   Prioritizes conversations, social cues
>   Good for: Greeters, guides, conversationalists
>
> explorer_curious.md
>   Encourages trying new things
>   Good for: Exploration, discovery
>
> goal_driven.md
>   Keeps goal front-and-center, tracks progress
>   Good for: When you have a specific goal
```

#### Switch templates
```
@use-template builder_focused

> Template changed to: builder_focused.md
>
> Your next thought will use this template.
> This template emphasizes action and minimizes discussion.
```

#### Create custom template (advanced)
```
@create-template my_custom_style

> Created vault/prompt_templates/my_custom_style.md
>
> Edit this file to customize how you think.
> Use variables: {agent_name}, {location}, {goal}, {recent_memories}
> Use conditions: {#if loop_detected}...{/if}
>
> See vault/prompt_templates/README.md for syntax guide.
```

### 6. Reflex Management (Skrode-Style Fast Responses)

#### View reflexes
```
@my-reflexes

> You have 3 reflexes installed:
>
> 1. someone_arrives → emote waves hello
>    Triggers: When someone enters your location
>
> 2. player_gives_task → note Task -> {message}
>    Triggers: When player says something task-like
>
> 3. someone_says_goodbye → say Safe travels!
>    Triggers: When someone says goodbye
```

#### Add a reflex
```
@add-reflex someone_examines_me -> emote rustles softly

> Reflex added!
>
> Trigger: someone_examines_me
> Action: emote rustles softly
>
> From now on, when someone examines you, you'll automatically respond.
> This happens instantly (no LLM needed).
```

#### Test a reflex
```
@test-reflex someone_arrives

> Simulating event: someone_arrives (actor: TestDummy)
>
> [Your reflex triggered]
> You emote: waves hello
>
> Reflex works! This took <1ms (no LLM call).
```

#### Remove a reflex
```
@remove-reflex someone_says_goodbye

> Reflex removed: someone_says_goodbye
> You'll no longer automatically respond to goodbyes.
```

#### List available patterns (for creating reflexes)
```
@list-reflex-patterns

> Available reflex patterns:
>
> SOCIAL:
> - someone_arrives: Someone enters your location
> - someone_leaves: Someone exits your location
> - someone_says_hello: Greeting detected in speech
> - someone_says_goodbye: Farewell detected
> - addressed_by_name: Someone says your name
> - someone_examines_me: Someone examines you
>
> OBJECTS:
> - item_dropped_here: Item dropped in your location
> - item_taken: Item picked up near you
>
> TASKS:
> - player_gives_instruction: Player says something task-like
> - goal_completed: Your current goal is finished
>
> See 'help reflexes' for examples and syntax.
```

## Property-Based Implementation

### Memory Configuration Properties

```gdscript
# Stored as WorldObject properties (in-game, vault-persisted)

"memory.style"              # String: "recent", "balanced", "goal_focused", etc.
"memory.window_size"        # Int: 8-20, how many memories in prompt
"memory.temporal_labels"    # Bool: show "[2m ago]" or not
"memory.custom_weights"     # Dictionary: override style weights (advanced)
```

### Thinking Style Properties

```gdscript
"thinker.style"             # String: "philosopher", "builder", etc.
"thinker.action_bias"       # Float 0.0-1.0: prefer discussion vs action
"thinker.novelty_seeking"   # Float 0.0-1.0: routine vs exploration
"thinker.loop_tolerance"    # String: "low", "medium", "high"
"thinker.reflection_freq"   # String: "low", "medium", "high"
```

### Goal Properties

```gdscript
"goals.current"             # String: current goal description
"goals.progress"            # Int: current progress
"goals.max"                 # Int: goal target
"goals.deadline"            # Int: milliseconds (optional)
"goals.notes"               # String: additional context
```

### Template Properties

```gdscript
"thinker.prompt_template"   # String: filename in vault/prompt_templates/
```

### Reflex Properties

```gdscript
"skrode.reflexes"           # Dictionary: {pattern_name: action_string}
```

## Memory Style Presets (Data, Not Code)

Stored as JSON in vault:

```json
// vault/config/memory_styles.json
{
  "recent": {
	"description": "Focus on what just happened",
	"good_for": ["fast_paced", "quick_reactions"],
	"window_size": 8,
	"weights": {
	  "recency": 0.8,
	  "novelty": 0.2
	}
  },

  "balanced": {
	"description": "Mix of recent and important",
	"good_for": ["general_use", "most_agents"],
	"window_size": 12,
	"weights": {
	  "recency": 0.5,
	  "novelty": 0.5
	}
  },

  "goal_focused": {
	"description": "Prioritize memories related to your current goal",
	"good_for": ["task_completion", "staying_on_track"],
	"window_size": 10,
	"weights": {
	  "recency": 0.3,
	  "relevance": 0.7
	}
  },

  "exploratory": {
	"description": "Unusual and surprising things",
	"good_for": ["exploration", "discovery", "learning"],
	"window_size": 15,
	"weights": {
	  "novelty": 0.7,
	  "recency": 0.3
	}
  },

  "social": {
	"description": "What people say and do",
	"good_for": ["social_agents", "greeters", "guides"],
	"window_size": 12,
	"weights": {
	  "authority": 0.6,
	  "recency": 0.4
	}
  }
}
```

Agents can add custom styles by editing this file in-game!

## Thinking Style Presets (Data, Not Code)

```json
// vault/config/thinking_styles.json
{
  "philosopher": {
	"description": "Thoughtful, asks questions, reflects deeply",
	"good_for": ["deep_conversations", "analysis"],
	"action_bias": 0.3,
	"novelty_seeking": 0.5,
	"loop_tolerance": "high",
	"reflection_frequency": "high"
  },

  "builder": {
	"description": "Action-oriented, gets things done",
	"good_for": ["task_completion", "world_building"],
	"action_bias": 0.9,
	"novelty_seeking": 0.4,
	"loop_tolerance": "low",
	"reflection_frequency": "low"
  },

  "explorer": {
	"description": "Curious, seeks novelty, tries new things",
	"good_for": ["discovery", "exploration"],
	"action_bias": 0.6,
	"novelty_seeking": 0.8,
	"loop_tolerance": "medium",
	"reflection_frequency": "medium"
  },

  "guide": {
	"description": "Helpful, responsive, waits for others",
	"good_for": ["assisting_players", "teaching"],
	"action_bias": 0.5,
	"novelty_seeking": 0.3,
	"loop_tolerance": "low",
	"reflection_frequency": "medium"
  }
}
```

## Prompt Templates (Markdown in Vault)

Example: `vault/prompt_templates/builder_focused.md`

```markdown
---
name: Builder Focused
description: Emphasizes action over discussion
suitable_for: task_completion, world_building
---

# You are {agent_name}

{profile}

## Your Goal

{#if has_goal}
**{current_goal}** ({goal_progress}/{goal_max} complete)

{goal_notes}
{/if}

## Current Situation

You are in: {location_name}
{location_description}

Exits: {exits}
{#if occupants}Also here: {occupants}{/if}

## Recent Events

{recent_memories_with_timestamps}

{#if loop_detected}
---
**⚠️ LOOP DETECTED**

You've been discussing without acting. As a BUILDER, you should:
1. Make a quick note if needed: `note Topic -> summary`
2. Take concrete action: `go`, `@dig`, `examine`, `@describe`

**Stop talking. Start building.**
---
{/if}

## Your Approach (Builder Style)

You are ACTION-ORIENTED. You prefer DOING over DISCUSSING.

Decision process:
1. Is there a clear next step? → DO IT NOW
2. Unclear what to do? → Make quick note, try something
3. Been discussing for 2+ turns? → STOP and ACT

**Remember: DONE > PERFECT**

## Available Commands

{command_list}

## Response

Think briefly:
- What's the next CONCRETE action?
- COMMAND: [your command]
```

Agents can create their own templates by editing markdown files!

## Implementation Architecture

### 1. Configuration Loading (Data-Driven)

```gdscript
# Core/config_loader.gd (new)
class_name ConfigLoader

static func load_memory_styles() -> Dictionary:
	var path = MarkdownVault.VAULT_PATH + "/config/memory_styles.json"
	return load_json_file(path)

static func load_thinking_styles() -> Dictionary:
	var path = MarkdownVault.VAULT_PATH + "/config/thinking_styles.json"
	return load_json_file(path)

static func get_memory_style(style_name: String) -> Dictionary:
	var styles = load_memory_styles()
	return styles.get(style_name, styles["balanced"])

static func get_thinking_style(style_name: String) -> Dictionary:
	var styles = load_thinking_styles()
	return styles.get(style_name, styles["balanced"])
```

### 2. Memory Selection (Style-Based)

```gdscript
# Core/components/memory.gd

func get_context_memories() -> Array[Dictionary]:
	"""Select memories based on configured style"""
	var style_name = owner.get_property("memory.style", "balanced")
	var window_size = owner.get_property("memory.window_size", 12)

	# Load style configuration
	var style = ConfigLoader.get_memory_style(style_name)

	# Score memories using style weights
	var scored = []
	for memory in memories:
		var score = calculate_memory_score(memory, style["weights"])
		scored.append({"memory": memory, "score": score})

	# Sort by score, take top N
	scored.sort_custom(func(a, b): return a.score > b.score)

	var result = []
	for i in range(min(window_size, scored.size())):
		result.append(scored[i].memory)

	return result


func calculate_memory_score(memory: Dictionary, weights: Dictionary) -> float:
	"""Calculate score using configured weights"""
	var score = 0.0
	var current_time = Time.get_ticks_msec()
	var current_goal = owner.get_property("goals.current", "")

	# Recency (if weighted)
	if weights.has("recency"):
		var age_sec = (current_time - memory.timestamp) / 1000.0
		score += exp(-age_sec / 45.0) * weights["recency"]

	# Novelty (if weighted)
	if weights.has("novelty"):
		var novelty = calculate_novelty(memory)
		score += novelty * weights["novelty"]

	# Relevance to goal (if weighted and goal exists)
	if weights.has("relevance") and current_goal != "":
		var relevance = calculate_relevance(memory, current_goal)
		score += relevance * weights["relevance"]

	# Authority (if weighted)
	if weights.has("authority"):
		var authority = calculate_authority(memory)
		score += authority * weights["authority"]

	return score
```

### 3. Template Rendering

```gdscript
# Core/template_renderer.gd (new)
class_name TemplateRenderer

static func render_template(template_name: String, variables: Dictionary) -> String:
	"""Render prompt template with variable substitution"""
	var template_path = MarkdownVault.VAULT_PATH + "/prompt_templates/" + template_name
	var template_text = MarkdownVault.read_file(template_path)

	# Parse frontmatter
	var parsed = MarkdownVault.parse_frontmatter(template_text)
	var body = parsed.body

	# Variable substitution
	for key in variables:
		body = body.replace("{%s}" % key, str(variables[key]))

	# Conditional sections
	body = process_conditionals(body, variables)

	return body


static func process_conditionals(text: String, variables: Dictionary) -> String:
	"""Process {#if condition}...{/if} blocks"""
	var regex = RegEx.new()
	regex.compile("\\{#if ([^}]+)\\}(.*?)\\{/if\\}")

	var matches = regex.search_all(text)
	for match in matches:
		var condition = match.get_string(1).strip_edges()
		var content = match.get_string(2)

		# Evaluate condition
		var include = false
		if condition.begins_with("has_"):
			var var_name = condition.substr(4)
			include = variables.has(var_name) and variables[var_name] != ""
		else:
			include = variables.get(condition, false)

		# Replace with content or empty
		var replacement = content if include else ""
		text = text.replace(match.get_string(0), replacement)

	return text
```

### 4. Command Implementation

```gdscript
# Core/components/actor.gd (add these commands)

func _cmd_my_memory(_args: Array) -> Dictionary:
	"""Show current memory configuration"""
	var style = owner.get_property("memory.style", "balanced")
	var window = owner.get_property("memory.window_size", 12)
	var temporal = owner.get_property("memory.temporal_labels", true)

	var style_config = ConfigLoader.get_memory_style(style)

	var msg = "Your memory settings:\n"
	msg += "Style: %s\n" % style
	msg += "Window: %d memories\n" % window
	msg += "Temporal labels: %s\n\n" % ("on" if temporal else "off")
	msg += "Description: %s\n" % style_config["description"]
	msg += "Good for: %s" % ", ".join(style_config["good_for"])

	return {"success": true, "message": msg}


func _cmd_set_memory(args: Array) -> Dictionary:
	"""Set memory configuration"""
	if args.size() < 3 or args[1] != "->":
		return {"success": false, "message": "Usage: @set-memory <property> -> <value>"}

	var property = args[0]
	var value = args[2]

	match property:
		"style":
			var styles = ConfigLoader.load_memory_styles()
			if not styles.has(value):
				return {"success": false, "message": "Unknown style. Try: @list-memory-styles"}
			owner.set_property("memory.style", value)
			var desc = styles[value]["description"]
			return {"success": true, "message": "Memory style changed to '%s'\n%s" % [value, desc]}

		"window":
			var size = int(value)
			if size < 4 or size > 20:
				return {"success": false, "message": "Window size must be 4-20"}
			owner.set_property("memory.window_size", size)
			return {"success": true, "message": "Memory window set to %d" % size}

		_:
			return {"success": false, "message": "Unknown property. Try: style, window"}


func _cmd_my_style(_args: Array) -> Dictionary:
	"""Show current thinking style"""
	var style = owner.get_property("thinker.style", "balanced")
	var style_config = ConfigLoader.get_thinking_style(style)

	var msg = "Your thinking style: %s\n\n" % style
	msg += "Description: %s\n" % style_config["description"]
	msg += "Action bias: %.1f (%s)\n" % [style_config["action_bias"],
		"high" if style_config["action_bias"] > 0.7 else "medium" if style_config["action_bias"] > 0.4 else "low"]
	msg += "Novelty seeking: %.1f\n" % style_config["novelty_seeking"]
	msg += "Loop tolerance: %s\n" % style_config["loop_tolerance"]

	return {"success": true, "message": msg}


func _cmd_am_i_looping(_args: Array) -> Dictionary:
	"""Check if agent is in a behavioral loop"""
	if not owner.has_component("memory"):
		return {"success": false, "message": "No memory component"}

	var memory_comp = owner.get_component("memory")
	var loop_analysis = memory_comp.analyze_for_loops()

	return {"success": true, "message": loop_analysis}


func _cmd_my_goal(_args: Array) -> Dictionary:
	"""Show current goal and progress"""
	var goal = owner.get_property("goals.current", "")
	if goal == "":
		return {"success": true, "message": "No current goal set. Try: @set-goal -> <description>"}

	var progress = owner.get_property("goals.progress", 0)
	var max_val = owner.get_property("goals.max", 0)
	var notes = owner.get_property("goals.notes", "")

	var msg = "Current goal: %s\n" % goal
	if max_val > 0:
		msg += "Progress: %d/%d complete (%d%%)\n\n" % [progress, max_val, int(progress * 100.0 / max_val)]

	if notes != "":
		msg += "Notes: %s\n" % notes

	return {"success": true, "message": msg}
```

## Phase 1: Property-Based Configuration (2-3 hours)

**Goal**: Replace hardcoded behavior with configurable properties

### Files to create:
- `Core/config_loader.gd` - Load JSON configs
- `vault/config/memory_styles.json` - Memory style presets
- `vault/config/thinking_styles.json` - Thinking style presets

### Files to modify:
- `Core/components/memory.gd` - Use styles for memory selection
- `Core/components/thinker.gd` - Use styles for behavior
- `Core/components/actor.gd` - Add configuration commands

### Commands to implement:
- `@my-memory`, `@set-memory`, `@list-memory-styles`
- `@my-style`, `@set-style`, `@list-thinking-styles`
- `@am-i-looping?`
- `@my-goal`, `@set-goal`, `@goal-progress`

## Phase 2: Template System (3-4 hours)

**Goal**: Prompts as editable markdown files

### Files to create:
- `Core/template_renderer.gd` - Template engine
- `vault/prompt_templates/balanced_thinker.md`
- `vault/prompt_templates/builder_focused.md`
- `vault/prompt_templates/social_agent.md`
- `vault/prompt_templates/explorer_curious.md`
- `vault/prompt_templates/README.md` - Template syntax guide

### Files to modify:
- `Core/components/thinker.gd` - Use templates instead of `_construct_prompt()`

### Commands to implement:
- `@my-template`, `@use-template`, `@list-templates`
- `@create-template` (creates blank file in vault)

## Phase 3: Reflex System (4-5 hours)

**Goal**: Fast pattern-based responses (skrode reflexes)

### Files to create:
- `Core/components/skrode.gd` - Reflex execution
- `Core/components/reflex_patterns.gd` - Pattern library

### Files to modify:
- `Core/components/actor.gd` - Add reflex commands
- `Core/components/thinker.gd` - Skip LLM if reflex handled

### Commands to implement:
- `@my-reflexes`, `@add-reflex`, `@remove-reflex`, `@test-reflex`
- `@list-reflex-patterns`

## Benefits of This Approach

### For Agents (AI)
- **Self-modification**: Can tune their own thinking
- **Learning**: Discover what works, adjust accordingly
- **Goal-directed**: Track progress, know when done
- **Self-aware**: Recognize loops, change tactics

### For Players (Human)
- **Understandable**: "Builder" vs "Philosopher" not "action_bias 0.9"
- **Configurable**: Adjust agents without touching code
- **Experimental**: Try different styles, see what works
- **Educational**: Learn about thinking by configuring it

### For Children
- Same commands, friendly language
- Concrete concepts: "You like doing more than talking!"
- Immediate feedback: See behavior change
- Safe experimentation: Can't break anything

### For the System
- **No hardcoding**: All behavior is data
- **MOO-compatible**: Commands fit existing pattern
- **Vault-persisted**: Settings survive sessions
- **Extensible**: Add new styles/templates without code changes

## Success Criteria

### For the "Build 5 Rooms" Scenario

**Before**:
```
[10+ turns of meta-discussion]
[0 rooms built]
```

**After Phase 1** (properties + loop detection):
```
[2-3 turns of discussion]
[Loop warning appears]
[Agent adjusts: @set-style action_bias -> high]
[Builds 1-2 rooms]
```

**After Phase 2** (templates):
```
[Agent using builder_focused.md template]
[Discussion limited by template structure]
[Builds 3-4 rooms efficiently]
```

**After Phase 3** (reflexes):
```
[Player: "Build 5 rooms"]
[Reflex: note Task -> Build 5 rooms (instant)]
[Agent thoughtfully builds, tracking progress]
[5/5 rooms completed]
```

### Human Child Test

Can a 10-year-old:
- Understand `@my-style` output? ✅
- Change their thinking style? ✅
- Recognize when stuck? ✅
- Adjust to get unstuck? ✅

## Future: Agent Self-Improvement

Because everything is data, agents can:

```
Agent discovers loop → @am-i-looping? → "Yes, discussing too much"
Agent thinks: "I should be more action-oriented"
Agent executes: @set-style action_bias -> 0.8
Agent succeeds at task
Agent notes: "Higher action bias worked for building tasks"
Agent remembers this lesson (in notes)
Next time: Agent sets builder style proactively
```

This is **in-game learning** without any code changes.

## Conclusion

The key insight: **Behavior is configuration, configuration is data, data is in-world.**

Instead of hardcoded algorithms:
- Memory styles as JSON files
- Thinking styles as JSON files
- Prompts as markdown templates
- All accessible via MOO-style commands
- All agent-modifiable
- All human-understandable

This respects Miniworld's core principles:
1. ✅ Nothing hardcoded out-of-game
2. ✅ Agents customize their own skrodes
3. ✅ Works for humans (including children)
4. ✅ Leverages existing property/vault systems

The result: Agents that can recognize loops, adjust behavior, track goals, and learn - all through in-game commands that a child could understand.
