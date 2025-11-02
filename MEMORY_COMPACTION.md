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

2. **Short-term Summary** (65-128 from end)
   - LLM-generated 2-3 sentence summary
   - Covers memories that aged out of immediate window
   - Provides mid-range historical context
   - Generated at 129 memories, then every ~64 memories thereafter
   - Updates in clean chunks (not on every single memory)
   - Historical versions saved with timestamps for future analysis

3. **Long-term Summary** (all older memories)
   - Progressively compacted summary
   - Waterfalls older short-term summaries together
   - Preserves distant historical patterns
   - Traces back to earliest memories (never loses history)
   - Persisted to vault (user://agents/{name}/summaries/)

### Waterfall Pattern

Every compaction cycle (triggered at 129 memories, then every ~64 thereafter):

```
1. Long-term summary ← LLM(short_term_summary + longterm_summary)
2. Short-term summary ← LLM(memories outside immediate window)
3. Immediate context ← 64 newest memories (unchanged)
4. Save both summaries to vault for persistence
5. Save timestamped copy of short-term summary for historical analysis
```

This creates a cascading effect where:
- Recent details stay crisp (64 memories in full)
- Mid-range context gets summarized (next 64 memories → paragraph)
- Distant history gets progressively compressed (waterfall squashing)
- Compaction triggers at 129 memories (immediate + recent windows filled)
- Then every ~64 new memories (not on every single memory)
- Long-term summary traces back to earliest memories (never loses history)
- Summaries persist across restarts (vault storage)
- Historical short-term summaries preserved with timestamps

## Configuration

All settings in `vault/config/memory_compaction.md`:

- `immediate_window`: 64 - Most recent memories in full detail
- `recent_window`: 64 - Size of short-term summary window
- `profile`: "summarizer" - LLM profile for summaries

## Usage

### Automatic Compaction

Runs automatically at 129 memories, then every ~64 memories thereafter:
```
First compaction:  immediate_window + recent_window = 128 + 1 = 129 memories
Next compactions:  every recent_window (64) new memories
```

When an agent reaches 129 memories, compaction triggers asynchronously:
1. Waterfalls old short-term summary into long-term (progressive squashing)
2. Generates new short-term summary from memories outside immediate window
3. Saves both summaries to vault for persistence
4. Saves timestamped copy of short-term summary for historical analysis

Then repeats every ~64 new memories (193, 257, 321...).

This ensures agents get summarization in clean chunks without regenerating summaries on every single new memory, while maintaining long-term summaries that trace back to their earliest memories.

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

1. Create an agent and have them accumulate 129+ memories (immediate + recent windows)
2. Watch for first compaction logs:
   ```
   [Memory] AgentName: Starting compaction (129 memories, 64 immediate, 64 recent)
   [Memory] AgentName: Short-term summary updated (127 chars)
   [Memory] AgentName: Compaction complete (first summary)
   ```

3. Continue adding memories (to 193+) to see waterfall compaction:
   ```
   [Memory] AgentName: Starting compaction (193 memories, 64 immediate, 64 recent)
   [Memory] AgentName: Long-term summary updated (215 chars)
   [Memory] AgentName: Short-term summary updated (134 chars)
   [Memory] AgentName: Compaction complete (waterfall)
   ```

4. Use `@memory-status` to verify summaries exist
5. Check vault folder for timestamped short-term summaries (recent-YYYYMMDD-HHMMSS.md)
6. Restart the agent to verify summaries load from vault
7. Use `@compact-memories` to manually trigger

## Benefits

1. **Attention Budget**: Summaries are token-efficient vs. full memories
2. **Historical Context**: Agents remember distant events via summaries
3. **Progressive Disclosure**: Most recent = most detail, older = compressed
4. **Clean Chunks**: Summaries regenerate every ~64 memories (not per-memory)
5. **Progressive Squashing**: Long-term summary traces back to earliest memories
6. **Persistence**: Summaries survive restarts via vault storage
7. **Historical Record**: Timestamped short-term summaries preserved for future features
8. **Base Model Support**: Works with comma-v0.1-2t and other base models
9. **Universal**: Effective for instruct/chat models too
10. **Automatic**: Runs in background, no manual intervention needed

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
