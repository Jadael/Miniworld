# Memory Budget Configuration

Dynamic memory allocation system that scales based on available system resources.

---

## Budget Allocation

**percent_of_ram**: 0.05
_Percentage of total RAM to allocate for agent memories (5% = 200MB on 4GB system)_

**avg_memory_size**: 300
_Estimated bytes per memory entry (includes content and metadata)_

---

## Per-Agent Limits

**min_per_agent**: 1024
_Minimum memories per agent (never go below 1K regardless of budget)_

**max_per_agent**: 1048576
_Maximum memories per agent (cap at 1M = ~300MB per agent)_

---

## How It Works

The MemoryBudget daemon:
1. Monitors current app memory usage via Performance.MEMORY_STATIC
2. Estimates total system RAM (conservative heuristic)
3. Allocates `percent_of_ram` of total RAM for memories
4. Divides budget equally among all agents with Memory components
5. Recalculates every 5 seconds or when agent count changes

### Scaling Examples

**Low-end (4GB RAM, 5% budget = 200MB)**
- 1 agent: 682K memories (~205MB)
- 2 agents: 341K memories each (~102MB each)
- 10 agents: 68K memories each (~20MB each)

**Mid-range (16GB RAM, 5% budget = 800MB)**
- 1 agent: 1M memories (capped at max_per_agent limit)
- 2 agents: 1M memories each (capped)
- 10 agents: 273K memories each (~82MB each)

**High-end (32GB RAM, 5% budget = 1.6GB)**
- 1 agent: 1M memories (capped)
- 2 agents: 1M memories each (capped)
- 10 agents: 546K memories each (~164MB each)

### Vault Persistence

**IMPORTANT**: These limits only affect in-memory cache. ALL memories are saved to vault immediately when created and persist indefinitely. The limit determines how many recent memories are kept in RAM for fast access.

---

## Tuning Guidelines

- **Increase percent_of_ram** (e.g., 0.10 = 10%) for memory-focused experiences
- **Decrease percent_of_ram** (e.g., 0.02 = 2%) for resource-constrained systems
- **Increase min_per_agent** if 1K memories is too few for short-term continuity
- **Increase max_per_agent** if you want individual agents to retain more in RAM
- **Adjust avg_memory_size** if profiling shows different typical sizes

### Console Command

Use `@memory-budget` in-game to see current allocation and adjust dynamically.

---

## Notes

- Budget recalculates automatically as agents are added/removed
- Falls back to 64K per agent if MemoryBudget daemon unavailable
- System uses conservative RAM estimation (assumes current usage is ~20% of total)
- Plain text memories are very small (~200-400 bytes each with metadata)
