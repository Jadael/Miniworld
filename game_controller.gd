## GameController: Interactive player interface for Miniworld
##
## This connects the console addon to the MOO-like world system,
## allowing the player to interact via text commands.

extends Node

## The player's WorldObject
var player: WorldObject

## Reference to the console (autoloaded as Console)
@onready var console = get_node("/root/Console")

func _ready() -> void:
	# Wait for World to initialize
	await get_tree().process_frame

	_setup_world()
	_setup_player()
	_register_commands()
	_show_welcome()

func _setup_world() -> void:
	"""Create the initial world"""
	# Create some starting locations
	var lobby = WorldKeeper.create_room("The Lobby",
		"A comfortable entrance hall with plush seating and warm lighting.")
	var lobby_loc = LocationComponent.new()
	lobby.add_component("location", lobby_loc)

	var garden = WorldKeeper.create_room("The Garden",
		"A peaceful garden filled with flowers and the sound of trickling water.")
	var garden_loc = LocationComponent.new()
	garden.add_component("location", garden_loc)

	var library = WorldKeeper.create_room("The Library",
		"Towering bookshelves line the walls, filled with ancient tomes and scrolls.")
	var library_loc = LocationComponent.new()
	library.add_component("location", library_loc)

	# Connect the rooms
	lobby_loc.add_exit("garden", garden)
	lobby_loc.add_exit("north", garden)
	lobby_loc.add_exit("library", library)
	lobby_loc.add_exit("east", library)

	garden_loc.add_exit("lobby", lobby)
	garden_loc.add_exit("south", lobby)

	library_loc.add_exit("lobby", lobby)
	library_loc.add_exit("west", lobby)

func _setup_player() -> void:
	"""Create the player character"""
	player = WorldKeeper.create_object("player", "You")

	# Add Actor component (can execute commands)
	var actor_comp = ActorComponent.new()
	player.add_component("actor", actor_comp)

	# Add Memory component (remembers events)
	var memory_comp = MemoryComponent.new()
	player.add_component("memory", memory_comp)

	# Place player in a random room (or the first one)
	var rooms = WorldKeeper.get_all_rooms()
	if rooms.size() > 0:
		player.move_to(rooms[0])

	# Connect to actor events to display results
	actor_comp.command_executed.connect(_on_command_executed)
	actor_comp.event_observed.connect(_on_event_observed)

func _register_commands() -> void:
	"""Register MOO commands with the console"""
	console.add_command("look", _cmd_look, 0, 0, "Look around your current location")
	console.add_command("l", _cmd_look, 0, 0, "Shortcut for 'look'")

	console.add_command("go", _cmd_go, ["exit name"], 1, "Move to another location")

	console.add_command("say", _cmd_say, ["message"], 1, "Say something to others in the room")
	console.add_command("\"", _cmd_say, ["message"], 1, "Shortcut for 'say'")

	console.add_command("emote", _cmd_emote, ["action"], 1, "Perform an emote/action")
	console.add_command(":", _cmd_emote, ["action"], 1, "Shortcut for 'emote'")

	console.add_command("examine", _cmd_examine, ["target"], 1, "Examine something or someone")
	console.add_command("ex", _cmd_examine, ["target"], 1, "Shortcut for 'examine'")

	console.add_command("who", _cmd_who, 0, 0, "List all characters in the world")
	console.add_command("where", _cmd_where, 0, 0, "Show your current location")
	console.add_command("rooms", _cmd_rooms, 0, 0, "List all rooms in the world")

	console.add_command("memories", _cmd_memories, 0, 0, "View your recent memories")
	console.add_command("notes", _cmd_notes, 0, 0, "View your notes")

func _show_welcome() -> void:
	"""Display welcome message and initial look"""
	console.print_line("[color=cyan]╔══════════════════════════════════════════╗[/color]")
	console.print_line("[color=cyan]║[/color]         [b]WELCOME TO MINIWORLD[/b]         [color=cyan]║[/color]")
	console.print_line("[color=cyan]║[/color]   A LambdaMOO-inspired world sim    [color=cyan]║[/color]")
	console.print_line("[color=cyan]╚══════════════════════════════════════════╝[/color]")
	console.print_line("")
	console.print_line("Type [color=light_green]help[/color] for console commands")
	console.print_line("Type [color=light_green]commands[/color] to see available game commands")
	console.print_line("")

	# Auto-look at starting location
	_cmd_look()

