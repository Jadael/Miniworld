## GameUI: Main player interface for Miniworld
##
## Classic MUD/MOO-style text-based interface providing:
## - Main event scroll displaying command results and events (center panel)
## - Location panel showing current room and exits (top right)
## - Occupants panel listing other actors present (bottom right)
## - Command input with history navigation (bottom)
##
## The UI supports BBCode formatting for colors and styling, and includes
## keyboard shortcuts for navigation commands and command history (UP/DOWN arrows).
##
## Dependencies:
## - GameControllerUI: Processes commands and provides game state updates
##
## Notes:
## - Command history is navigated with UP/DOWN arrow keys
## - Displays a welcome screen with command reference on startup
## - UP/DOWN keys navigate command history while input is focused

extends Control


## Main scrolling text area for events and command results
@onready var event_scroll: RichTextLabel = $MainPanel/EventScroll

## Container for the location panel
@onready var location_panel: PanelContainer = $SidePanel/LocationContainer/LocationPanel

## RichTextLabel showing location name and description
@onready var location_label: RichTextLabel = $SidePanel/LocationContainer/LocationPanel/VBox/LocationLabel

## Label showing available exits from current location
@onready var exits_label: Label = $SidePanel/LocationContainer/LocationPanel/VBox/ExitsLabel

## Container for the occupants panel
@onready var occupants_panel: PanelContainer = $SidePanel/OccupantsContainer/OccupantsPanel

## RichTextLabel listing other actors in the location
@onready var occupants_list: RichTextLabel = $SidePanel/OccupantsContainer/OccupantsPanel/OccupantsList

## LineEdit for player command input
@onready var command_input: LineEdit = $BottomPanel/CommandInput

## Button to submit commands (alternative to pressing Enter)
@onready var send_button: Button = $BottomPanel/SendButton


## Command history buffer storing previous commands
var command_history: Array[String] = []

## Current position in command history (size = at end, 0 = oldest)
var history_index: int = 0

## Reference to game controller (currently unused)
var game_controller: Node = null

## Current memory status indicator for command prompt
var memory_status: String = "[Memory: OK]"


## Emitted when player submits a command via Enter or Send button
signal command_submitted(command: String)

