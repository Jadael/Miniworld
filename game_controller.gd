## GameController: Interactive player interface for Miniworld
##
## This script serves as the primary bridge between the player and the Miniworld
## MOO-like system. It manages:
## - Player character creation and initialization
## - Console command registration and routing
## - World setup (creating initial rooms and connections)
## - Displaying command results and observed events to the player
##
## The GameController integrates the Console addon (terminal UI) with the
## core Miniworld systems (WorldKeeper, EventWeaver, ActorComponent, etc.),
## translating text commands into world actions and presenting results back
## to the player in a formatted manner.
##
## Dependencies:
## - Console: The terminal UI autoload (addon)
## - WorldKeeper: Object registry and room management
## - EventWeaver: Event formatting system
## - ActorComponent: Command execution on WorldObjects
## - MemoryComponent: Observation and memory storage
## - LocationComponent: Room navigation system
##
## Notes:
## - Commands are registered with the Console addon's command system
## - The player's actor events are connected to display handlers
## - Initial world setup creates a small test environment (Lobby, Garden, Library)

extends Node


## The player's WorldObject representing the human player's character in the world.
## This WorldObject has ActorComponent and MemoryComponent attached.
var player: WorldObject

## Reference to the Console autoload (terminal UI addon).
## Used for registering commands and displaying output to the player.
@onready var console = get_node("/root/Console")


func _ready() -> void:
	"""Initialize the game controller and set up the world.

	This is called when the node enters the scene tree. It coordinates
	the setup sequence: world creation, player initialization, command
	registration, and welcome message display.

	Notes:
		Waits one frame to ensure all autoloads are fully initialized
		before attempting to interact with them.
	"""
	# Wait one frame to ensure all autoloads (WorldKeeper, EventWeaver, etc.)
	# are fully initialized before we start creating objects
	await get_tree().process_frame

	_setup_world()
	_setup_player()
	_register_commands()
	_show_welcome()

func _setup_world() -> void:
	"""Create the initial world with rooms and exits.

	Constructs a small test environment consisting of three connected rooms:
	- The Lobby (central hub)
	- The Garden (north of Lobby)
	- The Library (east of Lobby)

	Each room is created as a WorldObject and given a LocationComponent to
	enable navigation. Exits are bidirectional and support both direction
	names (north/south/east/west) and room names.

	Notes:
		This is a placeholder world for testing. In a full implementation,
		world data would likely be loaded from external files or a database.
	"""
	# Create the Lobby (central starting area)
	var lobby: WorldObject = WorldKeeper.create_room("The Lobby",
		"A comfortable entrance hall with plush seating and warm lighting.")
	var lobby_loc: LocationComponent = LocationComponent.new()
	lobby.add_component("location", lobby_loc)

	# Create the Garden (peaceful outdoor area)
	var garden: WorldObject = WorldKeeper.create_room("The Garden",
		"A peaceful garden filled with flowers and the sound of trickling water.")
	var garden_loc: LocationComponent = LocationComponent.new()
	garden.add_component("location", garden_loc)

	# Create the Library (indoor study area)
	var library: WorldObject = WorldKeeper.create_room("The Library",
		"Towering bookshelves line the walls, filled with ancient tomes and scrolls.")
	var library_loc: LocationComponent = LocationComponent.new()
	library.add_component("location", library_loc)

	# Connect Lobby to Garden (north/south)
	lobby_loc.add_exit("garden", garden)
	lobby_loc.add_exit("north", garden)

	# Connect Lobby to Library (east/west)
	lobby_loc.add_exit("library", library)
	lobby_loc.add_exit("east", library)

	# Connect Garden back to Lobby
	garden_loc.add_exit("lobby", lobby)
	garden_loc.add_exit("south", lobby)

	# Connect Library back to Lobby
	library_loc.add_exit("lobby", lobby)
	library_loc.add_exit("west", lobby)

