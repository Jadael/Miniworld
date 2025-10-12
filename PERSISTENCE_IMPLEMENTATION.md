# Persistence System Implementation Plan

## Current Status

### ✅ Completed
1. **MarkdownVault Daemon** (`Daemons/markdown_vault.gd`)
   - File I/O operations
   - YAML frontmatter parsing
   - Template system
   - Directory management
   - Registered as autoload

2. **WorldObject Serialization** (`Core/world_object.gd`)
   - `to_markdown()` - Serializes object to Obsidian-compatible markdown
   - `from_markdown()` - Deserializes markdown to object
   - Handles properties, flags, components list, contents list

3. **Vault Structure** (`VAULT_STRUCTURE.md`)
   - Documented directory layout
   - File format specifications
   - Obsidian integration guide

### 🚧 Current Status

**Phases 1-3 Complete!** The core persistence system is now functional:

- ✅ WorldKeeper saves/loads world to/from markdown vault
- ✅ LocationComponent serializes exits to markdown with JSON data
- ✅ MemoryComponent saves individual memory files to agent vault directories
- ✅ Game controller loads from vault on startup or creates default world

**What's Working:**
- World saves to `vault/world/locations/*.md` and `vault/world/objects/characters/*.md`
- Location exits are serialized as Component Data JSON blocks
- Agent memories are saved as individual timestamped markdown files
- On startup, game loads from vault if it exists, otherwise creates default world

**What's Left (Optional Enhancements):**
- Phase 4: Auto-save system (periodic saves every 5 minutes)
- Phase 5: Initial world creation improvements (better error handling)
- Phase 6: Testing checklist
- Phase 7: Documentation updates

### 🔄 Next Steps

## Phase 4: Auto-Save System (Optional Enhancement)

This phase is optional but recommended for production use.

## Implementation Summary

### Phase 1: WorldKeeper Markdown Integration (✅ COMPLETED)

**Implemented Methods:**

- `save_world_to_vault()` - Saves entire world to markdown vault
  - Saves all rooms to `vault/world/locations/<name>.md`
  - Saves all characters to `vault/world/objects/characters/<name>.md`
  - Creates `world_state.md` snapshot with location occupancy and character locations
  - Saves agent memories via MemoryComponent

- `load_world_from_vault()` - Loads world from markdown vault
  - Three-pass loading: locations, characters, then relationships
  - Restores components based on markdown metadata
  - Loads memories from vault for each character

- `_load_location_from_markdown()` - Creates location from markdown file
- `_load_character_from_markdown()` - Creates character from markdown file
- `_save_world_snapshot()` - Creates world_state.md snapshot
- `_restore_world_state()` - Restores relationships and resolves exits
- `_resolve_all_exits()` - Connects exit names to WorldObject references
- `_restore_location_exits()` - Parses JSON from Component Data section
- `_parse_markdown_sections()` - Helper for markdown section parsing
- `_clear_dynamic_objects()` - Clears all objects except nexus/root_room

**GameController Integration:**

- `_setup_world()` - Now checks for vault and loads if exists, or creates default
- `_create_default_world()` - Extracted world creation logic

### Phase 2: LocationComponent Persistence (✅ COMPLETED)

**Implemented Methods:**

- `parse_exits_from_markdown(markdown_body, room_by_name)` - Parses exits from Exits section

**Exit Format:**

Exits use a clean, human-readable pipe-delimited format:

```markdown
## Exits
- [[The Garden]] | north | garden
- [[The Library]] | east | library
```

**Benefits:**
- No hidden JSON - everything is visible and editable
- Groups all aliases for a destination on one line
- Uses Obsidian wiki-links `[[Target]]` for destinations
- Easy to parse with simple string operations
- Admin can manually edit exits in any text editor

**WorldObject Integration:**

- `to_markdown()` checks for LocationComponent and generates Exits section
- Groups exits by destination for cleaner output
- All aliases to the same room appear on one line

### Phase 3: MemoryComponent Persistence (✅ COMPLETED)

**Implemented Methods:**

- `save_memory_to_vault(owner_name, memory_text, memory_type)` - Saves individual memory as markdown file
- `load_memories_from_vault(owner_name, max_count)` - Loads recent memories from vault
- `save_all_memories_to_vault(owner_name)` - Saves all current memories
- `_parse_iso_timestamp(iso_string)` - Parses ISO 8601 timestamps

**Memory Files:**
- Saved to `vault/agents/<name>/memories/<timestamp>-<type>.md`
- YAML frontmatter with timestamp, type, and importance
- Individual files for each memory (enables Obsidian linking and viewing)

