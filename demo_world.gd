## Demo script to test the Miniworld MOO-like architecture
##
## This creates a simple world with rooms and a player, demonstrating:
## - WorldObject creation
## - Component composition
## - Location/Actor/Memory systems
## - Command execution
## - Event propagation

extends Node2D

var player: WorldObject
var lobby: WorldObject
var garden: WorldObject

func _ready() -> void:
	# Give the world a moment to initialize
	await get_tree().process_frame

	_create_world()
	_create_player()
	_test_commands()

func _create_world() -> void:
	"""Create a simple world with two rooms"""
	print("\n=== Creating World ===")

	# Create the Lobby
	lobby = WorldKeeper.create_room("The Lobby", "A comfortable entrance hall with plush seating and warm lighting.")
	print("Created: %s" % lobby)

	# Add location component to make it a proper room
	var lobby_location = LocationComponent.new()
	lobby.add_component("location", lobby_location)

	# Create the Garden
	garden = WorldKeeper.create_room("The Garden", "A peaceful garden filled with flowers and the sound of trickling water.")
	print("Created: %s" % garden)

	var garden_location = LocationComponent.new()
	garden.add_component("location", garden_location)

	# Connect the rooms
	lobby_location.add_exit("garden", garden)
	lobby_location.add_exit("north", garden)

	garden_location.add_exit("lobby", lobby)
	garden_location.add_exit("south", lobby)

	print("Connected rooms with exits")

func _create_player() -> void:
	"""Create a player character"""
	print("\n=== Creating Player ===")

	player = WorldKeeper.create_object("player", "Wanderer")
	print("Created: %s" % player)

	# Add Actor component (can execute commands)
	var actor_comp = ActorComponent.new()
	player.add_component("actor", actor_comp)

	# Add Memory component (can remember things)
	var memory_comp = MemoryComponent.new()
	player.add_component("memory", memory_comp)

	# Place player in the lobby
	player.move_to(lobby)
	print("Player moved to: %s" % lobby.name)

func _test_commands() -> void:
	"""Test the command system"""
	print("\n=== Testing Commands ===\n")

	await get_tree().create_timer(1.0).timeout

	var actor_comp = player.get_component("actor") as ActorComponent

	# Test LOOK
	print("Player executes: LOOK")
	var result = actor_comp.execute_command("look")
	print("Result: %s\n" % result.message)

	await get_tree().create_timer(1.0).timeout

	# Test SAY
	print("Player executes: SAY Hello, world!")
	result = actor_comp.execute_command("say", ["Hello,", "world!"])
	print("Result: %s\n" % result.message)

	await get_tree().create_timer(1.0).timeout

	# Test GO
	print("Player executes: GO garden")
	result = actor_comp.execute_command("go", ["garden"])
	print("Result: %s\n" % result.message)

	await get_tree().create_timer(1.0).timeout

	# Test EMOTE
	print("Player executes: EMOTE waves at the flowers")
	result = actor_comp.execute_command("emote", ["waves", "at", "the", "flowers"])
	print("Result: %s\n" % result.message)

	await get_tree().create_timer(1.0).timeout

	# Check memories
	print("=== Player Memories ===")
	var memory_comp = player.get_component("memory") as MemoryComponent
	print(memory_comp.format_memories_as_text())

	print("\n=== World Stats ===")
	print(WorldKeeper.get_stats())

	print("\n=== World Tree ===")
	WorldKeeper.print_world_tree()

func _process(_delta: float) -> void:
	# Press SPACE to run the demo again
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()
