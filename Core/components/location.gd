## LocationComponent: Makes a WorldObject into a room/location
##
## Objects with this component are locations (rooms) that can:
## - Have exits to other locations
## - Contain other objects (characters, items, etc.)
## - Be navigated to/from
##
## This is the MOO equivalent of a room object. Every navigable space
## in Miniworld should have this component attached.
##
## Related: ActorComponent (for entities that move between locations)

extends ComponentBase
class_name LocationComponent


## Maps exit names to destination WorldObjects (direction -> location)
## Keys are normalized to lowercase for case-insensitive matching
var exits: Dictionary = {}


func _on_added(obj: WorldObject) -> void:
	"""Initialize location component and mark object as a room.

	Args:
		obj: The WorldObject becoming a location
	"""
	super._on_added(obj)
	obj.set_flag("is_room", true)


func _on_removed(obj: WorldObject) -> void:
	"""Clean up location component and remove room flag.

	Args:
		obj: The WorldObject being removed from
	"""
	super._on_removed(obj)
	obj.set_flag("is_room", false)


func add_exit(exit_name: String, destination: WorldObject) -> void:
	"""Add an exit from this location to another.

	Exit names are case-insensitive (stored as lowercase).

	Args:
		exit_name: Name of the exit (e.g., "north", "door", "garden")
		destination: The WorldObject to travel to via this exit

	Notes:
		Silently fails if destination is null (with warning)
	"""
	if destination == null:
		push_warning("LocationComponent: Cannot add exit to null destination")
		return

	exits[exit_name.to_lower()] = destination


func remove_exit(exit_name: String) -> void:
	"""Remove an exit from this location.

	Args:
		exit_name: Name of the exit to remove
	"""
	exits.erase(exit_name.to_lower())


func get_exit(exit_name: String) -> WorldObject:
	"""Get the destination for an exit with generous matching.

	Args:
		exit_name: Name of the exit to look up

	Returns:
		Destination WorldObject, or null if exit doesn't exist

	Notes:
		Performs generous fuzzy matching:
		- Exact match: "The Lobby" matches "the lobby"
		- Article-insensitive: "Lobby" matches "the lobby"
		- Partial word match: "Lobby" matches "The Grand Lobby"
		- Prefix match: "Lob" matches "Lobby"
	"""
	var search = exit_name.to_lower().strip_edges()
	if search.is_empty():
		return null

	# Try exact match first (fastest)
	if exits.has(search):
		return exits[search]

	# Helper function for fuzzy matching
	var matches = func(search_str: String, target_str: String) -> bool:
		var search_l = search_str.to_lower()
		var target_l = target_str.to_lower()

		# Exact match
		if target_l == search_l:
			return true

		# Remove common articles for matching
		var articles = ["the ", "a ", "an "]
		for article in articles:
			if target_l.begins_with(article):
				var target_without_article = target_l.substr(article.length())
				if target_without_article == search_l:
					return true
				# Also try prefix match without article
				if target_without_article.begins_with(search_l):
					return true

		# Prefix match
		if target_l.begins_with(search_l):
			return true

		# Word-boundary partial match (e.g., "Lobby" matches "The Grand Lobby")
		var search_words = search_l.split(" ")
		var target_words = target_l.split(" ")

		# Single word search matching any word in target
		if search_words.size() == 1:
			for target_word in target_words:
				if target_word == search_l or target_word.begins_with(search_l):
					return true

		# Multi-word search: all search words must match (in order)
		if search_words.size() > 1:
			var search_idx = 0
			for target_word in target_words:
				if search_idx < search_words.size():
					if target_word == search_words[search_idx] or target_word.begins_with(search_words[search_idx]):
						search_idx += 1
			if search_idx == search_words.size():
				return true

		return false

	# Try fuzzy matching on all exit names
	for exit_key in exits.keys():
		if matches.call(search, exit_key):
			return exits[exit_key]

	return null


func get_exits() -> Dictionary:
	"""Get all exits from this location.

	Returns:
		Dictionary mapping exit names (String) to destinations (WorldObject)
	"""
	return exits


func has_exit(exit_name: String) -> bool:
	"""Check if an exit exists.

	Args:
		exit_name: Name of the exit to check

	Returns:
		True if the exit exists, false otherwise
	"""
	return exit_name.to_lower() in exits


func enhance_description(base_description: String) -> String:
	"""Add exit information to the location's description.

	Args:
		base_description: The location's base description

	Returns:
		Enhanced description with exit list appended inline
	"""
	var desc = base_description

	# Add exit information inline
	if exits.size() > 0:
		desc += " Exits: "
		var exit_names: Array[String] = []
		for exit_name in exits.keys():
			exit_names.append(exit_name)
		desc += ", ".join(exit_names) + "."
	else:
		desc += " No obvious exits."

	return desc


func get_contents_description() -> String:
	"""Generate a description of objects in this location.

	Returns:
		Formatted text listing all objects in the location inline
	"""
	var contents = owner.get_contents()

	if contents.size() == 0:
		return ""  # Don't add anything if room is empty

	var names: Array[String] = []
	for obj in contents:
		if obj != owner:  # Don't list the room itself
			names.append(obj.name)

	if names.size() == 0:
		return ""

	return " Occupants: " + ", ".join(names) + "."


## Markdown Vault Persistence

func parse_exits_from_markdown(markdown_body: String, room_by_name: Dictionary) -> void:
	"""Parse and restore exits from markdown Exits section.

	Exits format:
	## Exits
	- [[Destination Room]] | alias1 | alias2 | alias3

	Args:
		markdown_body: Markdown body content containing Exits section
		room_by_name: Dictionary mapping room names to WorldObject instances

	Notes:
		Multiple aliases per destination create multiple exit entries
		All point to the same destination WorldObject
	"""
	exits.clear()

	# Find the Exits section
	if not "## Exits" in markdown_body:
		return

	var lines: Array = markdown_body.split("\n")
	var in_exits_section: bool = false

	for line in lines:
		if line.strip_edges() == "## Exits":
			in_exits_section = true
			continue

		if in_exits_section:
			# Stop at next section
			if line.begins_with("## "):
				break

			# Parse exit line: - [[Destination]] | alias1 | alias2
			if line.begins_with("- [["):
				var exit_line: String = line.substr(2).strip_edges()  # Remove "- "

				# Extract destination name from [[...]]
				var dest_end: int = exit_line.find("]]")
				if dest_end == -1:
					continue

				var dest_name: String = exit_line.substr(2, dest_end - 2).strip_edges()

				# Extract aliases after the |
				var aliases_start: int = exit_line.find("|", dest_end)
				if aliases_start == -1:
					continue

				var aliases_str: String = exit_line.substr(aliases_start + 1).strip_edges()
				var alias_list: Array = aliases_str.split("|")

				# Resolve destination
				if not room_by_name.has(dest_name):
					push_warning("LocationComponent: Cannot resolve exit to '%s' - room not found" % dest_name)
					continue

				var dest_room: WorldObject = room_by_name[dest_name]

				# Add all aliases pointing to this destination
				for alias in alias_list:
					var alias_name: String = alias.strip_edges()
					if not alias_name.is_empty():
						exits[alias_name.to_lower()] = dest_room
