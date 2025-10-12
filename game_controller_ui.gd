## GameControllerUI: Connects the MOO world to the game UI
##
## Acts as the bridge between the Miniworld backend systems and the
## player-facing UI. Responsibilities include:
## - Creating and initializing the game world
## - Managing the player WorldObject and AI agents
## - Processing player commands from UI input
## - Updating UI panels with game state
## - Routing events between systems and UI
##
## This controller initializes a three-room world (Lobby, Garden, Library)
## and spawns two AI agents (Eliza and Moss) as demonstration NPCs.
##
## Dependencies:
## - WorldKeeper: Object registry and world state
## - ActorComponent: Command execution for player and NPCs
## - LocationComponent: Room navigation system
## - AIAgent: Factory for creating AI-driven characters
## - GameUI: Visual interface for player interaction
##
## Notes:
## - Processes AI agent thinker components each frame
## - Filters emojis from command results for cleaner UI display

extends Node


## The player's WorldObject instance
var player: WorldObject

## Array of AI agent WorldObjects in the world
var ai_agents: Array[WorldObject] = []

## Reference to the GameUI Control node
var ui: Control

func _ready() -> void:
	"""Initialize the game controller and world.

	Waits one frame for autoloads, then connects to the UI,
	creates the world and player, spawns AI agents, and performs
	the initial look command.
	"""
	# Wait for World to initialize
	await get_tree().process_frame

	# Get UI reference and connect to command signal
	ui = get_node("GameUI")
	ui.command_submitted.connect(_on_command_submitted)

	_setup_world()
	_setup_player()
	_setup_ai_agents()
	_initial_look()

func _setup_world() -> void:
	"""Create the initial three-room world with connected exits.

	Constructs Lobby, Garden, and Library rooms, adds LocationComponents
	to each, and creates navigable exits:
	- Lobby: north/garden to Garden, east/library to Library
	- Garden: south/lobby back to Lobby
	- Library: west/lobby back to Lobby
	"""
	# Create Lobby room
	var lobby: WorldObject = WorldKeeper.create_room("The Lobby",
		"A comfortable entrance hall with plush seating and warm lighting.")
	var lobby_loc: LocationComponent = LocationComponent.new()
	lobby.add_component("location", lobby_loc)

	# Create Garden room
	var garden: WorldObject = WorldKeeper.create_room("The Garden",
		"A peaceful garden filled with flowers and the sound of trickling water.")
	var garden_loc: LocationComponent = LocationComponent.new()
	garden.add_component("location", garden_loc)

	# Create Library room
	var library: WorldObject = WorldKeeper.create_room("The Library",
		"Towering bookshelves line the walls, filled with ancient tomes and scrolls.")
	var library_loc: LocationComponent = LocationComponent.new()
	library.add_component("location", library_loc)

	# Connect the rooms with exits
	lobby_loc.add_exit("garden", garden)
	lobby_loc.add_exit("north", garden)
	lobby_loc.add_exit("library", library)
	lobby_loc.add_exit("east", library)

	garden_loc.add_exit("lobby", lobby)
	garden_loc.add_exit("south", lobby)

	library_loc.add_exit("lobby", lobby)
	library_loc.add_exit("west", lobby)

func _setup_player() -> void:
	"""Create the player character and place in starting room.

	Constructs the player WorldObject with Actor and Memory components,
	places them in the first available room, and connects event signals
	to UI update handlers.
	"""
	player = WorldKeeper.create_object("player", "You")

	# Add Actor component for command execution
	var actor_comp: ActorComponent = ActorComponent.new()
	player.add_component("actor", actor_comp)

	# Add Memory component for storing experiences
	var memory_comp: MemoryComponent = MemoryComponent.new()
	player.add_component("memory", memory_comp)

	# Place player in first available room
	var rooms: Array = WorldKeeper.get_all_rooms()
	if rooms.size() > 0:
		player.move_to(rooms[0])

	# Connect actor events to UI handlers
	actor_comp.command_executed.connect(_on_command_executed)
	actor_comp.event_observed.connect(_on_event_observed)

func _setup_ai_agents() -> void:
	"""Spawn AI agents (Eliza and Moss) in appropriate rooms.

	Searches for Garden and Library rooms by name, spawns Eliza in the
	Garden and Moss in the Library. If named rooms don't exist, falls
	back to root_room. Connects AI actor events to UI update handlers.
	"""
	var rooms: Array = WorldKeeper.get_all_rooms()

	# Find specific rooms by name for agent placement
	var garden: WorldObject = null
	var library: WorldObject = null
	for room in rooms:
		if room.name == "The Garden":
			garden = room
		elif room.name == "The Library":
			library = room

	# Create Eliza in the Garden (or fallback to root room)
	var eliza: WorldObject = AIAgent.create_eliza(garden if garden else WorldKeeper.root_room)
	ai_agents.append(eliza)

	# Create Moss in the Library (or fallback to root room)
	var moss: WorldObject = AIAgent.create_moss(library if library else WorldKeeper.root_room)
	ai_agents.append(moss)

	# Connect AI agent command events to UI update handlers
	for agent in ai_agents:
		if agent.has_component("actor"):
			var actor_comp: ActorComponent = agent.get_component("actor") as ActorComponent
			actor_comp.command_executed.connect(_on_ai_command_executed)

