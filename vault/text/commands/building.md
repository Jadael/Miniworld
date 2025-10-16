# Building Command Messages

## dig
**missing_arg**: Usage: @dig <room name>
**success**: Created room: {room_name} [{room_id}]\nUse @exit to connect it to other rooms.

## exit
**missing_arg**: Usage: @exit <exit name> to <destination room name or #ID>
**no_to_keyword**: Usage: @exit <exit name> to <destination>
**room_not_found**: Cannot find room: {destination}
**not_a_room**: {destination} is not a room.
**no_location**: You are nowhere.
**no_location_component**: This location cannot have exits.
**success**: Created exit: {exit_name} → {destination_name} [{destination_id}]

## teleport
**missing_arg**: Usage: @teleport <room name, #ID, or character name>
**not_a_room**: {destination} [{destination_id}] is not a room
**character_not_in_location**: {character} is not in a valid location
**not_found**: Cannot find room or character: {destination}\n{room_list}
**not_valid_location**: {destination} is not a valid location

## save
**success**: World saved to vault!\nCheck the console output for details.
**failure**: Failed to save world to vault.\nCheck the console for errors.
