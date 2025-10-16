## CommandParser: LambdaMOO-compatible command parsing system
##
## Implements the full LambdaMOO command parsing spec with maximum generosity:
## - Handles quoted arguments with backslash escaping
## - Parses prepositional phrases (in, on, to, with, etc.)
## - Matches objects with prefix and alias support (#-1, #-2, #-3 semantics)
## - Wildcard verb matching with * patterns
## - Three-word command forms: verb, verb dobj, verb dobj prep iobj
##
## Built-in shortcuts:
## - " → say
## - : → emote
## - ; → eval (for future use)
##
## Dependencies:
## - WorldKeeper: For object resolution
## - WorldObject: For alias matching
##
## References:
## - LambdaMOO Programmer's Manual, Chapter 3: The Built-in Command Parser
##
## Notes:
## - This parser is intentionally generous to be user-friendly
## - It follows MOO conventions for ambiguous/failed matches
## - Objects can be referenced by name, alias, or #ID

extends RefCounted
class_name CommandParser


## Special object IDs for match results (MOO-compatible)
const NOTHING = "#-1"           ## No object specified (empty string)
const AMBIGUOUS_MATCH = "#-2"   ## Multiple objects matched
const FAILED_MATCH = "#-3"      ## No objects matched


## All preposition sets from LambdaMOO spec
const PREPOSITIONS = {
	"with/using": ["with", "using"],
	"at/to": ["at", "to"],
	"in front of": ["in front of", "in", "inside", "into"],
	"on top of/on/onto/upon": ["on top of", "on", "onto", "upon"],
	"out of/from inside/from": ["out of", "from inside", "from"],
	"over": ["over"],
	"through": ["through"],
	"under/underneath/beneath": ["under", "underneath", "beneath"],
	"behind": ["behind"],
	"beside": ["beside"],
	"for/about": ["for", "about"],
	"is": ["is"],
	"as": ["as"],
	"off/off of": ["off", "off of"]
}

## Flattened list of all prepositions for quick matching
const ALL_PREPS: Array[String] = [
	"with", "using",
	"at", "to",
	"in front of", "in", "inside", "into",
	"on top of", "on", "onto", "upon",
	"out of", "from inside", "from",
	"over", "through",
	"under", "underneath", "beneath",
	"behind", "beside",
	"for", "about",
	"is", "as",
	"off", "off of"
]


## Parsed command structure
class ParsedCommand:
	"""Result of parsing a command string.

	Contains all components needed for verb resolution:
	- verb: The command verb string
	- argstr: Full argument string after verb
	- args: Array of tokenized words
	- dobjstr: Direct object string (empty if none)
	- dobj: Direct object WorldObject or special ID (#-1, #-2, #-3)
	- prepstr: Preposition string (empty if none)
	- iobjstr: Indirect object string (empty if none)
	- iobj: Indirect object WorldObject or special ID
	- reason: Optional reasoning/commentary after | separator
	"""
	var verb: String = ""
	var argstr: String = ""
	var args: Array[String] = []
	var dobjstr: String = ""
	var dobj: Variant = null  ## WorldObject, special ID string, or null
	var prepstr: String = ""
	var iobjstr: String = ""
	var iobj: Variant = null  ## WorldObject, special ID string, or null
	var reason: String = ""


## Parse a command string into its components
static func parse(input: String, actor: WorldObject = null, location: WorldObject = null) -> ParsedCommand:
	"""Parse a command string using LambdaMOO semantics.

	Handles:
	1. Built-in shortcuts (", :, ;)
	2. Reasoning separator (|)
	3. Quote-aware tokenization
	4. Preposition matching
	5. Object resolution with actor and location context

	Args:
		input: Raw command string from player
		actor: The actor executing the command (for "me" resolution)
		location: Current location (for object matching scope)

	Returns:
		ParsedCommand with all fields populated

	Example:
		parse('put yellow bird in cuckoo clock', actor, location)
		→ verb="put", dobjstr="yellow bird", prepstr="in", iobjstr="cuckoo clock"
	"""
	var result = ParsedCommand.new()

	# Step 1: Handle reasoning separator (|)
	var command_part: String = input
	if "|" in input:
		var parts: Array = input.split("|", true, 1)
		command_part = parts[0].strip_edges()
		if parts.size() > 1:
			result.reason = parts[1].strip_edges()

	# Step 2: Handle built-in shortcuts
	command_part = _expand_shortcuts(command_part)

	# Step 3: Tokenize with quote support
	var words: Array[String] = _tokenize(command_part)

	if words.size() == 0:
		return result  # Empty command

	# Step 4: Extract verb (first word)
	result.verb = words[0]
	words.remove_at(0)

	# Step 5: Build argstr from remaining words
	if words.size() > 0:
		result.argstr = " ".join(words)
	result.args = words

	# Step 6: Find preposition (earliest match in command)
	var prep_index: int = -1
	var matched_prep: String = ""

	for i in range(words.size()):
		# Try multi-word prepositions first (longest match)
		for prep in ALL_PREPS:
			var prep_words: Array = prep.split(" ")
			if i + prep_words.size() <= words.size():
				var matches: bool = true
				for j in range(prep_words.size()):
					if words[i + j].to_lower() != prep_words[j]:
						matches = false
						break
				if matches:
					prep_index = i
					matched_prep = prep
					break
		if prep_index != -1:
			break

	# Step 7: Split into dobj, prep, iobj based on preposition
	if prep_index != -1:
		# Has preposition: "verb [dobj words] prep [iobj words]"
		result.prepstr = matched_prep

		var prep_word_count: int = matched_prep.split(" ").size()

		# Direct object: words before preposition
		if prep_index > 0:
			var dobj_words: Array[String] = []
			for i in range(prep_index):
				dobj_words.append(words[i])
			result.dobjstr = " ".join(dobj_words)

		# Indirect object: words after preposition
		if prep_index + prep_word_count < words.size():
			var iobj_words: Array[String] = []
			for i in range(prep_index + prep_word_count, words.size()):
				iobj_words.append(words[i])
			result.iobjstr = " ".join(iobj_words)
	else:
		# No preposition: all words are direct object
		if words.size() > 0:
			result.dobjstr = " ".join(words)

	# Step 8: Resolve objects
	result.dobj = _resolve_object(result.dobjstr, actor, location)
	result.iobj = _resolve_object(result.iobjstr, actor, location)

	return result