func _on_ai_command_executed(_command: String, _result: Dictionary) -> void:
	"""Handle AI agent command execution.

	Updates the location display to reflect any changes caused by
	AI actions (movement, speech, etc).

	Args:
		_command: The command the AI executed (unused)
		_result: The command result Dictionary (unused)
	"""
	# Update occupants list if player is in same location
	_update_location_display()


func _process(delta: float) -> void:
	"""Process AI agent thinking each frame.

	Calls the process method on each AI agent's ThinkerComponent,
	allowing them to evaluate their situation and decide on actions.

	Args:
		delta: Time elapsed since previous frame
	"""
	for agent in ai_agents:
		if agent.has_component("thinker"):
			var thinker_comp: ThinkerComponent = agent.get_component("thinker") as ThinkerComponent
			thinker_comp.process(delta)


func _initial_look() -> void:
	"""Perform the initial look command for the player.

	Executes a look command immediately after world setup to
	display the starting location and populate the UI panels.
	"""
	var actor_comp: ActorComponent = player.get_component("actor") as ActorComponent
	if actor_comp:
		actor_comp.execute_command("look")

func _on_command_submitted(text: String) -> void:
	"""Process and execute player command from UI input.

	Parses the input text, handles command shortcuts (l, ', :),
	converts to full command format, and dispatches to the player's
	ActorComponent for execution.

	Args:
		text: Raw command string from UI input

	Notes:
		Shortcuts: l=look, '=say, :=emote
	"""
	# Parse command and arguments from input
	var parts: Array = text.split(" ", false, 1)
	var command: String = parts[0].to_lower()
	var args_string: String = parts[1] if parts.size() > 1 else ""

	# Handle command shortcuts
	match command:
		"l":
			command = "look"
		"'", "\"":
			command = "say"
			# If shortcut was used without space, extract everything after it
			if text.begins_with("'") or text.begins_with("\""):
				args_string = text.substr(1).strip_edges()
		":":
			command = "emote"
			if text.begins_with(":"):
				args_string = text.substr(1).strip_edges()

	# Verify player has actor component
	var actor_comp: ActorComponent = player.get_component("actor") as ActorComponent
	if not actor_comp:
		ui.add_error("You have no actor component!")
		return

	# Build arguments array from string
	var args: Array = []
	if not args_string.is_empty():
		args = args_string.split(" ", false)

	# Execute command through actor component
	actor_comp.execute_command(command, args)

func _on_command_executed(_command: String, result: Dictionary) -> void:
	"""Handle player command execution results and update UI.

	Displays success messages or errors, filters emoji icons for
	cleaner text, and updates location panels when relevant.

	Args:
		_command: The command that was executed (unused)
		result: Dictionary containing success, message, and optional location data

	Notes:
		Removes emoji icons (📍👥🔧) from messages for cleaner UI display
	"""
	if result.success:
		# Display success message
		var message: String = result.message as String

		# Remove emoji icons for cleaner UI
		message = message.replace("📍", "")
		message = message.replace("👥", "")
		message = message.replace("🔧", "")

		ui.add_event(message)

		# Update location panel if command affected location
		if result.has("location"):
			_update_location_display()
	else:
		ui.add_error(result.message)


func _on_event_observed(event: Dictionary) -> void:
	"""Display events observed by the player in their location.

	Formats and displays events from other actors (speech, movement,
	emotes) in light blue text.

	Args:
		event: Event Dictionary containing type, actor, message, etc.
	"""
	var text: String = EventWeaver.format_event(event)
	if text != "":
		ui.add_event("[color=light_blue]" + text + "[/color]")


func _update_location_display() -> void:
	"""Update the location and occupants UI panels.

	Retrieves current location data, extracts exits and occupants,
	and sends updates to the UI panels. Occupants list excludes
	the player and only shows other actors.
	"""
	var location: WorldObject = player.get_location()
	if not location:
		return

	# Update location panel with name, description, and exits
	var loc_comp: LocationComponent = location.get_component("location") as LocationComponent
	var exits: Array = []
	if loc_comp:
		exits.assign(loc_comp.get_exits().keys())

	ui.update_location(location.name, location.description, exits)

	# Update occupants panel with other actors in location
	var occupants: Array[String] = []
	for obj in location.get_contents():
		if obj != player and obj.has_component("actor"):
			occupants.append(obj.name)

	ui.update_occupants(occupants)