## Original Plan (For Reference)

### Phase 1: WorldKeeper Markdown Integration

Replace the current JSON-based persistence in `world_keeper.gd` with markdown vault persistence:

### Original Methods to Update:
- `save_world()` - Currently saves to JSON
- `load_world()` - Currently loads from JSON
- `_serialize_object()` - Replace with markdown vault calls
- `_deserialize_object()` - Replace with markdown loading

### Original Methods Planned:

```gdscript
func save_world_to_vault() -> bool:
	"""Save entire world to markdown vault.

	Creates/updates:
	- vault/world/locations/<name>.md for each room
	- vault/world/objects/characters/<name>.md for each character
	- vault/world/world_state.md for snapshot
	"""
	var success = true

	# Save all rooms
	for room in get_all_rooms():
		var filename = MarkdownVault.sanitize_filename(room.name) + ".md"
		var path = MarkdownVault.LOCATIONS_PATH + "/" + filename
		var content = room.to_markdown()
		if not MarkdownVault.write_file(path, content):
			success = false

	# Save all characters (objects with actor component)
	for obj in get_objects_with_component("actor"):
		var filename = MarkdownVault.sanitize_filename(obj.name) + ".md"
		var path = MarkdownVault.OBJECTS_PATH + "/characters/" + filename
		var content = obj.to_markdown()
		if not MarkdownVault.write_file(path, content):
			success = false

	# Create world state snapshot
	_save_world_snapshot()

	if success:
		world_saved.emit()

	return success

func load_world_from_vault() -> bool:
	"""Load world from markdown vault.

	Reads all markdown files and reconstructs the world.
	Two-pass loading:
	1. Create all objects
	2. Restore relationships (parents, locations)
	"""
	# Clear existing world (except nexus/root_room)
	_clear_dynamic_objects()

	# Pass 1: Load all location files
	var location_files = MarkdownVault.list_files(MarkdownVault.LOCATIONS_PATH, ".md")
	for filename in location_files:
		var path = MarkdownVault.LOCATIONS_PATH + "/" + filename
		var content = MarkdownVault.read_file(path)
		_load_location_from_markdown(content)

	# Pass 2: Load all character files
	var char_files = MarkdownVault.list_files(MarkdownVault.OBJECTS_PATH + "/characters", ".md")
	for filename in char_files:
		var path = MarkdownVault.OBJECTS_PATH + "/characters/" + filename
		var content = MarkdownVault.read_file(path)
		_load_character_from_markdown(content)

	# Pass 3: Restore relationships from world_state.md
	_restore_world_state()

	world_loaded.emit()
	return true

func _load_location_from_markdown(content: String) -> WorldObject:
	"""Create a location from markdown file."""
	var room = create_object("room", "temp")
	room.from_markdown(content)
	room.set_flag("is_room", true)
	room.move_to(nexus)

	# Add LocationComponent if specified
	var parsed = MarkdownVault.parse_frontmatter(content)
	if "## Components" in parsed.body and "location" in parsed.body:
		var loc_comp = LocationComponent.new()
		room.add_component("location", loc_comp)

	return room

func _load_character_from_markdown(content: String) -> WorldObject:
	"""Create a character from markdown file."""
	var char = create_object("character", "temp")
	char.from_markdown(content)

	# Restore components based on Components section
	var parsed = MarkdownVault.parse_frontmatter(content)
	if "## Components" in parsed.body:
		if "actor" in parsed.body:
			char.add_component("actor", ActorComponent.new())
		if "thinker" in parsed.body:
			char.add_component("thinker", ThinkerComponent.new())
		if "memory" in parsed.body:
			char.add_component("memory", MemoryComponent.new())

	return char
```

## Phase 2: LocationComponent Markdown Integration

Add persistence methods to `Core/components/location.gd`:

```gdscript
func to_dict() -> Dictionary:
	"""Serialize LocationComponent data for markdown.

	Returns dictionary with:
	- exits: {exit_name: target_room_name}
	"""
	var exits_data = {}
	for exit_name in exits.keys():
		var target = exits[exit_name]
		exits_data[exit_name] = target.name if target else "nowhere"

	return {"exits": exits_data}

func from_dict(data: Dictionary) -> void:
	"""Restore LocationComponent from serialized data.

	Note: Actual WorldObject connections must be restored
	by WorldKeeper after all objects are loaded.
	"""
	# Store exit names for later resolution
	if data.has("exits"):
		for exit_name in data.exits.keys():
			# Will be connected in WorldKeeper's second pass
			pass
```

