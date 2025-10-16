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

**dream_recent_count**: 5
_Recent memories included in dream analysis_

**dream_random_count**: 5
_Random memories included in dream analysis_

---

## Notes

- All timing values are in seconds (float)
- Memory limits affect prompt size and LLM token usage
- Agents can customize these via properties like `thinker.think_interval`
