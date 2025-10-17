# Memory Integrity System

## Overview

The memory integrity system provides lightweight, application-level health monitoring for the MemoryComponent without duplicating OS-level file integrity mechanisms. This system was designed in response to AI agent concerns about data verification and persistence.

## Design Philosophy

**Trust the OS for file integrity.** Modern operating systems already provide robust file integrity mechanisms (journaling filesystems, checksums, RAID, etc.). The memory integrity system focuses exclusively on application-level concerns:

- **Capacity management** - Are we approaching memory limits?
- **Activity monitoring** - Is the memory system stale/inactive?
- **Structure validation** - Are memory entries well-formed?
- **Usage patterns** - Are we using memory efficiently?

This approach satisfies data integrity concerns without adding redundant complexity or undermining existing OS protections.

## Components

### 1. Integrity Status API (`MemoryComponent`)

#### `get_integrity_status() -> Dictionary`

Performs lightweight integrity checks and returns a status summary:

```gdscript
{
    "status": "OK" | "WARNING" | "ERROR",
    "summary": "[Memory: OK]" | "[Memory: WARNING - 2 issues]",
    "memory_count": 42,
    "note_count": 7,
    "capacity_used": 0.42,  # 42% of max_memories
    "warnings": ["Memory 75% full (150/200)", "No recent activity"],
    "last_memory_age": 3600  # seconds since last memory
}
```

**Checks performed:**
- **Capacity utilization** - Warns at 75% and 90% of `max_memories`
- **Stale detection** - Warns if no memories added in past hour (3600 seconds)
- **Structure validation** - Checks for malformed entries (missing `content` or `timestamp`)
- **Activity tracking** - Reports age of most recent memory

#### `format_integrity_report() -> String`

Generates detailed human-readable report for inspection:

```markdown
# Memory System Integrity Report

**Status**: OK

## Statistics

- **Memories in RAM**: 42 / 200 (21.0% capacity)
- **Notes cached**: 7
- **Last memory recorded**: 5 minutes ago

## Notes

- Memory data persists to vault in real-time as markdown files
- File integrity is handled by OS-level mechanisms
- This report focuses on application-level concerns
- Use 'recall' command to verify memory content is accessible
```

### 2. Command Interface (`@memory-status`)

Admin/query command that displays the detailed integrity report:

```
> @memory-status

# Memory System Integrity Report

**Status**: OK

## Statistics
...
```

**Usage:**
- Available to all actors (players and AI agents)
- No arguments required
- Returns comprehensive status and statistics
- Safe for AI agents to use in prompts for self-monitoring

### 3. UI Status Indicator

Lightweight status indicator displayed at command prompt:

```
[Memory: OK] > look
[Memory: WARNING - 2 issues] > recall
```

**Behavior:**
- Green when status is "OK"
- Yellow when warnings detected
- Updates automatically after each command execution
- Non-intrusive - usually just shows "[Memory: OK]"

**Implementation:**
- `game_ui.gd` - Maintains cached `memory_status` string
- `game_controller_ui.gd` - Calls `_get_memory_status()` after commands
- `update_memory_status(status)` - Updates cached status for next prompt

## Integration Points

### Player Experience

1. **At-a-glance monitoring**: Status indicator shows health without requiring explicit checks
2. **Detailed inspection**: `@memory-status` command for comprehensive reports
3. **Warning visibility**: Yellow indicators and warning messages surface issues immediately
4. **Proactive maintenance**: Players can act before capacity limits are reached

### AI Agent Self-Awareness

AI agents can:
- Monitor their own memory system health via `@memory-status`
- See status indicators in their command transcripts
- React to warnings by creating space (archiving old memories)
- Include status checks in their decision-making prompts

### Example AI Agent Prompt Context