func _setup_player() -> void:
	"""Create and initialize the player character.

	Creates a WorldObject to represent the player and attaches:
	- ActorComponent: Enables command execution
	- MemoryComponent: Stores observations and experiences

	The player is placed in the first available room and their actor
	events are connected to display handlers so command results and
	observed events appear in the console.

	Notes:
		Player is named "The Traveler" to avoid confusing LLMs with
		pronoun ambiguity (using "You" creates unclear references in prompts).
		If no rooms exist, the player will be created but locationless.
	"""
	# Create the player WorldObject with ID "player" and name "The Traveler"
	player = WorldKeeper.create_object("player", "The Traveler")

	# Add Actor component (enables command execution)
	var actor_comp: ActorComponent = ActorComponent.new()
	player.add_component("actor", actor_comp)

	# Add Memory component (stores observations and experiences)
	var memory_comp: MemoryComponent = MemoryComponent.new()
	player.add_component("memory", memory_comp)

	# Place player in the first available room
	var rooms: Array[WorldObject] = WorldKeeper.get_all_rooms()
	if rooms.size() > 0:
		player.move_to(rooms[0])

	# Connect actor signals to our display handlers
	# This ensures command results and observed events appear in the console
	actor_comp.command_executed.connect(_on_command_executed)
	actor_comp.event_observed.connect(_on_event_observed)

func _register_commands() -> void:
	"""Register all game commands with the Console addon.

	Registers MOO-style commands and their shortcuts with the Console's
	command system. Commands are routed to handler functions that interact
	with the player's ActorComponent or query WorldKeeper for information.

	Command categories:
	- Movement: look, go
	- Social: say, emote
	- Examination: examine
	- Information: who, where, rooms
	- Memory: memories, notes

	Notes:
		Console.add_command signature: (name, callable, min_args, max_args, description)
		Shortcuts like "l", "\"", and ":" provide familiar MOO-style aliases.
	"""
	# Movement commands
	console.add_command("look", _cmd_look, 0, 0, "Look around your current location")
	console.add_command("l", _cmd_look, 0, 0, "Shortcut for 'look'")
	console.add_command("go", _cmd_go, ["exit name"], 1, "Move to another location")

	# Social interaction commands
	console.add_command("say", _cmd_say, ["message"], 1, "Say something to others in the room")
	console.add_command("\"", _cmd_say, ["message"], 1, "Shortcut for 'say'")
	console.add_command("emote", _cmd_emote, ["action"], 1, "Perform an emote/action")
	console.add_command(":", _cmd_emote, ["action"], 1, "Shortcut for 'emote'")

	# Examination commands
	console.add_command("examine", _cmd_examine, ["target"], 1, "Examine something or someone")
	console.add_command("ex", _cmd_examine, ["target"], 1, "Shortcut for 'examine'")

	# Information commands
	console.add_command("who", _cmd_who, 0, 0, "List all characters in the world")
	console.add_command("where", _cmd_where, 0, 0, "Show your current location")
	console.add_command("rooms", _cmd_rooms, 0, 0, "List all rooms in the world")

	# Memory-related commands
	console.add_command("memories", _cmd_memories, 0, 0, "View your recent memories")
	console.add_command("notes", _cmd_notes, 0, 0, "View your notes")

func _show_welcome() -> void:
	"""Display the welcome banner and initial room description.

	Prints a formatted welcome message with instructions, then automatically
	executes a 'look' command to show the player's starting location.

	Notes:
		Uses BBCode color tags for formatting in the console.
		The 'help' command is provided by the Console addon.
		The 'commands' command lists all registered game commands.
	"""
	# Display welcome banner with box drawing characters
	console.print_line("[color=cyan]╔══════════════════════════════════════════╗[/color]")
	console.print_line("[color=cyan]║[/color]         [b]WELCOME TO MINIWORLD[/b]         [color=cyan]║[/color]")
	console.print_line("[color=cyan]║[/color]   A LambdaMOO-inspired world sim    [color=cyan]║[/color]")
	console.print_line("[color=cyan]╚══════════════════════════════════════════╝[/color]")
	console.print_line("")

	# Show help instructions
	console.print_line("Type [color=light_green]help[/color] for console commands")
	console.print_line("Type [color=light_green]commands[/color] to see available game commands")
	console.print_line("")

	# Automatically look at the starting location to orient the player
	_cmd_look()


## ============================================================================
## Command Implementations
## ============================================================================
## These functions are registered with the Console and handle player commands.
## Most delegate to the player's ActorComponent.execute_command() method.


func _cmd_look(_arg: String = "") -> void:
	"""Look around the current location.

	Executes the 'look' command through the player's ActorComponent,
	which describes the current room, its contents, and available exits.

	Args:
		_arg: Unused parameter (Console passes empty string for no-arg commands)

	Notes:
		The underscore prefix indicates the parameter is intentionally unused.
	"""
	var actor_comp: ActorComponent = player.get_component("actor") as ActorComponent
	if actor_comp:
		actor_comp.execute_command("look")

