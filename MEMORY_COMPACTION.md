# Memory Compaction Implementation

## Overview

We've implemented cascading temporal summaries for AI agent memory, based on Anthropic's context engineering best practices. This provides agents with multi-scale historical context without overwhelming the LLM's attention budget.

## How It Works

### Three-Tier Memory System

1. **Immediate Window** (default: 64 memories)
   - Most recent memories in full detail
   - Shown verbatim in agent prompts
   - Acts as few-shot examples for base models
   - Provides rich context for decision-making

2. **Mid-term Summary** (default: prior 64 memories)
   - LLM-generated 2-3 sentence summary
   - Covers memories that aged out of immediate window
   - Provides mid-range historical context
   - Generated when compaction threshold exceeded

3. **Long-term Summary** (all older memories)
   - Progressively compacted summary
   - Waterfalls older mid-term summaries together
   - Preserves distant historical patterns

### Waterfall Pattern

Every compaction cycle:

```
1. Long-term summary ← LLM(mid-term_summary + longterm_summary)
2. Mid-term summary ← LLM(memories outside immediate window)
3. Immediate context ← 64 newest memories (unchanged)
```

This creates a cascading effect where:
- Recent details stay crisp (64 memories in full)
- Mid-range context gets summarized (next 64 memories → paragraph)
- Distant history gets progressively compressed
- Compaction only triggers at 256+ total memories (prevents aggressive cutoff)

## Configuration

All settings in `vault/config/memory_compaction.md`:

- `immediate_window`: 64 - Memories in full detail
- `recent_window`: 64 - Memories to summarize into mid-term summary
- `compaction_threshold`: 256 - Total memories before triggering compaction
- `profile`: "summarizer" - LLM profile for summaries

## Usage

### Automatic Compaction

Runs automatically when memories exceed threshold:
```
compaction_threshold = 256 (default)
```

When an agent accumulates more than 256 memories, compaction triggers asynchronously. This prevents overly aggressive context reduction while still providing progressive summarization for long-running agents.

### Manual Compaction

Force compaction regardless of threshold:
```
@compact-memories
```

### Checking Status

View memory stats and summaries:
```
@memory-status
```

## Implementation Details

### Files Modified

1. **Core/components/memory.gd**
   - Added `recent_summary`, `longterm_summary`, `last_compaction_time` properties
   - Implemented `compact_memories_async()` with waterfall logic
   - Added `get_recent_context()` method returning summaries + immediate memories
   - Added `should_compact()` threshold check
   - Integrated compaction trigger in `add_memory()`

2. **Core/components/thinker.gd**
   - Updated `_build_context()` to use `get_recent_context()`
   - Modified `_construct_prompt()` to include summaries in prompt
   - Added documentation about multi-scale memory context

3. **Core/components/actor.gd**
   - Added `@compact-memories` command
   - Command manually triggers compaction

4. **vault/config/memory_compaction.md**
   - Configuration file with window sizes and LLM profile

### Base Model Compatibility

Summarization prompts optimized for base models (like comma-v0.1-2t):

```gdscript
"Summarize these memories in 2-3 sentences:\n\n"
+ [memory contents]
+ "\nSUMMARY:\n"
```

- Direct task framing (no chat wrapper)
- Uses `/api/generate` endpoint
- Stop tokens configured server-side
- Works equally well with instruct/chat models

### Prompt Structure

Agent prompts now include summaries before the transcript:

```
You are AgentName. [profile]

BASIC COMMANDS:
- [command list]

## Relevant Private Notes
[contextual notes]

## Older Memories (Summary)
[longterm_summary if exists]

## Recent Past (Summary)
[recent_summary if exists]

---
[immediate memories in full detail]
---

You are AgentName in LocationName. [description]
Exits: [exits]
Also here: [occupants]
~AgentName>
```

This structure:
- Provides historical context via summaries
- Keeps recent memories as few-shot examples
- Maintains base model compatibility
- Prevents context rot from excessive history

## Testing

To test the system:

1. Create an agent with 40+ memories (or lower threshold in config)
2. Watch for compaction logs:
   ```
   [Memory] AgentName: Starting compaction (260 memories, 64 immediate, 64 recent)
   [Memory] AgentName: Recent summary updated (127 chars)
   [Memory] AgentName: Long-term summary updated (215 chars)
   [Memory] AgentName: Compaction complete
   ```

3. Use `@memory-status` to verify summaries exist
4. Use `@compact-memories` to manually trigger

## Benefits

1. **Attention Budget**: Summaries are token-efficient vs. full memories
2. **Historical Context**: Agents remember distant events via summaries
3. **Progressive Disclosure**: Most recent = most detail, older = compressed
4. **Base Model Support**: Works with comma-v0.1-2t and other base models
5. **Universal**: Effective for instruct/chat models too
6. **Automatic**: Runs in background, no manual intervention needed

## Future Enhancements

Potential improvements:
- Semantic clustering before summarization
- Different summary lengths based on importance
- User-configurable compaction strategies
- Summary quality metrics and validation
- Periodic re-summarization of long-term summary

## References

- [Anthropic: Effective context engineering for AI agents](https://www.anthropic.com/news/context-engineering)
- Project CLAUDE.md: Context engineering patterns
- Memory component implementation: `Core/components/memory.gd:407-580`
- Thinker integration: `Core/components/thinker.gd:259-401`