func _ready() -> void:
	"""Initialize the UI and display welcome screen.

	Connects signals, sets focus to command input, and displays
	a formatted welcome message with command reference.
	"""
	# Connect input signals
	# NOTE: We handle Enter key manually in _input() instead of using text_submitted
	# because LineEdit's text_submitted signal has focus issues in Godot
	send_button.pressed.connect(_on_send_pressed)

	# Focus on input for immediate interaction
	command_input.grab_focus()

	# Display welcome screen with command reference
	add_event("[color=cyan]════════════════════════════════════════════════[/color]")
	add_event("[color=cyan][center][b][font_size=20]MINIWORLD[/font_size][/b][/center][/color]")
	add_event("[color=cyan][center]A LambdaMOO-Inspired World[/center][/color]")
	add_event("[color=cyan]════════════════════════════════════════════════[/color]")
	add_event("")
	add_event("[color=orange][b]⚙  GETTING STARTED[/b][/color]")
	add_event("[color=gray]────────────────────────────────────────────────[/color]")
	add_event("Miniworld requires a local [b]Ollama[/b] server for AI agents.")
	add_event("")
	add_event("[color=dim_gray]•[/color] [b]Setup:[/b] Install from [color=light_blue][url]https://ollama.com[/url][/color]")
	add_event("[color=dim_gray]•[/color] [b]Default:[/b] http://localhost:11434 (auto-configured)")
	add_event("[color=dim_gray]•[/color] [b]Models:[/b] Recommend llama3.2 or similar chat model")
	add_event("[color=dim_gray]•[/color] Type [b][color=light_green]settings[/color][/b] to configure connection if needed")
	add_event("")
	add_event("")
	add_event("[color=yellow][b]📍 NAVIGATION[/b][/color]")
	add_event("[color=gray]────────────────────────────────────────────────[/color]")
	add_event("[b]look[/b] (l) [color=gray]..................[/color] Look around")
	add_event("[b]go[/b] <exit> [color=gray]................[/color] Move through an exit")
	add_event("[b]where[/b] [color=gray]....................[/color] Show current location")
	add_event("")
	add_event("[color=yellow][b]💬 SOCIAL[/b][/color]")
	add_event("[color=gray]────────────────────────────────────────────────[/color]")
	add_event("[b]say[/b] <msg> or [b]'[/b]<msg> [color=gray].......[/color] Speak")
	add_event("[b]emote[/b] <action> or [b]:[/b]<action> [color=gray]..[/color] Perform action")
	add_event("[b]who[/b] [color=gray]......................[/color] List all characters")
	add_event("")
	add_event("[color=yellow][b]🏗  BUILDING[/b][/color]")
	add_event("[color=gray]────────────────────────────────────────────────[/color]")
	add_event("[b]rooms[/b] [color=gray]....................[/color] List all rooms")
	add_event("[b]@dig[/b] <name> [color=gray]...............[/color] Create a new room")
	add_event("[b]@exit[/b] <name> to <room> [color=gray]....[/color] Connect rooms")
	add_event("[b]@teleport[/b] <room> [color=gray].........[/color] Jump to any room")
	add_event("")
	add_event("[color=magenta][b]❓ HELP[/b][/color]")
	add_event("[color=gray]────────────────────────────────────────────────[/color]")
	add_event("[b]help[/b] [color=gray]....................[/color] Show all commands")
	add_event("[b]help[/b] <command> [color=gray]...........[/color] Detailed command help")
	add_event("[b]help[/b] <category> [color=gray].........[/color] Show category commands")
	add_event("")
	add_event("[color=cyan]════════════════════════════════════════════════[/color]")
	add_event("")

func _input(event: InputEvent) -> void:
	"""Handle keyboard input for command history navigation and Enter key.

	Intercepts UP/DOWN arrow keys when command input is focused to
	navigate through command history. Also intercepts Enter key to
	avoid LineEdit's text_submitted focus issues.

	Args:
		event: The input event to process
	"""
	if event is InputEventKey and event.pressed and command_input.has_focus():
		# Handle Enter key for command submission
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			var text: String = command_input.text
			if not text.strip_edges().is_empty():
				_on_command_submitted(text)
			get_viewport().set_input_as_handled()
		# Command history navigation with arrow keys
		elif event.keycode == KEY_UP:
			_history_prev()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			_history_next()
			get_viewport().set_input_as_handled()


func _on_command_submitted(text: String) -> void:
	"""Process submitted command text.

	Adds non-duplicate commands to history, echoes the command in
	green text with memory status indicator, emits command_submitted
	signal, and clears the input.

	Args:
		text: The command string submitted by the player

	Notes:
		Memory status is displayed as a compact indicator before the >
		prompt (e.g., "[Memory: OK] > look" or "[Memory: WARNING - 2 issues] > recall").
	"""
	if text.strip_edges().is_empty():
		return

	# Add to history (skip duplicates of last command)
	if command_history.is_empty() or command_history.back() != text:
		command_history.append(text)
	history_index = command_history.size()

	# Echo command to event scroll with memory status indicator
	var status_color: String = "green" if "OK" in memory_status else "yellow"
	add_event("[color=%s]%s[/color] [color=light_green]> %s[/color]" % [status_color, memory_status, text])

	# Emit signal for game controller to process
	command_submitted.emit(text)

	# Clear input
	command_input.clear()

	# Re-grab focus to keep input ready for next command
	command_input.grab_focus()


func _on_send_pressed() -> void:
	"""Handle Send button press.

	Delegates to _on_command_submitted with current input text.
	"""
	_on_command_submitted(command_input.text)


