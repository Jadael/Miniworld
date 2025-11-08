# Default AI Agent Configuration

These values are used when creating new AI agents or when per-agent properties are not set.
Individual agents can override these via their `thinker.*` properties.

---

## Timing

**think_interval**: 6.0
_Seconds between autonomous thoughts for AI agents_

**min_think_interval**: 1.0
_Minimum allowed interval (validation)_

---

## Context Building

**prompt_memory_limit**: 64
_Maximum memories included in AI prompt context_

**context_notes_max**: 3
_Maximum relevant notes from personal wiki in prompt_

---

## Dream Analysis

**dream_memory_count**: 128
_Total memories to analyze during dream (mix of recent and older experiences)_

**dream_expansion_multiplier**: 2.0
_Multiplier for older memory sampling (2.0 = sample 2x recent count from archive)_

**dream_chunk_min**: 2
_Minimum memories per narrative chunk (for dream-like non-linear structure)_

**dream_chunk_max**: 4
_Maximum memories per narrative chunk_

---

## Notes

- All timing values are in seconds (float)
- Memory limits affect prompt size and LLM token usage
- Agents can customize these via properties like `thinker.think_interval`