## Expand built-in shortcuts like ", :, ;
static func _expand_shortcuts(text: String) -> String:
	"""Replace shortcut prefixes with full commands.

	Args:
		text: Command string that may start with ", :, or ;

	Returns:
		Expanded command string
	"""
	if text.is_empty():
		return text

	var first_char: String = text[0]
	match first_char:
		"\"":
			return "say " + text.substr(1).strip_edges()
		":":
			return "emote " + text.substr(1).strip_edges()
		";":
			return "eval " + text.substr(1).strip_edges()

	return text


## Tokenize a command string with quote and backslash support
static func _tokenize(text: String) -> Array[String]:
	"""Break command into words, respecting quoted strings.

	Rules (from LambdaMOO spec):
	- Words separated by spaces
	- Double-quotes group words together
	- Backslash escapes next character (including quotes and backslashes)

	Args:
		text: Command string to tokenize

	Returns:
		Array of word strings

	Example:
		_tokenize('foo "bar mumble" baz" "fr"otz" bl"o"rt')
		→ ["foo", "bar mumble", "baz frotz", "blort"]
	"""
	var words: Array[String] = []
	var current_word: String = ""
	var in_quotes: bool = false
	var escape_next: bool = false

	for i in range(text.length()):
		var ch: String = text[i]

		if escape_next:
			# Backslash escape: add character literally
			current_word += ch
			escape_next = false
		elif ch == "\\":
			# Start escape sequence
			escape_next = true
		elif ch == "\"":
			# Toggle quote mode (but don't add the quote itself)
			in_quotes = !in_quotes
		elif ch == " " and !in_quotes:
			# Space outside quotes: end current word
			if current_word.length() > 0:
				words.append(current_word)
				current_word = ""
		else:
			# Regular character: add to current word
			current_word += ch

	# Add final word if any
	if current_word.length() > 0:
		words.append(current_word)

	return words


## Resolve an object string to a WorldObject or special ID
static func _resolve_object(objstr: String, actor: WorldObject, location: WorldObject) -> Variant:
	"""Match an object string to a WorldObject using MOO matching rules.

	Resolution priority:
	1. Empty string → NOTHING (#-1)
	2. "#123" format → Lookup by ID (if exists)
	3. "me" → actor
	4. "here" → location
	5. Search in location contents (if location provided)
	6. Search in actor inventory (if actor provided)
	7. Global search as fallback

	Matching uses prefix matching and aliases:
	- Exact matches preferred over prefix matches
	- Multiple matches → AMBIGUOUS_MATCH (#-2)
	- No matches → FAILED_MATCH (#-3)

	Args:
		objstr: Object name string to resolve
		actor: The actor executing the command (for "me" and inventory)
		location: Current location (for scoped search)

	Returns:
		WorldObject if found, or special ID string (#-1, #-2, #-3)
	"""
	# Empty string → NOTHING
	if objstr.is_empty():
		return NOTHING

	# Object number format: #123
	if objstr.begins_with("#"):
		var obj: WorldObject = WorldKeeper.get_object(objstr)
		if obj != null:
			return obj
		else:
			return FAILED_MATCH  # Invalid object ID

	# Special keywords
	var objstr_lower: String = objstr.to_lower()
	if objstr_lower == "me" and actor != null:
		return actor
	if objstr_lower == "here" and location != null:
		return location

	# Build search scope: location contents + actor inventory
	var candidates: Array[WorldObject] = []

	if location != null:
		candidates.append_array(location.get_contents())

	if actor != null:
		candidates.append_array(actor.get_contents())

	# If no local scope, fall back to global search
	if candidates.size() == 0:
		candidates = WorldKeeper.get_all_objects()

	# Match against candidates
	var exact_matches: Array[WorldObject] = []
	var prefix_matches: Array[WorldObject] = []

	for candidate in candidates:
		var match_result: int = _match_object_name(objstr, candidate)
		if match_result == 2:  # Exact match
			exact_matches.append(candidate)
		elif match_result == 1:  # Prefix match
			prefix_matches.append(candidate)

	# Prefer exact matches over prefix matches
	var matches: Array[WorldObject] = exact_matches if exact_matches.size() > 0 else prefix_matches

	if matches.size() == 0:
		return FAILED_MATCH
	elif matches.size() == 1:
		return matches[0]
	else:
		return AMBIGUOUS_MATCH