func _history_prev() -> void:
	"""Navigate to previous command in history.

	Moves backward through command_history and updates input text.
	Places caret at end of restored command.
	"""
	if history_index > 0:
		history_index -= 1
		command_input.text = command_history[history_index]
		command_input.caret_column = command_input.text.length()


func _history_next() -> void:
	"""Navigate to next command in history.

	Moves forward through command_history and updates input text.
	If at end of history, clears the input. Places caret at end.
	"""
	if history_index < command_history.size() - 1:
		history_index += 1
		command_input.text = command_history[history_index]
		command_input.caret_column = command_input.text.length()
	else:
		history_index = command_history.size()
		command_input.clear()

## Public interface for game controller
func add_event(text: String) -> void:
	"""Add text to the event scroll.

	Appends BBCode-formatted text to the scrolling event display.

	Args:
		text: The text string to append (may contain BBCode formatting)
	"""
	event_scroll.append_text(text + "\n")


func add_system_message(text: String) -> void:
	"""Add a system message formatted in gray italic text.

	Used for system notifications and meta-information.

	Args:
		text: The message text to display
	"""
	add_event("[color=gray][i]" + text + "[/i][/color]")


func add_error(text: String) -> void:
	"""Add an error message formatted in red with an X icon.

	Used for command failures and error conditions.

	Args:
		text: The error message to display
	"""
	add_event("[color=red]✗ " + text + "[/color]")


func add_success(text: String) -> void:
	"""Add a success message formatted in green with a checkmark.

	Used for successful operations and confirmations.

	Args:
		text: The success message to display
	"""
	add_event("[color=green]✓ " + text + "[/color]")


func update_location(location_name: String, description: String, exits: Array) -> void:
	"""Update the location panel with current room information.

	Displays the room name in bold yellow with increased size,
	followed by description, and lists available exits at the bottom.

	Args:
		location_name: Name of the current location
		description: Descriptive text for the location
		exits: Array of exit names (Strings)
	"""
	location_label.clear()
	location_label.append_text("[font_size=16][b][color=yellow]" + location_name + "[/color][/b][/font_size]\n")
	location_label.append_text("[color=gray]──────────────[/color]\n")
	location_label.append_text(description)

	# Update exits display - plain Label doesn't support BBCode
	if exits.size() > 0:
		exits_label.text = "Exits: " + ", ".join(exits)
	else:
		exits_label.text = "No exits"


func update_occupants(occupants: Array[String]) -> void:
	"""Update the occupants panel with current room's actors.

	Displays a list of other actors present in the location,
	excluding the player. Shows "You are alone" if empty.

	Args:
		occupants: Array of actor names present in location
	"""
	occupants_list.clear()

	if occupants.size() == 0:
		occupants_list.append_text("[color=dim_gray][i]You are alone[/i][/color]")
	else:
		occupants_list.append_text("[font_size=14][b]Also here:[/b][/font_size]\n")
		occupants_list.append_text("[color=gray]──────────────[/color]\n")
		for occupant in occupants:
			occupants_list.append_text("[color=light_blue]•[/color] [b]" + occupant + "[/b]\n")


func clear_events() -> void:
	"""Clear all text from the event scroll.

	Removes all event history from the display.
	"""
	event_scroll.clear()


func set_input_enabled(enabled: bool) -> void:
	"""Enable or disable command input controls.

	Used to prevent input during certain game states.

	Args:
		enabled: True to enable input, False to disable
	"""
	command_input.editable = enabled
	send_button.disabled = not enabled


func update_memory_status(status: String) -> void:
	"""Update the memory status indicator for the command prompt.

	Args:
		status: Compact status string (e.g., "[Memory: OK]" or "[Memory: WARNING - 2 issues]")

	Notes:
		This updates the cached status that will be displayed on the next
		command submission. The status indicator appears before the > prompt
		in green (if OK) or yellow (if warnings detected).
	"""
	memory_status = status
