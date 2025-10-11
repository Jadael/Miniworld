## GameController: Connects the MOO world to the game UI
##
## Handles player commands and updates the UI panels

extends Node

## The player's WorldObject
var player: WorldObject

## AI agents in the world
var ai_agents: Array[WorldObject] = []

## Reference to UI
var ui: Control

func _ready() -> void:
	# Wait for World to initialize
	await get_tree().process_frame

	# Get UI reference
	ui = get_node("GameUI")
	ui.command_submitted.connect(_on_command_submitted)

	_setup_world()
	_setup_player()
	_setup_ai_agents()
	_initial_look()

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

	# Add Actor component
	var actor_comp = ActorComponent.new()
	player.add_component("actor", actor_comp)

	# Add Memory component
	var memory_comp = MemoryComponent.new()
	player.add_component("memory", memory_comp)

	# Place player in first room
	var rooms = WorldKeeper.get_all_rooms()
	if rooms.size() > 0:
		player.move_to(rooms[0])

	# Connect to actor events
	actor_comp.command_executed.connect(_on_command_executed)
	actor_comp.event_observed.connect(_on_event_observed)

func _setup_ai_agents() -> void:
	"""Spawn AI agents in the world"""
	var rooms = WorldKeeper.get_all_rooms()

	# Spawn Eliza in the Garden (if it exists)
	var garden = null
	var library = null
	for room in rooms:
		if room.name == "The Garden":
			garden = room
		elif room.name == "The Library":
			library = room

	# Create Eliza in the Garden
	var eliza = AIAgent.create_eliza(garden if garden else WorldKeeper.root_room)
	ai_agents.append(eliza)

	# Create Moss in the Library
	var moss = AIAgent.create_moss(library if library else WorldKeeper.root_room)
	ai_agents.append(moss)

	# Connect AI agent events to UI
	for agent in ai_agents:
		if agent.has_component("actor"):
			var actor_comp = agent.get_component("actor") as ActorComponent
			actor_comp.command_executed.connect(_on_ai_command_executed)

func _on_ai_command_executed(_command: String, _result: Dictionary) -> void:
	"""Display AI agent actions"""
	# Update occupants list if player is in same location
	_update_location_display()

func _process(delta: float) -> void:
	"""Update AI agents each frame"""
	for agent in ai_agents:
		if agent.has_component("thinker"):
			var thinker_comp = agent.get_component("thinker") as ThinkerComponent
			thinker_comp.process(delta)

func _initial_look() -> void:
	"""Perform initial look command"""
	var actor_comp = player.get_component("actor") as ActorComponent
	if actor_comp:
		actor_comp.execute_command("look")

func _on_command_submitted(text: String) -> void:
	"""Process player command"""
	# Parse command and args
	var parts = text.split(" ", false, 1)
	var command = parts[0].to_lower()
	var args_string = parts[1] if parts.size() > 1 else ""

	# Handle shortcuts
	match command:
		"l":
			command = "look"
		"'", "\"":
			command = "say"
			# If shortcut was used without space, the rest is in command
			if text.begins_with("'") or text.begins_with("\""):
				args_string = text.substr(1).strip_edges()
		":":
			command = "emote"
			if text.begins_with(":"):
				args_string = text.substr(1).strip_edges()

	# Execute command
	var actor_comp = player.get_component("actor") as ActorComponent
	if not actor_comp:
		ui.add_error("You have no actor component!")
		return

	# Build args array
	var args: Array = []
	if not args_string.is_empty():
		args = args_string.split(" ", false)

	# Execute
	actor_comp.execute_command(command, args)

func _on_command_executed(_command: String, result: Dictionary) -> void:
	"""Handle command results"""
	if result.success:
		# Display success message
		var message = result.message as String

		# Remove emoji icons for cleaner UI
		message = message.replace("📍", "")
		message = message.replace("👥", "")
		message = message.replace("🔧", "")

		ui.add_event(message)

		# Update location panel if we have location data
		if result.has("location"):
			_update_location_display()
	else:
		ui.add_error(result.message)

func _on_event_observed(event: Dictionary) -> void:
	"""Display observed events"""
	var text = EventWeaver.format_event(event)
	if text != "":
		ui.add_event("[color=light_blue]" + text + "[/color]")

func _update_location_display() -> void:
	"""Update the location and occupants panels"""
	var location = player.get_location()
	if not location:
		return

	# Update location panel
	var loc_comp = location.get_component("location") as LocationComponent
	var exits: Array = []
	if loc_comp:
		exits.assign(loc_comp.get_exits().keys())

	ui.update_location(location.name, location.description, exits)

	# Update occupants panel
	var occupants: Array[String] = []
	for obj in location.get_contents():
		if obj != player and obj.has_component("actor"):
			occupants.append(obj.name)

	ui.update_occupants(occupants)
