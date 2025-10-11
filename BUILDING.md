# World Building Guide

Miniworld gives players full control to build and shape the world using MOO-style commands.

## Overview

All players can:
- Create new rooms
- Connect rooms with exits
- Teleport anywhere
- View the world structure

This creates a collaborative, player-built world similar to classic MOOs like LambdaMOO.

---

## Commands

### `rooms` - List All Rooms

View all rooms in the world with their IDs and occupants.

```
> rooms

Rooms in the World

• The Lobby [#1] (You, Moss)
• The Garden [#2] (Eliza)
• The Library [#3] (empty)
```

Each room shows:
- Name
- Object ID in brackets
- Current occupants (or "empty")

---

### `@dig <name>` - Create a Room

Create a new room with the given name.

```
> @dig The Café

Created room: The Café [#7]
Use @exit to connect it to other rooms.
```

The new room is created but not connected to anything yet. Use `@exit` to make it accessible.

**Tips:**
- Room names can contain spaces
- New rooms start with a default description: "A newly created room."
- Room IDs are assigned automatically (#1, #2, #3, etc.)

---

### `@exit <name> to <destination>` - Create an Exit

Connect the current room to another room with a named exit.

**By Room Name:**
```
> @exit door to The Café

Created exit: door → The Café [#7]
```

**By Room ID:**
```
> @exit north to #4

Created exit: north → The Garden [#4]
```

**Common Exit Names:**
- Cardinal directions: `north`, `south`, `east`, `west`
- Vertical: `up`, `down`
- Descriptive: `door`, `stairs`, `hallway`, `portal`
- Themed: `forest`, `cave`, `teleporter`

**Important:**
- Exits are **one-way** by default
- To make two-way connections, create exits in both rooms
- Multiple exits can lead to the same destination

**Example - Two-Way Connection:**
```
# In The Lobby
> @exit garden to The Garden

# Go to The Garden
> go garden

# Create return exit
> @exit lobby to The Lobby
```

---

### `@teleport <destination>` - Jump to Any Room

Instantly move to any room by name or ID. Shortcut: `@tp`

**By Name:**
```
> @teleport The Library

You vanishes in a swirl of light.

The Library
Towering bookshelves line the walls...
```

**By ID:**
```
> @tp #2

You appears in a swirl of light.
```

**Uses:**
- Quick navigation during building
- Visiting disconnected rooms
- Recovering from being stuck
- Dramatic entrances! ✨

---

### `who` - List All Characters

See everyone in the world and where they are.

```
> who

Who's Online

• You - in The Lobby
• Eliza [AI] - in The Garden
• Moss [AI] - in The Library
```

Shows:
- Character names
- `[AI]` tag for AI agents
- Current location

---

### `where` - Show Current Location

Display your current room name and ID.

```
> where

You are in The Lobby (#1)
```

Useful for:
- Confirming your location
- Getting the room ID for @exit commands
- Orientation after teleporting

---

## Building Workflow

### Creating a New Area

**1. Plan Your Space**
```
# Decide what rooms you want
# Example: A park with three areas
```

**2. Dig the Rooms**
```
> @dig Central Park
> @dig Rose Garden
> @dig Duck Pond
```

**3. List Rooms to Get IDs**
```
> rooms

Rooms in the World
• Central Park [#5] (empty)
• Rose Garden [#6] (empty)
• Duck Pond [#7] (empty)
```

**4. Connect from Existing Space**
```
# Go to where you want the entrance
> go lobby

# Create entrance to your new area
> @exit park to Central Park
```

**5. Connect Internal Rooms**
```
> @tp Central Park

# Connect to sub-areas
> @exit roses to Rose Garden
> @exit pond to Duck Pond

# Create returns
> @tp Rose Garden
> @exit back to Central Park

> @tp Duck Pond
> @exit back to Central Park
```

**6. Test Navigation**
```
> @tp lobby
> go park
> go roses
> go back
> go pond
```

---

## Advanced Patterns

### Hub-and-Spoke Layout
```
        [Room A]
           |
    [Room B] - [HUB] - [Room C]
           |
        [Room D]
```

Central hub with exits to multiple rooms, each with a return.

### Linear Path
```
[Start] -> [Room 1] -> [Room 2] -> [End]
        <-          <-          <-
```

Two-way connections form a path.

### Loop
```
    [A] -> [B]
     ^      |
     |      v
    [D] <- [C]
```

Circular navigation pattern.

### Portal Network
```
[Hub] has teleporter exits to distant rooms
Each remote room has return teleporter to Hub
```

### Maze
```
Complex interconnections where multiple exits
lead to the same or unexpected destinations
```

---

## Best Practices

### Exit Naming
- **Be consistent:** If you use "north" in one room, use "south" for the return
- **Be descriptive:** "secret door" is more interesting than "exit1"
- **Match theme:** Fantasy world? Use "portal". Sci-fi? Use "airlock"

### Room Design
- Create rooms with purpose (not just empty boxes)
- Think about traffic flow (where will people naturally go?)
- Add variety (mix open hubs with cozy alcoves)

### World Coherence
- Connected spaces should make spatial sense
- If Room A is "north" of Room B, Room B should be "south" of Room A
- Consider how the map would look if drawn out

### Collaborative Building
- Check `rooms` before naming to avoid duplicates
- Use `who` to see where others are building
- Communicate about shared spaces

---

## Room IDs

Every object in Miniworld has a unique ID:
- Format: `#1`, `#2`, `#3`, etc.
- Assigned automatically when created
- Never changes (permanent reference)
- `#0` is The Nexus (root container)
- `#1` is usually the first room created

**Why Use IDs?**
- Unambiguous (no confusion with similar names)
- Works even if room is renamed
- Required for some advanced features

**Finding IDs:**
- Use `rooms` command
- Use `where` command (shows your current room's ID)

---

## Common Scenarios

### "I Created a Room but Can't Get There"

You need to create an exit!

```
# Where are you now?
> where
You are in The Lobby (#1)

# Connect to your new room
> @exit doorway to My New Room
```

### "How Do I Make a Two-Way Connection?"

Create exits in both directions:

```
# From Room A
> @exit east to Room B

# Move to Room B
> go east

# Create return
> @exit west to Room A
```

### "Can Multiple Exits Go to the Same Place?"

Yes! This is useful for:
- Different descriptions of same destination ("door" and "exit" both lead out)
- Alternate paths to important locations
- Thematic variety ("portal" and "stairs" lead to Tower)

### "How Do I Find a Room's ID?"

Two ways:
1. Use `rooms` (lists all rooms with IDs)
2. Go to the room and use `where`

### "What If I Misname a Room?"

Currently, room renaming isn't implemented. But you can:
- Create a new room with correct name
- Use `@exit` to redirect exits to the new room
- The old room becomes abandoned (harmless)

---

## Future Building Features

Coming eventually:
- `@describe <object>` - Change room descriptions
- `@rename <object>` - Rename rooms
- `@delete <object>` - Remove rooms/exits
- `@create <object>` - Create interactive objects
- In-game scripting for custom behaviors
- Permission system (private vs public rooms)
- Room properties (dark, quiet, no-teleport, etc.)

---

## Philosophy

Miniworld follows the **LambdaMOO tradition** where:
- The world is shaped by its inhabitants
- Everyone can contribute to the shared space
- Building is a form of creative expression
- Exploration rewards curiosity

Unlike traditional games with fixed maps, Miniworld's geography is **emergent** - it grows organically as players create what they need.

Build what you want to see in the world! 🏗️