## Match an object name string against a WorldObject
static func _match_object_name(search: String, obj: WorldObject) -> int:
	"""Check if search string matches object's name or aliases.

	Args:
		search: The search string to match
		obj: The WorldObject to test against

	Returns:
		2 if exact match (case-insensitive)
		1 if prefix match
		0 if no match
	"""
	var search_lower: String = search.to_lower()

	# Check name
	var name_lower: String = obj.name.to_lower()
	if name_lower == search_lower:
		return 2  # Exact
	if name_lower.begins_with(search_lower):
		return 1  # Prefix

	# Check aliases
	for alias in obj.aliases:
		var alias_lower: String = alias.to_lower()
		if alias_lower == search_lower:
			return 2  # Exact
		if alias_lower.begins_with(search_lower):
			return 1  # Prefix

	return 0  # No match


## Match a verb string against a verb name pattern
static func match_verb(verb_input: String, verb_pattern: String) -> bool:
	"""Check if a verb input matches a verb name pattern with wildcards.

	Wildcard rules (from LambdaMOO spec):
	- No star: exact match required
	- Star in middle (foo*bar): matches any prefix >= length before star
	- Star at end (foo*): matches any string starting with prefix
	- Single star (*): matches anything

	Args:
		verb_input: The verb string from user input
		verb_pattern: The verb name pattern (may contain *)

	Returns:
		true if verb_input matches verb_pattern

	Examples:
		match_verb("look", "look") → true
		match_verb("l", "look") → false
		match_verb("foo", "foo*bar") → true (matches prefix before *)
		match_verb("foobar", "foo*bar") → true
		match_verb("foo", "foo*") → true
		match_verb("foobar", "foo*") → true
		match_verb("anything", "*") → true
	"""
	var input_lower: String = verb_input.to_lower()
	var pattern_lower: String = verb_pattern.to_lower()

	# Special case: single star matches everything
	if pattern_lower == "*":
		return true

	# No wildcard: exact match
	if "*" not in pattern_lower:
		return input_lower == pattern_lower

	# Star at end: prefix match
	if pattern_lower.ends_with("*"):
		var prefix: String = pattern_lower.substr(0, pattern_lower.length() - 1) #FIXME: W 0:00:02:198   The variable "prefix" is declared below in the parent block. <GDScript Error>CONFUSABLE_LOCAL_DECLARATION <GDScript Source>command_parser.gd:431

		return input_lower.begins_with(prefix)

	# Star in middle: match prefix up to star
	var star_pos: int = pattern_lower.find("*")
	var prefix: String = pattern_lower.substr(0, star_pos)
	var suffix: String = pattern_lower.substr(star_pos + 1)

	# Input must be at least as long as the prefix
	if input_lower.length() < prefix.length():
		return false

	# Input must start with prefix
	if not input_lower.begins_with(prefix):
		return false

	# If there's a suffix, input must end with it
	if suffix.length() > 0:
		return input_lower.ends_with(suffix)

	return true


## Get the preposition set name for a given preposition
static func get_prep_set(prep: String) -> String:
	"""Find which preposition set a given preposition belongs to.

	Args:
		prep: A preposition string (e.g., "in", "into", "with")

	Returns:
		The set name (e.g., "in front of") or empty string if not found
	"""
	var prep_lower: String = prep.to_lower()

	for set_name in PREPOSITIONS.keys():
		if prep_lower in PREPOSITIONS[set_name]:
			return set_name

	return ""


## Check if a preposition matches a verb's preposition specifier
static func matches_prep_spec(found_prep: String, spec: String) -> bool:
	"""Test if a found preposition matches a verb's preposition specifier.

	Specifier types:
	- "none": No preposition allowed (found_prep must be empty)
	- "any": Any preposition accepted (or none)
	- Set name: found_prep must be in that preposition set

	Args:
		found_prep: The preposition found in the command (may be empty)
		spec: The verb's preposition specifier

	Returns:
		true if the preposition matches the specifier
	"""
	if spec == "none":
		return found_prep.is_empty()

	if spec == "any":
		return true

	# Check if found_prep is in the specified set
	if spec in PREPOSITIONS:
		if found_prep.is_empty():
			return false
		return found_prep in PREPOSITIONS[spec]

	return false
