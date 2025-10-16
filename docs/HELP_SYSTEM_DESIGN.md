# Auto-Discovering Help System Design

## Vision

A help system that **automatically discovers and documents commands** by reflecting on the ActorComponent's methods. As we add new commands, they automatically appear in help with their docstring documentation.

## Core Principles

1. **Self-Documenting** - Docstrings ARE the documentation
2. **Auto-Discovery** - No manual command registry to maintain
3. **Always Up-to-Date** - Help reflects actual available commands
4. **Categorized** - Commands organized by purpose
5. **Context-Aware** - Show different help based on who's asking

---

## Commands

### `help` or `?`
Show overview of command categories and how to get detailed help.

### `help <command>` or `? <command>`
Show detailed help for a specific command, extracted from its docstring.

### `help <category>`
Show all commands in a category (social, building, admin, etc.)

### `commands`
List all available commands in compact format.

---

## Implementation: Reflection-Based Discovery

### Method Naming Convention

All command handler methods follow the pattern: `_cmd_<command_name>`

Examples:
- `_cmd_look()` → command: `look`
- `_cmd_say()` → command: `say`
- `_cmd_edit_profile()` → command: `@edit-profile`

### Automatic Discovery

```gdscript
func _discover_commands() -> Dictionary:
    """Scan ActorComponent for all _cmd_* methods and extract their info"""
    var commands: Dictionary = {}

    # Get all methods on ActorComponent
    var method_list = get_method_list()

    for method_info in method_list:
        var method_name: String = method_info.name

        # Find command handler methods
        if method_name.begins_with("_cmd_"):
            var command_name = _extract_command_name(method_name)
            var command_info = _extract_command_info(method_name)
            commands[command_name] = command_info

    return commands
```

### Docstring Parsing

We already have excellent docstrings! Let's parse them:

```gdscript
func _extract_command_info(method_name: String) -> Dictionary:
    """Extract command info from method docstring"""

    # Get method's source code (GDScript limitation: need workaround)
    # For now, use manual annotations in docstrings

    var info = {
        "name": "",
        "aliases": [],
        "syntax": "",
        "description": "",
        "category": "general",
        "examples": [],
        "admin_only": false
    }

    # Parse docstring format:
    # """COMMAND_NAME command - Short description
    #
    # Longer description...
    #
    # Syntax: command args
    #
    # Category: social|building|admin|query|self
    # """

    return info
```

### Docstring Annotation Format

Let's add structured comments to our command docstrings:

```gdscript
func _cmd_say(args: Array) -> Dictionary:
    """SAY command - Speak aloud to others in the location.

    @category social
    @syntax say <message>
    @alias ' (apostrophe shortcut)
    @example say Hello everyone!
    @example ' Hi there!

    Broadcasts speech event to all actors in the current location.
    """
```

### Category System

Commands are automatically categorized:

- **social**: say, emote, examine, look
- **movement**: go
- **memory**: note, recall, dream, think
- **building**: @dig, @exit, @teleport
- **admin**: @save, @impersonate, @edit-profile, @edit-interval
- **self**: @my-profile, @my-description, @set-profile, @set-description
- **query**: who, where, rooms, commands, help

---

## Implementation Plan

### Step 1: Add Help Command Handler

```gdscript
# In actor.gd execute_command() match block:
"help", "?":
    result = _cmd_help(args)
"commands":
    result = _cmd_commands(args)
```

### Step 2: Implement Command Discovery

```gdscript
# Cache discovered commands (updated when ActorComponent loads)
static var _command_registry: Dictionary = {}

func _ready() -> void:
    if _command_registry.is_empty():
        _discover_and_register_commands()

func _discover_and_register_commands() -> void:
    """Build command registry from method inspection"""

    # Manually register commands with metadata for now
    # (GDScript reflection is limited, can't easily read source)

    _register_command("look", {
        "aliases": ["l"],
        "category": "social",
        "syntax": "look",
        "description": "Observe your current location",
        "admin": false
    })

    _register_command("say", {
        "aliases": ["'"],
        "category": "social",
        "syntax": "say <message>",
        "description": "Speak aloud to others",
        "example": "say Hello everyone!",
        "admin": false
    })

    # ... register all commands
```

### Step 3: Implement Help Command

```gdscript
func _cmd_help(args: Array) -> Dictionary:
    """HELP command - Get help on commands

    @category query
    @syntax help [command|category]
    @alias ?
    @example help
    @example help say
    @example help social
    """

    if args.size() == 0:
        return _show_help_overview()

    var query = args[0].to_lower()

    # Check if query is a category
    if _is_category(query):
        return _show_category_help(query)

    # Check if query is a command
    if _command_registry.has(query):
        return _show_command_help(query)

    # Try aliases
    var command = _resolve_alias(query)
    if command != "":
        return _show_command_help(command)

    return {
        "success": false,
        "message": "Unknown command or category: %s\nTry 'help' for an overview." % query
    }
```

### Step 4: Format Help Output

