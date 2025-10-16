# Observable Action Behaviors

Templates for broadcasting observable actions to other players.
Use {actor} for the character name, {target} for objects/people.

## General Actions

**look**: {actor} looks around.
**examine**: {actor} examines {target}.

## Speech and Expression

**say**: {actor} says, "{text}"
**emote**: {actor} {text}

## Memory Actions

**think**: {actor} pauses in thought.
**dream**: {actor} becomes still, eyes unfocused, lost in thought.
**note**: {actor} jots something down.
**recall**: {actor} pauses to recall...

## Self-Modification

**set_profile**: {actor} pauses in deep contemplation.
**set_description**: {actor} adjusts their appearance.

## Movement

**depart**: {actor} leaves to {exit}.
**arrive**: {actor} arrives from {exit}.
**teleport_depart**: {actor} vanishes in a swirl of light.
**teleport_arrive**: {actor} appears in a swirl of light.

## Building

**dig**: {actor} digs a new room: {room_name}
**create_exit**: {actor} creates an exit '{exit_name}' leading to {destination_name}.
