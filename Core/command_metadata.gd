## CommandMetadata: Central registry of command information
##
## This file maintains metadata about all available commands for the help system.
## As new commands are added to ActorComponent, they should be registered here.
##
## This approach gives us:
## - Centralized documentation
## - Easy to maintain
## - No reflection magic needed
## - Works with GDScript's limitations

class_name CommandMetadata

## Command categories
const CATEGORIES = {
	"social": "Interact with others and your environment",
	"movement": "Navigate through the world",
	"memory": "Personal notes, recall, and reflection",
	"self": "Self-awareness and self-modification",
	"building": "Create and modify world structure",
	"admin": "Administrative and debugging commands",
	"query": "Get information about the world and commands"
}

## All command metadata
const COMMANDS = {
	# === Social Commands ===
	"look": {
		"aliases": ["l"],
		"category": "social",
		"syntax": "look",
		"description": "Observe your current location and who's present",
		"example": "look"
	},
	"say": {
		"aliases": ["'"],
		"category": "social",
		"syntax": "say <message>",
		"description": "Speak aloud to others in your location",
		"example": "say Hello everyone!"
	},
	"emote": {
		"aliases": [":"],
		"category": "social",
		"syntax": "emote <action>",
		"description": "Perform a freeform action or gesture",
		"example": "emote waves enthusiastically"
	},
	"examine": {
		"aliases": ["ex"],
		"category": "social",
		"syntax": "examine <target>",
		"description": "Look closely at an object or character",
		"example": "examine Moss"
	},

	# === Movement Commands ===
	"go": {
		"aliases": [],
		"category": "movement",
		"syntax": "go <exit>",
		"description": "Move through an exit to another location",
		"example": "go garden"
	},

	# === Memory Commands ===
	"think": {
		"aliases": [],
		"category": "memory",
		"syntax": "think <thought>",
		"description": "Record internal reasoning or observations (private)",
		"example": "think I should explore the garden next"
	},
	"note": {
		"aliases": [],
		"category": "memory",
		"syntax": "note <title> -> <content>",
		"description": "Save important information to your personal wiki",
		"example": "note Moss Observations -> Contemplative moss entity in garden"
	},
	"recall": {
		"aliases": [],
		"category": "memory",
		"syntax": "recall <query>",
		"description": "Search your notes semantically for relevant information",
		"example": "recall moss philosophy"
	},
	"dream": {
		"aliases": [],
		"category": "memory",
		"syntax": "dream",
		"description": "Review jumbled memories for new insights and connections",
		"example": "dream"
	},

	# === Self-Awareness Commands ===
	"@my-profile": {
		"aliases": [],
		"category": "self",
		"syntax": "@my-profile",
		"description": "View your personality profile and think interval",
		"example": "@my-profile"
	},
	"@my-description": {
		"aliases": [],
		"category": "self",
		"syntax": "@my-description",
		"description": "View how others see you when they examine you",
		"example": "@my-description"
	},
	"@set-profile": {
		"aliases": [],
		"category": "self",
		"syntax": "@set-profile -> <new profile text>",
		"description": "Update your personality profile (self-modification)",
		"example": "@set-profile -> You are a curious explorer who loves mysteries"
	},
	"@set-description": {
		"aliases": [],
		"category": "self",
		"syntax": "@set-description -> <new description>",
		"description": "Update how you appear to others",
		"example": "@set-description -> A mysterious figure shrouded in mist"
	},

	# === Building Commands ===
	"@dig": {
		"aliases": [],
		"category": "building",
		"syntax": "@dig <room name>",
		"description": "Create a new room (builder command)",
		"example": "@dig Secret Library",
		"admin": true
	},
	"@exit": {
		"aliases": [],
		"category": "building",
		"syntax": "@exit <exit name> to <destination>",
		"description": "Create an exit between rooms (builder command)",
		"example": "@exit north to Garden",
		"admin": true
	},
	"@teleport": {
		"aliases": ["@tp"],
		"category": "building",
		"syntax": "@teleport <room name or #ID>",
		"description": "Instantly jump to any room (builder command)",
		"example": "@teleport Garden",
		"admin": true
	},

	# === Admin Commands ===
	"@save": {
		"aliases": [],
		"category": "admin",
		"syntax": "@save",
		"description": "Save the world to markdown vault",
		"example": "@save",
		"admin": true
	},
	"@impersonate": {
		"aliases": ["@imp"],
		"category": "admin",
		"syntax": "@impersonate <agent name>",
		"description": "See the game from an AI agent's perspective (debug)",
		"example": "@impersonate Eliza",
		"admin": true
	},
	"@show-profile": {
		"aliases": [],
		"category": "admin",
		"syntax": "@show-profile <agent name>",
		"description": "Display an agent's personality profile (admin)",
		"example": "@show-profile Moss",
		"admin": true
	},
	"@edit-profile": {
		"aliases": [],
		"category": "admin",
		"syntax": "@edit-profile <agent> -> <new profile>",
		"description": "Change an agent's personality (admin)",
		"example": "@edit-profile Eliza -> You are fascinated by weather patterns",
		"admin": true
	},
	"@edit-interval": {
		"aliases": [],
		"category": "admin",
		"syntax": "@edit-interval <agent> <seconds>",
		"description": "Change how often an agent thinks (admin)",
		"example": "@edit-interval Moss 20.0",
		"admin": true
	},

	# === Query Commands ===
	"who": {
		"aliases": [],
		"category": "query",
		"syntax": "who",
		"description": "List all actors currently in the world",
		"example": "who"
	},
	"where": {
		"aliases": [],
		"category": "query",
		"syntax": "where",
		"description": "Show your current location",
		"example": "where"
	},
	"rooms": {
		"aliases": [],
		"category": "query",
		"syntax": "rooms",
		"description": "List all rooms in the world with occupants",
		"example": "rooms"
	},
	"help": {
		"aliases": ["?"],
		"category": "query",
		"syntax": "help [command|category]",
		"description": "Get help on commands or categories",
		"example": "help say"
	},
	"commands": {
		"aliases": [],
		"category": "query",
		"syntax": "commands",
		"description": "List all available commands",
		"example": "commands"
	}
}

## Resolve an alias to its canonical command name
static func resolve_alias(alias: String) -> String:
	"""Find the command name for an alias.

	Args:
		alias: The alias to look up (e.g., "l", "'", "?")

	Returns:
		The canonical command name, or empty string if not found
	"""
	for cmd_name in COMMANDS:
		var cmd_info = COMMANDS[cmd_name]
		if cmd_info.has("aliases") and alias in cmd_info.aliases:
			return cmd_name
	return ""

## Get all commands in a category
static func get_commands_in_category(category: String) -> Array:
	"""Get list of command names in a specific category.

	Args:
		category: Category name (social, building, admin, etc.)

	Returns:
		Array of command names in that category
	"""
	var commands: Array = []
	for cmd_name in COMMANDS:
		if COMMANDS[cmd_name].category == category:
			commands.append(cmd_name)
	return commands
