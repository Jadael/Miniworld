## DemoWorld: Demonstration script for Miniworld MOO-like architecture
##
## This script creates a simple test world to showcase the core systems:
## - WorldObject creation and management
## - Component composition (Actor, Memory, Location)
## - Command execution and parsing
## - Event propagation between objects
## - Room navigation and connectivity
##
## The demo automatically creates a two-room world, spawns a player,
## and executes a series of test commands to demonstrate functionality.
##
## Dependencies:
## - WorldKeeper: Object registry and lifecycle manager
## - ActorComponent: Command execution capability
## - LocationComponent: Room navigation system
## - MemoryComponent: Experience storage
##
## Notes:
## - Press SPACE to restart the demo
## - Commands execute on a 1-second timer for readability

extends Node2D


## The player's WorldObject instance
var player: WorldObject

## The starting room WorldObject
var lobby: WorldObject

## The connected garden room WorldObject
var garden: WorldObject

func _ready() -> void:
	"""Initialize the demo world and run test sequence.

	Waits one frame for autoloads to initialize, then creates
	the world, player, and executes demonstration commands.
	"""
	# Give the world a moment to initialize
	await get_tree().process_frame

	_create_world()
	_create_player()
	_test_commands()


func _create_world() -> void:
	"""Create a simple world with two connected rooms.

	Constructs the Lobby and Garden rooms, adds LocationComponents
	to make them navigable, and creates bidirectional exits between them.
	"""
	print("\n=== Creating World ===")

	# Create the Lobby room
	lobby = WorldKeeper.create_room("The Lobby", "A comfortable entrance hall with plush seating and warm lighting.")
	print("Created: %s" % lobby)

	# Add location component to make it a proper room
	var lobby_location: LocationComponent = LocationComponent.new()
	lobby.add_component("location", lobby_location)

	# Create the Garden room
	garden = WorldKeeper.create_room("The Garden", "A peaceful garden filled with flowers and the sound of trickling water.")
	print("Created: %s" % garden)

	var garden_location: LocationComponent = LocationComponent.new()
	garden.add_component("location", garden_location)

	# Connect the rooms with bidirectional exits
	lobby_location.add_exit("garden", garden)
	lobby_location.add_exit("north", garden)

	garden_location.add_exit("lobby", lobby)
	garden_location.add_exit("south", lobby)

	print("Connected rooms with exits")

func _create_player() -> void:
	"""Create a player character with Actor and Memory components.

	Constructs a player WorldObject, adds Actor capability for command
	execution and Memory for storing experiences, then places the
	player in the lobby.
	"""
	print("\n=== Creating Player ===")

	player = WorldKeeper.create_object("player", "Wanderer")
	print("Created: %s" % player)

	# Add Actor component (can execute commands)
	var actor_comp: ActorComponent = ActorComponent.new()
	player.add_component("actor", actor_comp)

	# Add Memory component (can remember things)
	var memory_comp: MemoryComponent = MemoryComponent.new()
	player.add_component("memory", memory_comp)

	# Place player in the lobby
	player.move_to(lobby)
	print("Player moved to: %s" % lobby.name)

func _test_commands() -> void:
	"""Execute a sequence of test commands to demonstrate functionality.

	Runs through LOOK, SAY, GO, and EMOTE commands with 1-second delays
	between each. After completion, displays the player's accumulated
	memories, world statistics, and the object hierarchy tree.
	"""
	print("\n=== Testing Commands ===\n")

	await get_tree().create_timer(1.0).timeout

	var actor_comp: ActorComponent = player.get_component("actor") as ActorComponent

	# Test LOOK command
	print("Player executes: LOOK")
	var result: Dictionary = actor_comp.execute_command("look")
	print("Result: %s\n" % result.message)

	await get_tree().create_timer(1.0).timeout

	# Test SAY command
	print("Player executes: SAY Hello, world!")
	result = actor_comp.execute_command("say", ["Hello,", "world!"])
	print("Result: %s\n" % result.message)

	await get_tree().create_timer(1.0).timeout

	# Test GO command
	print("Player executes: GO garden")
	result = actor_comp.execute_command("go", ["garden"])
	print("Result: %s\n" % result.message)

	await get_tree().create_timer(1.0).timeout

	# Test EMOTE command
	print("Player executes: EMOTE waves at the flowers")
	result = actor_comp.execute_command("emote", ["waves", "at", "the", "flowers"])
	print("Result: %s\n" % result.message)

	await get_tree().create_timer(1.0).timeout

	# Display player's accumulated memories
	print("=== Player Memories ===")
	var memory_comp: MemoryComponent = player.get_component("memory") as MemoryComponent
	print(memory_comp.format_memories_as_text())

	# Display world statistics
	print("\n=== World Stats ===")
	print(WorldKeeper.get_stats())

	# Display object hierarchy tree
	print("\n=== World Tree ===")
	WorldKeeper.print_world_tree()

func _process(_delta: float) -> void:
	"""Handle input for demo restart.

	Monitors for SPACE key press to reload the scene and restart
	the demonstration from the beginning.

	Args:
		_delta: Time elapsed since previous frame (unused)
	"""
	# Press SPACE to run the demo again
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()