## Command implementations
func _cmd_look(_arg: String = "") -> void:
	var actor_comp = player.get_component("actor") as ActorComponent
	if actor_comp:
		actor_comp.execute_command("look")

func _cmd_go(exit_name: String) -> void:
	if exit_name.is_empty():
		console.print_error("Go where?")
		return

	var actor_comp = player.get_component("actor") as ActorComponent
	if actor_comp:
		actor_comp.execute_command("go", [exit_name])

func _cmd_say(message: String) -> void:
	if message.is_empty():
		console.print_error("Say what?")
		return

	var actor_comp = player.get_component("actor") as ActorComponent
	if actor_comp:
		# Split message into words for the command
		var words = message.split(" ")
		actor_comp.execute_command("say", words)

func _cmd_emote(action: String) -> void:
	if action.is_empty():
		console.print_error("Emote what?")
		return

	var actor_comp = player.get_component("actor") as ActorComponent
	if actor_comp:
		var words = action.split(" ")
		actor_comp.execute_command("emote", words)

func _cmd_examine(target: String) -> void:
	if target.is_empty():
		console.print_error("Examine what?")
		return

	var actor_comp = player.get_component("actor") as ActorComponent
	if actor_comp:
		actor_comp.execute_command("examine", [target])

func _cmd_who() -> void:
	"""List all actors in the world"""
	var actors = WorldKeeper.get_objects_with_component("actor")

	if actors.size() == 0:
		console.print_line("No one is here.")
		return

	console.print_line("[b]Who's online:[/b]")
	for actor in actors:
		var location = actor.get_location()
		var loc_name = location.name if location else "nowhere"
		console.print_line("  %s - %s" % [actor.name, loc_name])

func _cmd_where() -> void:
	"""Show current location"""
	var location = player.get_location()
	if location:
		console.print_line("You are in: [b]%s[/b]" % location.name)
	else:
		console.print_line("You are nowhere.")

func _cmd_rooms() -> void:
	"""List all rooms"""
	var rooms = WorldKeeper.get_all_rooms()

	if rooms.size() == 0:
		console.print_line("No rooms exist.")
		return

	console.print_line("[b]Rooms in the world:[/b]")
	for room in rooms:
		var loc_comp = room.get_component("location") as LocationComponent
		var exits = loc_comp.get_exits() if loc_comp else {}
		var exit_list = ", ".join(exits.keys()) if exits.size() > 0 else "none"
		console.print_line("  [b]%s[/b] - exits: %s" % [room.name, exit_list])

func _cmd_memories() -> void:
	"""View recent memories"""
	var memory_comp = player.get_component("memory") as MemoryComponent
	if memory_comp:
		var text = memory_comp.format_memories_as_text(10)
		console.print_line(text)
	else:
		console.print_line("You have no memory component.")

func _cmd_notes() -> void:
	"""View notes"""
	var memory_comp = player.get_component("memory") as MemoryComponent
	if memory_comp:
		var text = memory_comp.format_notes_as_text()
		console.print_line(text)
	else:
		console.print_line("You have no memory component.")

## Event handlers
func _on_command_executed(_command: String, result: Dictionary) -> void:
	"""Display command results"""
	if result.success:
		_format_output(result.message)
	else:
		console.print_error(result.message)

func _on_event_observed(event: Dictionary) -> void:
	"""Display observed events"""
	var text = EventWeaver.format_event(event)
	if text != "":
		console.print_line("[color=gray]" + text + "[/color]")

func _format_output(text: String) -> void:
	"""Format and display text with MOO-style coloring"""
	# Add some basic formatting for readability
	var formatted = text.replace("📍", "[color=yellow]")
	formatted = formatted.replace("👥", "[/color][color=light_blue]")
	formatted = formatted.replace("🔧", "[/color][color=gray]")

	# Ensure we close color tags
	formatted += "[/color]"

	console.print_line(formatted)
