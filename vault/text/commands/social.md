# Social Command Messages

Messages for social interaction commands (say, emote, examine, look).

## look

**success**: You look around.
**behavior**: {actor} looks around.
**no_location**: You are nowhere.

## say

**success**: You say, "{text}"
**missing_arg**: Say what?
**behavior**: {actor} says, "{text}"

## emote

**success**:
**missing_arg**: Emote what?
**behavior**: {actor} {text}

## examine

**success**:
**missing_arg**: Examine what?
**not_found**: You don't see '{target}' here.
**behavior**: {actor} examines {target}.
