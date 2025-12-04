## LLMDebugPanel: Spectator-friendly display of active LLM prompts and agent actions
##
## Provides real-time visibility into what prompts are being sent to the LLM
## and a scrolling log of all agent actions. This helps users understand what
## AI agents are "thinking" and doing.
##
## Features:
## - Shows the current prompt being processed
## - Displays a scrolling log of all agent actions (Name> command)
## - Color-coded for readability
## - Persistent action log (doesn't auto-clear)
##
## Dependencies:
## - Shoggoth daemon for task_started and task_response signals

extends VBoxContainer


## Label showing which agent/task is currently active
@onready var header_label: Label = $HeaderLabel

## RichTextLabel displaying the full prompt sent to the LLM
@onready var prompt_scroll: RichTextLabel = $PromptContainer/PromptPanel/PromptScroll

## RichTextLabel displaying scrolling log of agent actions
@onready var response_scroll: RichTextLabel = $ResponseContainer/ResponsePanel/ResponseScroll

## Maps task_id to agent name for logging
var task_agents: Dictionary = {}


func _ready() -> void:
	"""Initialize the panel and connect to Shoggoth signals.

	Connects to task_started and task_response signals to receive
	real-time updates about LLM activity.
	"""
	if Shoggoth:
		Shoggoth.task_started.connect(_on_task_started)
		Shoggoth.task_response.connect(_on_task_response)

	# Start with empty state
	_clear_display()


func _on_task_started(task_id: String, prompt: String) -> void:
	"""Handle a new task starting.

	Args:
		task_id: Unique identifier for the task
		prompt: The full prompt being sent to the LLM

	Notes:
		Displays the prompt immediately and extracts agent name for logging.
	"""
	# Extract agent name from prompt (look for "You are <name> in <location>")
	var agent_name: String = "Unknown"
	var name_pattern: RegEx = RegEx.new()
	name_pattern.compile("You are ([^\\s]+) in")
	var result: RegExMatch = name_pattern.search(prompt)
	if result:
		agent_name = result.get_string(1)

	# Store for later logging
	task_agents[task_id] = agent_name

	header_label.text = "LLM PROCESSING: %s" % agent_name

	# Display the prompt
	prompt_scroll.clear()
	prompt_scroll.append_text("[color=light_blue]" + prompt + "[/color]")


func _on_task_response(task_id: String, response: String) -> void:
	"""Handle a task response arriving.

	Args:
		task_id: Unique identifier for the task
		response: The LLM's response text

	Notes:
		Adds the response to the scrolling log with agent name prefix.
		Log format: "Name> command"
	"""
	# Get agent name from stored mapping
	var agent_name: String = task_agents.get(task_id, "Unknown")
	task_agents.erase(task_id)  # Clean up

	# Extract just the command (first line, ignore thinking if present)
	var command: String = response
	if "[Thinking]" in response:
		# Skip thinking section, get response section
		var parts: PackedStringArray = response.split("[Response]")
		if parts.size() > 1:
			command = parts[1].strip_edges()

	# Take only first line of command
	var lines: PackedStringArray = command.split("\n")
	if lines.size() > 0:
		command = lines[0].strip_edges()

	# Add to scrolling log
	response_scroll.append_text("[color=light_green]%s>[/color] %s\n" % [agent_name, command])

	# Update header to show idle after brief delay
	header_label.text = "LLM IDLE"


func _clear_display() -> void:
	"""Clear all display areas and reset to idle state."""
	header_label.text = "LLM IDLE"
	prompt_scroll.clear()
	prompt_scroll.append_text("[color=dim_gray][i]No active LLM tasks[/i][/color]")
	response_scroll.clear()
	response_scroll.append_text("[color=dim_gray][i]Agent action log (Name> command)[/i][/color]\n")
