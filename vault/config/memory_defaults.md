# Memory System Configuration

Default settings for the memory component and note-taking system.

**NOTE**: Memory limits are now managed dynamically by the MemoryBudget daemon.
See `memory_budget.md` for resource-based allocation settings.

---

## Legacy Settings (For Reference)

**max_memories_per_agent**: 65536
_DEPRECATED: Now calculated dynamically by MemoryBudget daemon_

**load_memories_limit**: 65536
_Maximum memories loaded from vault on agent initialization (still used)_

**recent_memories_default**: 24
_Default number of recent memories to retrieve for AI prompts_

---

## Search Behavior

**min_similarity_threshold**: 0.0
_Minimum cosine similarity for semantic search results (0.0-1.0)_

**max_notes_display**: 12
_Maximum notes to display in recall command results_

---

## Dynamic Memory Budgeting (NEW)

As of this version, memory limits are calculated dynamically based on:
- Available system RAM (monitored via Performance class)
- Number of active agents
- Configured percentage allocation (see `memory_budget.md`)

### Migration Notes

- Old fixed limits (4096, 100, etc.) are now obsolete
- MemoryBudget scales from 1K-1M memories per agent automatically
- Low-end systems get smaller caches, high-end systems get larger
- Vault files persist ALL memories regardless of in-RAM limit

### Configuration

See `memory_budget.md` for tuning:
- `percent_of_ram` - How much RAM to use for memories
- `min_per_agent` / `max_per_agent` - Bounds on per-agent limits
- `avg_memory_size` - Estimated bytes per memory

---

## Notes

- Similarity threshold of 0.0 returns all results, ranked by similarity
- Higher thresholds (e.g., 0.5) filter to more relevant matches only
- Use `@memory-budget` command in-game to inspect current allocation