```gdscript
func _show_help_overview() -> Dictionary:
    """Show general help overview"""
    var text = "═══ Miniworld Help ═══\n\n"

    text += "Available command categories:\n"
    text += "  • social - Interact with others (say, emote, examine)\n"
    text += "  • movement - Navigate the world (go)\n"
    text += "  • memory - Personal notes and recall (note, recall, dream)\n"
    text += "  • self - Self-awareness and modification (@my-profile, @set-profile)\n"
    text += "  • building - Create rooms and exits (@dig, @exit, @teleport)\n"
    text += "  • admin - Administrative commands (@save, @edit-profile)\n"
    text += "  • query - Get information (who, where, rooms, commands)\n\n"

    text += "Usage:\n"
    text += "  help <command>  - Detailed help on a specific command\n"
    text += "  help <category> - List all commands in a category\n"
    text += "  commands        - List all available commands\n"
    text += "  ? <command>     - Shortcut for help\n"

    return {"success": true, "message": text}

func _show_command_help(command: String) -> Dictionary:
    """Show detailed help for a command"""
    var cmd_info = _command_registry[command]

    var text = "═══ %s ═══\n\n" % command.to_upper()
    text += "%s\n\n" % cmd_info.description

    if cmd_info.has("syntax"):
        text += "Syntax: %s\n" % cmd_info.syntax

    if cmd_info.has("aliases") and cmd_info.aliases.size() > 0:
        text += "Aliases: %s\n" % ", ".join(cmd_info.aliases)

    if cmd_info.has("example"):
        text += "\nExample:\n  %s\n" % cmd_info.example

    if cmd_info.has("admin") and cmd_info.admin:
        text += "\n[Admin Command]\n"

    text += "\nCategory: %s\n" % cmd_info.category

    return {"success": true, "message": text}

func _show_category_help(category: String) -> Dictionary:
    """Show all commands in a category"""
    var text = "═══ %s Commands ═══\n\n" % category.capitalize()

    for cmd_name in _command_registry.keys():
        var cmd_info = _command_registry[cmd_name]
        if cmd_info.category == category:
            text += "  %-20s %s\n" % [cmd_name, cmd_info.description]

    text += "\nUse 'help <command>' for detailed information.\n"

    return {"success": true, "message": text}
```

### Step 5: Commands List

```gdscript
func _cmd_commands(_args: Array) -> Dictionary:
    """COMMANDS command - List all available commands

    @category query
    @syntax commands
    """
    var text = "Available Commands:\n\n"

    # Group by category
    var categories = ["social", "movement", "memory", "self", "building", "admin", "query"]

    for category in categories:
        var cmds = []
        for cmd_name in _command_registry.keys():
            if _command_registry[cmd_name].category == category:
                cmds.append(cmd_name)

        if cmds.size() > 0:
            text += "%s: %s\n" % [category.capitalize(), ", ".join(cmds)]

    text += "\nUse 'help <command>' for details on any command.\n"

    return {"success": true, "message": text}
```

---

## Phase 2: True Auto-Discovery

### Using GDScript Reflection (Limited)

GDScript can't easily read source code, but we can:

1. **Method List**: `get_method_list()` returns all methods
2. **Property List**: `get_property_list()` returns properties
3. **Script Annotations**: Use `@export` for metadata

### Script Annotations Approach

```gdscript
@command_info({
    "category": "social",
    "syntax": "say <message>",
    "description": "Speak aloud to others"
})
func _cmd_say(args: Array) -> Dictionary:
    # Implementation...
```

**Problem**: GDScript doesn't support custom annotations yet.

### Metadata Registry Approach (Current Best)

Create a separate metadata file that mirrors commands:

```gdscript
# Core/command_metadata.gd
const COMMAND_INFO = {
    "look": {
        "aliases": ["l"],
        "category": "social",
        "syntax": "look",
        "description": "Observe your current location"
    },
    "say": {
        "aliases": ["'"],
        "category": "social",
        "syntax": "say <message>",
        "description": "Speak aloud to others"
    },
    # ... etc
}
```

Then:
```gdscript
func _discover_and_register_commands() -> void:
    for cmd_name in CommandMetadata.COMMAND_INFO:
        _command_registry[cmd_name] = CommandMetadata.COMMAND_INFO[cmd_name]
```

---

## Future: Vault-Based Help

Store help text as markdown in vault:

```
vault/
  help/
    commands/
      say.md
      look.md
      @my-profile.md
    categories/
      social.md
      building.md
```

Load dynamically:
```gdscript
func _load_command_help(command: String) -> String:
    var help_path = "help/commands/%s.md" % command
    return MarkdownVault.read_file(help_path)
```

**Benefits**:
- Help text is editable without code changes
- Can be customized per-world
- Version controlled with world data
- Players/admins can improve documentation

---

## Success Criteria

✅ Type `help` - get overview of categories
✅ Type `help say` - get detailed info on say command
✅ Type `help social` - list all social commands
✅ Type `commands` - compact list of all commands
✅ Type `?` - alias for help works
✅ New commands automatically appear in help
✅ AI agents have help in their command list

---

## Implementation Priority

### MVP (Today)
- [ ] Add help and commands to match block
- [ ] Create command metadata registry
- [ ] Implement _cmd_help() with all formats
- [ ] Implement _cmd_commands()
- [ ] Test all help queries

### Phase 2 (Later)
- [ ] Move metadata to separate file
- [ ] Add more detailed examples
- [ ] Add @help annotation support
- [ ] Vault-based help text

---

## AI Agent Help Usage

Add to default command list:
```gdscript
"help or ?: Get help on commands (try 'help social' or 'help say')",
"commands: List all available commands",
```

Agents can then use:
```
> help @set-profile
> help memory
> commands
```

This enables agents to **discover their own capabilities**!