## Phase 3: MemoryComponent Markdown Integration

Update `Core/components/memory.gd` to save memories as individual markdown files:

```gdscript
func save_memory_to_vault(owner_name: String, memory_text: String, memory_type: String) -> void:
	"""Save a memory as a markdown file in the agent's vault.

	Args:
		owner_name: Name of the agent (for directory path)
		memory_text: The memory content
		memory_type: "observed", "action", or "response"
	"""
	var timestamp = MarkdownVault.get_filename_timestamp()
	var filename = "%s-%s.md" % [timestamp, memory_type]
	var agent_path = MarkdownVault.AGENTS_PATH + "/" + MarkdownVault.sanitize_filename(owner_name)
	var mem_path = agent_path + "/memories/" + filename

	# Create frontmatter
	var frontmatter = {
		"timestamp": MarkdownVault.get_timestamp(),
		"type": memory_type,
		"importance": 5  # Default importance
	}

	var content = MarkdownVault.create_frontmatter(frontmatter)
	content += "# Memory\n\n"
	content += memory_text

	MarkdownVault.write_file(mem_path, content)

func load_memories_from_vault(owner_name: String, max_count: int = 50) -> Array:
	"""Load recent memories from the vault."""
	var agent_path = MarkdownVault.AGENTS_PATH + "/" + MarkdownVault.sanitize_filename(owner_name)
	var mem_path = agent_path + "/memories"

	var files = MarkdownVault.list_files(mem_path, ".md")
	files.sort()  # Sort by timestamp (filename)
	files.reverse()  # Most recent first

	var memories = []
	for i in range(min(max_count, files.size())):
		var content = MarkdownVault.read_file(mem_path + "/" + files[i])
		var parsed = MarkdownVault.parse_frontmatter(content)

		memories.append({
			"content": parsed.body.strip_edges(),
			"type": parsed.frontmatter.get("type", "unknown"),
			"timestamp": parsed.frontmatter.get("timestamp", "")
		})

	return memories
```

## Phase 4: Auto-Save System

Add automatic vault saving to `WorldKeeper`:

```gdscript
var auto_save_enabled: bool = true
var auto_save_interval: float = 300.0  # 5 minutes
var time_since_save: float = 0.0

func _process(delta: float) -> void:
	"""Process auto-save timer."""
	if not auto_save_enabled:
		return

	time_since_save += delta

	if time_since_save >= auto_save_interval:
		save_world_to_vault()
		time_since_save = 0.0
```

## Phase 5: Initial World Creation

Update `game_controller_ui.gd` to create locations from vault or defaults:

```gdscript
func _setup_world() -> void:
	"""Setup world from vault or create defaults."""
	# Try to load from vault
	if MarkdownVault.list_files(MarkdownVault.LOCATIONS_PATH, ".md").size() > 0:
		WorldKeeper.load_world_from_vault()
	else:
		# Create default world and save to vault
		_create_default_world()
		WorldKeeper.save_world_to_vault()

func _create_default_world() -> void:
	"""Create the default 3-room world."""
	# Same as current _setup_world, but saves to vault afterward
	# ...
```

## Phase 6: Testing Checklist

- [ ] Create a new world, verify markdown files generated
- [ ] Modify a location in Obsidian, reload, verify changes appear in game
- [ ] Create an AI agent, verify agent.md and memories/ created
- [ ] Agent performs action, verify memory file created
- [ ] Restart game, verify world persists
- [ ] Check vault in Obsidian for graph view of world

## Phase 7: Documentation Updates

Update these files:
- [ ] README.md - Add vault location and Obsidian integration
- [ ] BUILDING.md - Add instructions for world building via markdown
- [ ] AGENTS.md - Document agent memory vault structure

## Benefits Once Complete

1. **Admin Can Use Obsidian**
   - Graph view shows all connections between locations
   - Search finds any character, memory, or event
   - Edit world structure with text editor

2. **Git-Friendly**
   - Every change creates a diff
   - Easy to track world evolution
   - Can branch/merge worlds

3. **Hackable**
   - Players (with permissions) can edit their character markdown
   - Eventually: In-game markdown editor
   - Future: Embedded MOO-style scripting in markdown

4. **Transparent**
   - No hidden database
   - Everything is human-readable
   - Easy to debug and inspect

## Migration Path

For users with existing JSON saves:

```gdscript
func migrate_json_to_vault(json_path: String) -> bool:
	"""One-time migration from JSON to markdown vault."""
	if load_world(json_path):  # Load old JSON format
		return save_world_to_vault()  # Save as markdown
	return false
```