func _cmd_go(exit_name: String) -> void:
	"""Move through an exit to another location.

	Attempts to move the player through the specified exit in their
	current location. The exit name can be a direction (north, south, etc.)
	or a room name.

	Args:
		exit_name: The name of the exit to traverse

	Notes:
		Validates that exit_name is not empty before delegating to ActorComponent.
	"""
	# Validate that an exit name was provided
	if exit_name.is_empty():
		console.print_error("Go where?")
		return

	# Execute the 'go' command with the exit name as an argument
	var actor_comp: ActorComponent = player.get_component("actor") as ActorComponent
	if actor_comp:
		actor_comp.execute_command("go", [exit_name])

func _cmd_say(message: String) -> void:
	"""Say something aloud in the current location.

	Broadcasts a speech message to all characters in the current room.
	Other actors with observers will see this event.

	Args:
		message: The text to speak

	Notes:
		The message is split into words for the ActorComponent command system.
		Empty messages are rejected with an error.
	"""
	# Validate that a message was provided
	if message.is_empty():
		console.print_error("Say what?")
		return

	# Split message into words for the command system
	var actor_comp: ActorComponent = player.get_component("actor") as ActorComponent
	if actor_comp:
		var words: PackedStringArray = message.split(" ")
		actor_comp.execute_command("say", words)

func _cmd_emote(action: String) -> void:
	"""Perform an emote/action visible to others.

	Broadcasts a descriptive action to all characters in the current room.
	Emotes typically describe what the character is doing without speaking.

	Args:
		action: The action to perform (e.g., "waves hello" or "sits down")

	Notes:
		Like say, the action is split into words for the command system.
		Empty actions are rejected with an error.
	"""
	# Validate that an action was provided
	if action.is_empty():
		console.print_error("Emote what?")
		return

	# Split action into words for the command system
	var actor_comp: ActorComponent = player.get_component("actor") as ActorComponent
	if actor_comp:
		var words: PackedStringArray = action.split(" ")
		actor_comp.execute_command("emote", words)

func _cmd_examine(target: String) -> void:
	"""Examine an object, character, or feature in detail.

	Provides a detailed description of the specified target, if it exists
	and is visible to the player.

	Args:
		target: The name or identifier of the thing to examine

	Notes:
		Empty targets are rejected with an error.
		The examine command may be enhanced to support fuzzy matching.
	"""
	# Validate that a target was provided
	if target.is_empty():
		console.print_error("Examine what?")
		return

	# Execute the 'examine' command with the target as an argument
	var actor_comp: ActorComponent = player.get_component("actor") as ActorComponent
	if actor_comp:
		actor_comp.execute_command("examine", [target])

func _cmd_who() -> void:
	"""List all actors currently in the world.

	Queries WorldKeeper for all objects with ActorComponent and displays
	their names and current locations. This provides a "who's online" view
	of all active characters.

	Notes:
		This is a direct query command, not delegated to ActorComponent.
		If no actors exist, displays a message instead of an empty list.
	"""
	# Query WorldKeeper for all objects with the "actor" component
	var actors: Array[WorldObject] = WorldKeeper.get_objects_with_component("actor")

	# Handle empty case
	if actors.size() == 0:
		console.print_line("No one is here.")
		return

	# Display header and list all actors with their locations
	console.print_line("[b]Who's online:[/b]")
	for actor in actors:
		var location: WorldObject = actor.get_location()
		var loc_name: String = location.name if location else "nowhere"
		console.print_line("  %s - %s" % [actor.name, loc_name])

func _cmd_where() -> void:
	"""Show the player's current location.

	Displays the name of the room the player is currently in.
	This is a quick way to check your location without looking around.

	Notes:
		This is a direct query command, not delegated to ActorComponent.
		If the player is not in a room, displays "You are nowhere."
	"""
	# Get the player's current location from their WorldObject
	var location: WorldObject = player.get_location()

	# Display location name or nowhere message
	if location:
		console.print_line("You are in: [b]%s[/b]" % location.name)
	else:
		console.print_line("You are nowhere.")

