# Default Text and Configuration Files

This directory contains the **default** text and configuration files for Miniworld.

## How it Works

On first run, these files are **automatically copied** to your user vault:
- Windows: `%APPDATA%\Godot\app_userdata\Miniworld\vault\`
- macOS: `~/Library/Application Support/Godot/app_userdata/Miniworld/vault/`
- Linux: `~/.local/share/godot/app_userdata/Miniworld/vault/`

Once copied, **you can edit the files in your user vault** using:
- Obsidian (recommended for markdown editing)
- Any text editor

## Customization

**Your customizations are safe!** The game will never overwrite your vault files. If you want to reset to defaults:
1. Delete the file from your user vault
2. Restart the game (it will copy the default back)

## Hot-Reloading

After editing text or config files, use the in-game command:
```
@reload-text
```

This reloads all text and configuration without restarting the game.

## File Structure

### Text Files (`vault/text/`)
- `commands/social.md` - Messages for look, say, emote, examine
- `commands/movement.md` - Messages for go command
- `commands/memory.md` - Messages for think, dream, note, recall
- `behaviors/actions.md` - Observable behavior templates (what others see)
- `defaults/world.md` - Default descriptions for objects and rooms

### Config Files (`vault/config/`)
- `ai_defaults.md` - AI agent settings (think interval, memory limits)
- `shoggoth.md` - LLM configuration (retries, model names)
- `memory_defaults.md` - Memory system settings

## Markdown Format

**Text files** use this format:
```markdown
## section_name
**key**: value with {variable} substitution
```

**Config files** use this format:
```markdown
**key**: value
_Optional description text_
```

Values are auto-typed (float, int, bool, or string).

## Variable Substitution

Text templates support variables in `{curly_braces}`:
- `{actor}` - Character name
- `{target}` - Target object/person name
- `{text}` - Message content
- `{exit}` - Exit/destination name
- `{origin}` - Where the actor came from

Example:
```markdown
**arrival**: {actor} arrives from {origin}.
```

Becomes: "Alice arrives from the garden."
