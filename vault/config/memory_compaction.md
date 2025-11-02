# Memory Compaction Configuration

Settings for multi-scale memory context retention using cascading temporal summaries.

Based on Anthropic's context engineering best practices, this system maintains:
- **Immediate window**: Full detail for recent memories
- **Recent summary**: LLM-generated summary of aged-out memories
- **Long-term summary**: Progressively compacted summary of all older memories

---

## Compaction Windows

**immediate_window**: 64
_Number of most recent memories to keep in full detail_

**recent_window**: 64
_Number of memories before immediate window to summarize (creates short-term summary)_

**Notes**:
- Immediate memories (64) appear in full in agent prompts - provides rich context
- Compaction triggers at 129 memories (immediate + recent windows filled)
- Then compaction runs again every ~64 new memories (recent_window size)
- When compaction runs:
  1. Old short-term summary waterfalls into long-term (progressive squashing)
  2. New short-term summary generated from memories outside immediate window
- This ensures long-term summary traces back to earliest memories
- Short-term summary updates every ~64 memories (not on every single memory)
- Long-term summary grows progressively with each short-term update
- Historical short-term summaries saved with timestamps for future analysis

---

## LLM Profile for Summarization

**profile**: summarizer
_LLM profile name used for generating summaries_

**Notes**:
- Uses /api/generate endpoint (optimized for base models)
- Works with both base and instruct models
- Summarization prompts are simple and direct
- Stop tokens prevent runaway generation

---

## Usage

**Automatic**: Compaction runs automatically at 129 memories, then every ~64 memories thereafter
**Manual**: Use `@compact-memories` command to force compaction
**Status**: Use `@memory-status` to see summary stats and integrity report
**Persistence**: Summaries automatically saved to vault after each compaction
**Historical**: Short-term summaries saved with timestamps (recent-YYYYMMDD-HHMMSS.md)

---

## Design Notes

This implements the "waterfall" pattern from Anthropic's context engineering article:

1. **Long-term summary** ← LLM(short_term_summary + longterm_summary)
2. **Short-term summary** ← LLM(memories outside immediate window)
3. **Immediate context** ← N newest memories (unchanged)

Each compaction cycle (triggered at 129 memories, then every ~64 thereafter):
- Waterfalls old short-term summary into long-term (progressive squashing)
- Generates new short-term summary from memories outside immediate window
- Preserves most recent memories (immediate window) in full detail
- Saves both summaries to vault for persistence
- Saves timestamped copy of short-term summary for historical analysis

This ensures:
- Long-term summary traces back to earliest memories (never loses history)
- Short-term summary updates every ~64 memories (clean chunks, not per-memory)
- Agents maintain multi-scale temporal context without overwhelming LLM attention
- Summaries persist across restarts (vault storage)
- Historical record of short-term summaries preserved for future features

---

## Base Model Compatibility

Summarization prompts are optimized for base models (like comma-v0.1-2t):
- Direct task framing with clear structural guidance
- First-person perspective explicitly specified (I/me/my)
- No meta-commentary instructions prevent "Here is a summary..." responses
- Stop tokens configured server-side
- Simple, predictable format

The same prompts work effectively with instruct/chat models.

**Prompt Format**:
```
# Memories:
[memory lines]

# Summary (first-person perspective, I/me/my, no meta-commentary):
>
```

This ensures summaries are pure narrative, not wrapped in conversational framing.
