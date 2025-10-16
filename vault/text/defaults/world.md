# World Default Strings

Default descriptions and fallback text for world objects.

---

## Object Defaults

**object_description**: You see nothing special.
_Default description for objects without a custom description_

**object_description_place**: You see nothing special about this place.
_Default description for locations/rooms_

---

## Nexus

**nexus_name**: the nexus
**nexus_description**: An endless expanse of possibility, the container of all containers.

---

## Root Room

**root_room_name**: The Genesis Chamber
**root_room_description**: A featureless white room that seems to exist outside of space and time. This is where all things begin.

---

## Notes

- These provide fallback values when objects don't have custom descriptions
- The nexus and root room are created on first world initialization
- Individual objects override these via their `description` property