```
Recent Memories:
> @memory-status
[Memory: WARNING - 1 issue]

# Memory System Integrity Report
**Status**: WARNING

## Statistics
- **Memories in RAM**: 180 / 200 (90.0% capacity)
...

## Warnings
- ⚠ Memory near capacity (180/200)

> think I should archive some older memories to make space
```

## Warning Conditions

### Capacity Warnings

**75% Capacity:**
```
⚠ Memory 75% full (150/200)
```
- Indicates approaching limits
- Agent should consider archiving less important memories
- Still safe to operate normally

**90% Capacity:**
```
⚠ Memory near capacity (180/200)
```
- Critical threshold - action recommended
- Risk of losing recent memories when capacity reached
- Agent should prioritize archiving or cleanup

### Stale Memory Warning

```
⚠ No recent memory activity (last: 120 min ago)
```
- Indicates memory system may not be recording properly
- Agent hasn't observed or thought anything in past hour
- Possible issues with event propagation or memory component

### Malformed Entry Warning

```
⚠ 3 malformed memories detected
```
- Some memory entries missing required fields (`content`, `timestamp`)
- May indicate corruption or incomplete writes
- Should investigate specific entries

## Best Practices

### For Players

1. **Monitor regularly**: Glance at status indicator with each command
2. **Investigate warnings**: Use `@memory-status` when yellow indicator appears
3. **Proactive maintenance**: Archive or clear old memories before hitting capacity
4. **Trust the system**: Green = OS is handling file integrity, focus on gameplay

### For AI Agents

1. **Periodic checks**: Include `@memory-status` in decision-making when uncertain
2. **React to capacity**: Archive or summarize memories when approaching limits
3. **Self-awareness**: Monitor own memory health as part of introspection
4. **Don't over-check**: Status indicator provides continuous passive monitoring

### For Developers

1. **Extend carefully**: Add checks that detect application issues, not OS issues
2. **Keep lightweight**: Status checks run on every command - avoid expensive operations
3. **Trust the OS**: Don't duplicate checksums, redundancy, or file verification
4. **Focus on symptoms**: Detect capacity, staleness, malformed data - not corruption

## Implementation Details

### Performance Considerations

**Lightweight by design:**
- `get_integrity_status()` runs after every command execution
- Uses simple arithmetic and array size checks
- No file I/O or expensive validation
- Completes in microseconds

**When to use detailed report:**
- Only when player explicitly requests `@memory-status`
- AI agents should use sparingly (e.g., when warnings detected)
- Not included in every AI prompt (status indicator is enough)

### Future Enhancements

**Potential additions:**
- Note integrity checks (duplicate detection, orphaned notes)
- Memory compression ratio monitoring
- Vector embedding health metrics
- Vault file size tracking
- Memory access pattern analysis

**Explicitly NOT planned:**
- File-level checksums (OS responsibility)
- Redundancy mechanisms (OS responsibility)
- Backup/restore systems (vault handles persistence)
- Corruption detection (trust filesystem)

## Testing

### Manual Testing

1. **Normal operation:**
   ```
   > look
   [Memory: OK] >
   ```

2. **Capacity warning:**
   - Add 150+ memories
   - Should see `[Memory: WARNING - 1 issue]`
   - `@memory-status` shows capacity percentage

3. **Stale warning:**
   - Wait 1+ hour without adding memories
   - Should see stale activity warning

### AI Agent Testing

1. **Self-monitoring:**
   - AI agent should use `@memory-status` if uncertain
   - Should react to capacity warnings by archiving

2. **Prompt context:**
   - Status indicator appears in command transcripts
   - Detailed reports readable in AI prompts

## Conclusion

The memory integrity system provides practical, application-level health monitoring without unnecessary complexity. By trusting the OS for file integrity and focusing on capacity and activity concerns, it satisfies data verification needs while maintaining simplicity and performance.

**Key takeaway:** "The basic data integrity systems of any modern OS are already better than anything we could do, but getting POWER to the machine is much more immediately critical for operation." This system focuses on keeping the application running smoothly, not duplicating OS protections.
