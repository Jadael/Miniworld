## GameUI: Main player interface for Miniworld
##
## Classic MUD/MOO-style interface with:
## - Main event scroll (center)
## - Location panel (top right)
## - Who's here panel (bottom right)
## - Command input (bottom)

extends Control

## UI Elements
@onready var event_scroll: RichTextLabel = $MainPanel/EventScroll
@onready var location_panel: PanelContainer = $SidePanel/LocationContainer/LocationPanel
@onready var location_label: RichTextLabel = $SidePanel/LocationContainer/LocationPanel/LocationLabel
@onready var exits_label: Label = $SidePanel/LocationContainer/LocationPanel/ExitsLabel
@onready var occupants_panel: PanelContainer = $SidePanel/OccupantsContainer/OccupantsPanel
@onready var occupants_list: RichTextLabel = $SidePanel/OccupantsContainer/OccupantsPanel/OccupantsList
@onready var command_input: LineEdit = $BottomPanel/CommandInput
@onready var send_button: Button = $BottomPanel/SendButton

## Command history
var command_history: Array[String] = []
var history_index: int = 0

## Reference to game controller
var game_controller: Node = null

signal command_submitted(command: String)

func _ready() -> void:
	# Connect signals
	command_input.text_submitted.connect(_on_command_submitted)
	send_button.pressed.connect(_on_send_pressed)

	# Focus on input
	command_input.grab_focus()

	# Welcome message
	add_event("[color=cyan]═══════════════════════════════════════[/color]")
	add_event("[color=cyan][center][b]MINIWORLD[/b][/center][/color]")
	add_event("[color=cyan][center]A LambdaMOO-Inspired World[/center][/color]")
	add_event("[color=cyan]═══════════════════════════════════════[/color]")
	add_event("")
	add_event("[color=yellow][b]Navigation:[/b][/color]")
	add_event("  look (l) - Look around")
	add_event("  go <exit> - Move through an exit")
	add_event("  where - Show current location")
	add_event("")
	add_event("[color=yellow][b]Social:[/b][/color]")
	add_event("  say <msg> or '<msg> - Speak")
	add_event("  emote <action> or :<action> - Perform action")
	add_event("  who - List all characters")
	add_event("")
	add_event("[color=yellow][b]Building:[/b][/color]")
	add_event("  rooms - List all rooms")
	add_event("  @dig <name> - Create a new room")
	add_event("  @exit <name> to <room> - Connect rooms")
	add_event("  @teleport <room> - Jump to any room")
	add_event("")
	add_event("[color=gray]Press ~ for dev console[/color]")
	add_event("")

func _input(event: InputEvent) -> void:
	# Command history navigation
	if event is InputEventKey and event.pressed and command_input.has_focus():
		if event.keycode == KEY_UP:
			_history_prev()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			_history_next()
			get_viewport().set_input_as_handled()

func _on_command_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return

	# Add to history
	if command_history.is_empty() or command_history.back() != text:
		command_history.append(text)
	history_index = command_history.size()

	# Echo command
	add_event("[color=light_green]> " + text + "[/color]")

	# Emit signal for game controller
	command_submitted.emit(text)

	# Clear input and keep focus
	command_input.clear()
	command_input.call_deferred("grab_focus")

func _on_send_pressed() -> void:
	_on_command_submitted(command_input.text)

func _history_prev() -> void:
	if history_index > 0:
		history_index -= 1
		command_input.text = command_history[history_index]
		command_input.caret_column = command_input.text.length()

func _history_next() -> void:
	if history_index < command_history.size() - 1:
		history_index += 1
		command_input.text = command_history[history_index]
		command_input.caret_column = command_input.text.length()
	else:
		history_index = command_history.size()
		command_input.clear()

## Public interface for game controller
func add_event(text: String) -> void:
	"""Add text to the event scroll"""
	event_scroll.append_text(text + "\n")

func add_system_message(text: String) -> void:
	"""Add a system message (gray, italic)"""
	add_event("[color=gray][i]" + text + "[/i][/color]")

func add_error(text: String) -> void:
	"""Add an error message"""
	add_event("[color=red]✗ " + text + "[/color]")

func add_success(text: String) -> void:
	"""Add a success message"""
	add_event("[color=green]✓ " + text + "[/color]")

func update_location(location_name: String, description: String, exits: Array) -> void:
	"""Update the location panel"""
	location_label.clear()
	location_label.append_text("[b][color=yellow]" + location_name + "[/color][/b]\n\n")
	location_label.append_text(description)

	# Update exits
	if exits.size() > 0:
		exits_label.text = "Exits: " + ", ".join(exits)
	else:
		exits_label.text = "No exits"

func update_occupants(occupants: Array[String]) -> void:
	"""Update the occupants list"""
	occupants_list.clear()

	if occupants.size() == 0:
		occupants_list.append_text("[color=gray][i]You are alone[/i][/color]")
	else:
		occupants_list.append_text("[b]Also here:[/b]\n\n")
		for occupant in occupants:
			occupants_list.append_text("• " + occupant + "\n")

func clear_events() -> void:
	"""Clear the event scroll"""
	event_scroll.clear()

func set_input_enabled(enabled: bool) -> void:
	"""Enable/disable input"""
	command_input.editable = enabled
	send_button.disabled = not enabled
