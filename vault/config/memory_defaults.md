# Memory System Configuration

Default settings for the memory component and note-taking system.

---

## Memory Limits

**max_memories_per_agent**: 4096
_Maximum memories stored per agent before pruning oldest_

**load_memories_limit**: 4096
_Maximum memories loaded from vault on agent initialization_

**recent_memories_default**: 24
_Default number of recent memories to retrieve_

---

## Search Behavior

**min_similarity_threshold**: 0.0
_Minimum cosine similarity for semantic search results (0.0-1.0)_

**max_notes_display**: 12
_Maximum notes to display in recall command results_

---

## Notes

- Individual agents can override `max_memories_per_agent` via `memory.max_memories` property
- Similarity threshold of 0.0 returns all results, ranked by similarity
- Higher thresholds (e.g., 0.5) filter to more relevant matches only
