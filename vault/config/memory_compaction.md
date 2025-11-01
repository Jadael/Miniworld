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
_Number of memories before immediate window to summarize (creates mid-term summary)_

**compaction_threshold**: 256
_Total memories before triggering compaction (should be much larger than immediate + recent windows)_

**Notes**:
- Immediate memories (64) appear in full in agent prompts - provides rich context
- Recent window (64) gets summarized into mid-term summary when threshold exceeded
- Compaction is progressive: mid-term summary → long-term summary → recent → mid-term
- Default threshold (256) means compaction only triggers with substantial memory buildup
- This prevents overly aggressive context reduction

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

**Automatic**: Compaction runs automatically when memories exceed threshold
**Manual**: Use `@compact-memories` command to force compaction
**Status**: Use `@memory-status` to see summary stats

---

## Design Notes

This implements the "waterfall" pattern from Anthropic's context engineering article:

1. **Long-term summary** ← LLM(recent_summary + longterm_summary)
2. **Recent summary** ← LLM(memories outside immediate window)
3. **Immediate context** ← N newest memories (unchanged)

Each compaction cycle:
- Waterfalls the recent summary into long-term
- Generates new recent summary from aged-out memories
- Preserves most recent memories in full detail

This provides agents with multi-scale temporal context without overwhelming
the LLM's attention budget.

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
