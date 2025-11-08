## MemoryBudget: Dynamic memory allocation for agent memories based on system resources
##
## This daemon calculates how many memories each agent should store based on:
## - Available system memory (via Performance monitoring)
## - Number of active agents in the world
## - Configurable budget percentage
##
## The system is designed to scale gracefully from low-end (4GB RAM) to
## high-end (32GB+ RAM) systems while keeping memory usage reasonable.
##
## Architecture:
## - Monitors current memory usage via Performance class
## - Allocates a percentage of available memory for agent memories
## - Divides budget equally among all agents with Memory components
## - Provides per-agent memory limits that scale dynamically
##
## Configuration (via TextManager):
## - memory_budget.percent_of_ram: Percentage of system RAM to use (default 5%)
## - memory_budget.min_per_agent: Minimum memories per agent (default 1024)
## - memory_budget.max_per_agent: Maximum memories per agent (default 1048576 = 1M)
## - memory_budget.avg_memory_size: Estimated bytes per memory (default 300)
##
## Usage:
##   var limit = MemoryBudget.get_memory_limit_for_agent(agent)
##
## Notes:
## - Budget recalculates when agents are added/removed
## - Falls back to safe defaults if Performance monitoring unavailable
## - Assumes plain text memories (~200-400 bytes each with metadata)

extends Node

# Singleton access
static var instance: MemoryBudget

# Cached budget calculation
var _cached_per_agent_limit: int = 65536  # Default: 64K memories per agent
var _cached_agent_count: int = 0
var _last_budget_calculation: int = 0
var _recalc_interval_ms: int = 5000  # Recalculate every 5 seconds

# Configuration defaults (overridden by vault config)
const DEFAULT_PERCENT_OF_RAM := 0.05  # Use 5% of RAM for memories
const DEFAULT_MIN_PER_AGENT := 1024  # Never go below 1K memories
const DEFAULT_MAX_PER_AGENT := 1048576  # Never exceed 1M memories (cap at ~300MB per agent)
const DEFAULT_AVG_MEMORY_SIZE := 300  # Bytes per memory entry with metadata


func _ready() -> void:
	"""Initialize singleton and calculate initial budget."""
	instance = self
	_calculate_memory_budget()
	print("[MemoryBudget] Initialized with %d memories per agent" % _cached_per_agent_limit)


func get_memory_limit_for_agent(_agent: WorldObject) -> int:
	"""Get the maximum number of memories this agent should store.

	Args:
		_agent: The WorldObject (currently unused, all agents get same limit)

	Returns:
		Maximum number of memories to retain in RAM

	Notes:
		Recalculates budget periodically to adapt to changing conditions.
		All agents currently share the same limit (future: per-agent budgets).
	"""
	var now := Time.get_ticks_msec()

	# Recalculate periodically or if agent count changed
	var current_agent_count := _count_agents_with_memory()
	if now - _last_budget_calculation > _recalc_interval_ms or current_agent_count != _cached_agent_count:
		_calculate_memory_budget()

	return _cached_per_agent_limit


func _calculate_memory_budget() -> void:
	"""Calculate per-agent memory limits based on system resources.

	Uses Performance.MEMORY_STATIC to estimate available memory,
	then divides budget among all agents with Memory components.
	"""
	_last_budget_calculation = Time.get_ticks_msec()
	_cached_agent_count = _count_agents_with_memory()

	# Get configuration from TextManager (explicit type casting)
	var percent_of_ram: float = TextManager.get_config("memory_budget.percent_of_ram", DEFAULT_PERCENT_OF_RAM)
	var min_per_agent: int = TextManager.get_config("memory_budget.min_per_agent", DEFAULT_MIN_PER_AGENT)
	var max_per_agent: int = TextManager.get_config("memory_budget.max_per_agent", DEFAULT_MAX_PER_AGENT)
	var avg_memory_size: int = TextManager.get_config("memory_budget.avg_memory_size", DEFAULT_AVG_MEMORY_SIZE)

	# Estimate total available RAM based on current usage
	# Performance.MEMORY_STATIC gives us current app memory usage in bytes
	var current_usage_bytes: float = Performance.get_monitor(Performance.MEMORY_STATIC)

	# Heuristic: assume current usage is ~20% of available RAM on a typical system
	# This is conservative but scales reasonably across different hardware
	var estimated_total_ram_bytes: float = current_usage_bytes * 5.0

	# Calculate budget for memories
	var memory_budget_bytes: float = estimated_total_ram_bytes * percent_of_ram

	# Divide among all agents
	var per_agent_bytes: float = memory_budget_bytes
	if _cached_agent_count > 0:
		per_agent_bytes = memory_budget_bytes / float(_cached_agent_count)

	# Convert bytes to number of memories
	var per_agent_memories: int = int(per_agent_bytes / float(avg_memory_size))

	# Clamp to configured min/max
	per_agent_memories = clampi(per_agent_memories, min_per_agent, max_per_agent)

	# Only log if the limit changed significantly (more than 10% change)
	var old_limit: int = _cached_per_agent_limit
	_cached_per_agent_limit = per_agent_memories

	var change_ratio: float = 0.0
	if old_limit > 0:
		change_ratio = abs(float(per_agent_memories - old_limit) / float(old_limit))

	# Log if significant change, or if this is the first calculation (old_limit == default)
	if old_limit == 65536 or change_ratio > 0.1:
		print("[MemoryBudget] %d agents → %d memories each (~%.1f MB total)" % [
			_cached_agent_count,
			per_agent_memories,
			(per_agent_memories * _cached_agent_count * avg_memory_size) / (1024.0 * 1024.0)
		])


func _count_agents_with_memory() -> int:
	"""Count how many WorldObjects have Memory components.

	Returns:
		Number of active agents with memory capability
	"""
	if not WorldKeeper:
		return 1  # Fallback: assume at least one agent

	var count := 0
	for obj in WorldKeeper.get_all_objects():
		if obj.has_component("memory"):
			count += 1

	return max(1, count)  # Always assume at least one agent


func get_budget_info() -> Dictionary:
	"""Get human-readable budget information for debugging.

	Returns:
		Dictionary with keys: per_agent_limit, agent_count, total_budget_mb
	"""
	var avg_memory_size: int = TextManager.get_config("memory_budget.avg_memory_size", DEFAULT_AVG_MEMORY_SIZE)

	return {
		"per_agent_limit": _cached_per_agent_limit,
		"agent_count": _cached_agent_count,
		"total_budget_mb": (_cached_per_agent_limit * _cached_agent_count * avg_memory_size) / (1024.0 * 1024.0),
		"per_agent_mb": (_cached_per_agent_limit * avg_memory_size) / (1024.0 * 1024.0)
	}