func _cmd_rooms() -> void:
	"""List all rooms in the world with their exits.

	Queries WorldKeeper for all rooms and displays them with their
	available exits. Useful for getting an overview of the world geography.

	Notes:
		This is a direct query command, not delegated to ActorComponent.
		Rooms are identified by having a LocationComponent.
		If no rooms exist, displays a message instead of an empty list.
	"""
	# Query WorldKeeper for all rooms (objects with LocationComponent)
	var rooms: Array[WorldObject] = WorldKeeper.get_all_rooms()

	# Handle empty case
	if rooms.size() == 0:
		console.print_line("No rooms exist.")
		return

	# Display header and list all rooms with their exits
	console.print_line("[b]Rooms in the world:[/b]")
	for room in rooms:
		# Get the room's LocationComponent to access exits
		var loc_comp: LocationComponent = room.get_component("location") as LocationComponent
		var exits: Dictionary = loc_comp.get_exits() if loc_comp else {}

		# Format exit names as a comma-separated list
		var exit_list: String = ", ".join(exits.keys()) if exits.size() > 0 else "none"
		console.print_line("  [b]%s[/b] - exits: %s" % [room.name, exit_list])

func _cmd_memories() -> void:
	"""View the player's recent memories.

	Displays the last 10 memories stored in the player's MemoryComponent.
	Memories are observations of events that occurred in the world.

	Notes:
		This accesses the player's MemoryComponent directly rather than
		delegating to ActorComponent.
		If the player has no MemoryComponent, displays an error message.
	"""
	# Get the player's MemoryComponent
	var memory_comp: MemoryComponent = player.get_component("memory") as MemoryComponent

	if memory_comp:
		# Format and display the last 10 memories
		var text: String = memory_comp.format_memories_as_text(10)
		console.print_line(text)
	else:
		console.print_line("You have no memory component.")

func _cmd_notes() -> void:
	"""View the player's notes.

	Displays all notes stored in the player's MemoryComponent.
	Notes are persistent annotations that can be added by the player or AI.

	Notes:
		This accesses the player's MemoryComponent directly rather than
		delegating to ActorComponent.
		If the player has no MemoryComponent, displays an error message.
	"""
	# Get the player's MemoryComponent
	var memory_comp: MemoryComponent = player.get_component("memory") as MemoryComponent

	if memory_comp:
		# Format and display all notes
		var text: String = memory_comp.format_notes_as_text()
		console.print_line(text)
	else:
		console.print_line("You have no memory component.")


## ============================================================================
## Event Handlers
## ============================================================================
## These functions handle signals emitted by the player's ActorComponent.


func _on_command_executed(_command: String, result: Dictionary) -> void:
	"""Handle command execution results from the player's ActorComponent.

	Called when the player's ActorComponent finishes executing a command.
	Displays the result message in the console, with success messages
	formatted and error messages shown in red.

	Args:
		_command: The command name that was executed (intentionally unused)
		result: Dictionary containing:
			- success: Boolean indicating if command succeeded
			- message: String containing the result message

	Notes:
		The underscore prefix on _command indicates it's intentionally unused.
		Success messages are passed through _format_output for styling.
	"""
	if result.success:
		_format_output(result.message)
	else:
		console.print_error(result.message)

func _on_event_observed(event: Dictionary) -> void:
	"""Handle events observed by the player's ActorComponent.

	Called when the player observes an event in the world (e.g., another
	character speaking or performing an action). The event is formatted
	by EventWeaver and displayed in gray text to distinguish it from
	direct command results.

	Args:
		event: Dictionary containing event data structured by EventWeaver

	Notes:
		Events are only displayed if they produce non-empty text.
		Observed events appear in gray to differentiate them from actions.
	"""
	# Format the event using EventWeaver's formatting system
	var text: String = EventWeaver.format_event(event)

	# Only display if the event produced text
	if text != "":
		console.print_line("[color=gray]" + text + "[/color]")


## ============================================================================
## Utility Functions
## ============================================================================


func _format_output(text: String) -> void:
	"""Format and display text with MOO-style coloring.

	Applies basic emoji-to-color transformations for visual organization
	of command output. This provides a simple way to add visual hierarchy
	to room descriptions and other output.

	Args:
		text: The text to format and display

	Notes:
		Emoji replacements:
		- 📍 → yellow (location markers)
		- 👥 → light blue (people/actors)
		- 🔧 → gray (objects/details)
		All text receives a closing color tag to ensure proper formatting.
	"""
	# Replace emoji markers with BBCode color tags for visual hierarchy
	var formatted: String = text.replace("📍", "[color=yellow]")
	formatted = formatted.replace("👥", "[/color][color=light_blue]")
	formatted = formatted.replace("🔧", "[/color][color=gray]")

	# Ensure color tags are properly closed
	formatted += "[/color]"

	console.print_line(formatted)
