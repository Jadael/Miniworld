import os
import re
import random
from datetime import datetime
from collections import defaultdict
from markdown_utils import MarkdownVault

class World:
    _instance = None
    
    @classmethod
    def get_instance(cls):
        """Get the singleton instance of the World"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
        
    def __init__(self):
        """Initialize the world state"""
        # Record as singleton instance
        World._instance = self
        
        self.locations = {}
        self.current_location = None
        # Dictionary to store observers (characters) who should receive notifications
        self.observers = defaultdict(list)
        
        # Load templates from vault
        self.location_template = MarkdownVault.load_template("location_template")
        self.world_state_template = MarkdownVault.load_template("world_state_template")
        
        # Load or create locations
        self.initialize_locations()
        
        # Try to load saved world state
        self.load_world_state()
    
    def _apply_command_formatting(self, command):
        """Clean up and standardize command formatting"""
        # Skip empty commands
        if not command:
            return command
            
        # Trim whitespace
        command = command.strip()
        
        # Command format patterns to clean up
        patterns = [
            # Handle "**Command:** EMOTE SMILES" format
            (r'^\*\*Command\*\*:\s*(.*?)$', r'\1'),
            (r'^\[COMMAND\]\s*(.*?)$', r'\1'),
            (r'^\{COMMAND\}\s*(.*?)$', r'\1'),
            (r'^COMMAND:\s*(.*?)$', r'\1'),
            
            # Standardize capitalized commands
            (r'^EMOTE\s+(.*?)$', r'emote \1'),
            (r'^SAY\s+(.*?)$', r'say \1'),
            (r'^SHOUT\s+(.*?)$', r'shout \1'),
            (r'^GO TO\s+(.*?)$', r'go to \1'),
            (r'^GO\s+TO\s+(.*?)$', r'go to \1'),
            (r'^LOOK$', r'look'),
            (r'^NOTE\s+(.*?)$', r'note \1')
        ]
        
        # Apply each pattern
        for pattern, replacement in patterns:
            command = re.sub(pattern, replacement, command, flags=re.IGNORECASE)
        
        return command

    def initialize_locations(self):
        """Initialize locations from individual files in the world/locations directory"""
        # Create world and locations directories if they don't exist
        world_dir = "world"
        locations_dir = os.path.join(world_dir, "locations")
        os.makedirs(world_dir, exist_ok=True)
        os.makedirs(locations_dir, exist_ok=True)
        
        # Check if we have any locations
        location_files = [f for f in os.listdir(locations_dir) if f.endswith('.md')]
        
        # If no locations exist, create default ones
        if not location_files:
            # Create default locations
            self.create_default_locations(locations_dir)
            location_files = [f for f in os.listdir(locations_dir) if f.endswith('.md')]
        
        # Load each location from its file
        for filename in location_files:
            location_name = os.path.splitext(filename)[0]  # Remove .md extension
            file_path = os.path.join(locations_dir, filename)
            
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
                
                # Parse the location file
                description_pattern = r"# Description\s+(.*?)(?=\n#|\Z)"
                connections_pattern = r"# Connections\s+(.*?)(?=\n#|\Z)"
                objects_pattern = r"# Objects\s+(.*?)(?=\n#|\Z)"
                
                description_match = re.search(description_pattern, content, re.DOTALL)
                connections_match = re.search(connections_pattern, content, re.DOTALL)
                objects_match = re.search(objects_pattern, content, re.DOTALL)
                
                description = description_match.group(1).strip() if description_match else "No description available."
                connections = []
                objects = {}
                
                if connections_match:
                    connections_text = connections_match.group(1).strip()
                    # Parse connections from bulleted list
                    for line in connections_text.split('\n'):
                        if line.strip().startswith('- '):
                            connection = line.strip()[2:].strip()
                            connections.append(connection)
                
                if objects_match:
                    objects_text = objects_match.group(1).strip()
                    # Parse objects from bulleted list
                    for line in objects_text.split('\n'):
                        if line.strip().startswith('- '):
                            # Extract object name and state
                            obj_line = line.strip()[2:].strip()
                            if ': ' in obj_line:
                                obj_name, obj_state = obj_line.split(': ', 1)
                                objects[obj_name.strip()] = obj_state.strip()
                
                self.locations[location_name] = {
                    "description": description,
                    "connections": connections,
                    "characters": [],
                    "objects": objects
                }
    
    def save_world_state(self):
        """Save the current world state to a markdown file"""
        # Create world state directory if it doesn't exist
        world_dir = "world"
        state_file = os.path.join(world_dir, "world_state.md")
        os.makedirs(world_dir, exist_ok=True)
        
        # Format the current time
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Track all characters
        all_characters = []
        for location, data in self.locations.items():
            all_characters.extend(data.get("characters", []))
        
        # Format character locations
        character_locations = ""
        for character in sorted(set(all_characters)):
            location = self.get_character_location(character)
            character_locations += f"- {character}: {location}\n"
        
        # Format object states
        object_states = ""
        for location, data in self.locations.items():
            objects = data.get("objects", {})
            if objects:
                object_states += f"### {location}\n"
                for obj_name, state in objects.items():
                    object_states += f"- {obj_name}: {state}\n"
        
        # Fill template with data
        template_data = {
            "timestamp": timestamp,
            "character_locations": character_locations,
            "object_states": object_states
        }
        content = MarkdownVault.fill_template(self.world_state_template, template_data)
        
        # Write the file - FIX: Add explicit UTF-8 encoding
        with open(state_file, "w", encoding="utf-8") as f:
            f.write(content)

    def load_world_state(self):
        """Load world state from the markdown file if it exists"""
        world_dir = "world"
        state_file = os.path.join(world_dir, "world_state.md")
        
        if not os.path.exists(state_file):
            return False
        
        try:
            with open(state_file, "r", encoding="utf-8") as f:
                content = f.read()
            
            # Parse character locations
            char_section = re.search(r"## Character Locations\n(.*?)(?=\n\n|\n##|\Z)", content, re.DOTALL)
            if char_section:
                char_lines = char_section.group(1).strip().split("\n")
                for line in char_lines:
                    if line.startswith("- "):
                        parts = line[2:].split(": ", 1)
                        if len(parts) == 2:
                            character, location = parts
                            # Check if location exists before placing character
                            if location in self.locations:
                                # Add to location without saving state again (avoid recursion)
                                if character not in self.locations[location]["characters"]:
                                    self.locations[location]["characters"].append(character)
            
            # Parse object states
            obj_section = re.search(r"## Object States\n(.*?)(?=\n\n|\Z)", content, re.DOTALL)
            if obj_section:
                # Split into location sections
                loc_sections = re.findall(r"### (.*?)\n(.*?)(?=###|\Z)", 
                                        obj_section.group(0), re.DOTALL)
                
                for location, obj_content in loc_sections:
                    location = location.strip()
                    obj_lines = obj_content.strip().split("\n")
                    for line in obj_lines:
                        if line.startswith("- "):
                            parts = line[2:].split(": ", 1)
                            if len(parts) == 2:
                                obj_name, state = parts
                                # Update or add object
                                self.add_object_to_location(location, obj_name, state)
            
            return True
        except Exception as e:
            print(f"Error loading world state: {e}")
            return False
    
    def create_default_locations(self, locations_dir):
        """Create default location files"""
        # Living Room
        living_room_data = {
            "description": "A cozy living room with a comfortable sofa and a coffee table. There's a bookshelf against one wall and a window overlooking a garden.",
            "connections": "- Kitchen\n- Bedroom"
        }
        
        living_room_content = MarkdownVault.fill_template(self.location_template, living_room_data)
        with open(os.path.join(locations_dir, "Living Room.md"), "w") as f:
            f.write(living_room_content)
        
        # Kitchen
        kitchen_data = {
            "description": "A functional kitchen with modern appliances. There's a stove, refrigerator, and sink.",
            "connections": "- Living Room",
            "objects": "- stove: off\n- refrigerator: contains food\n- sink: clean"
        }
        
        kitchen_content = MarkdownVault.fill_template(self.location_template, kitchen_data)
        with open(os.path.join(locations_dir, "Kitchen.md"), "w") as f:
            f.write(kitchen_content)
        
        # Bedroom
        bedroom_data = {
            "description": "A peaceful bedroom with a bed and a window overlooking a garden. There's a small desk and a chair in the corner.",
            "connections": "- Living Room",
            "objects": "- bed: made\n- desk: tidy"
        }
        
        bedroom_content = MarkdownVault.fill_template(self.location_template, bedroom_data)
        with open(os.path.join(locations_dir, "Bedroom.md"), "w") as f:
            f.write(bedroom_content)
    
    # Update the register_observer method in world.py
    def register_observer(self, character_name, callback):
        """Register a callback for a character to receive world events"""
        from core.event_bus import EventBus
        
        # Get the event bus and register with it
        event_bus = EventBus.get_instance()
        event_bus.register(character_name, callback)
    
    def notify_location(self, location, event_type, description, data=None):
        """Notify all characters in a location about an event"""
        if data is None:
            data = {}
        
        # Always include location in data
        if "location" not in data:
            data["location"] = location
        
        # Add event description if not already present
        if "description" not in data:
            data["description"] = description
        
        # Add observer_locations to data for efficient filtering
        observer_locations = {}
        for loc_name, loc_data in self.locations.items():
            for character in loc_data.get("characters", []):
                observer_locations[character] = loc_name
        
        data["observer_locations"] = observer_locations
        
        # Use the event dispatcher to send the event
        from core.event_dispatcher import EventDispatcher
        dispatcher = EventDispatcher.get_instance()
        dispatcher.dispatch_event(event_type, data)
        
    def _apply_command_aliases(self, command):
        """Apply command aliases to convert aliased commands to canonical form"""
        try:
            # Load aliases from the vault
            aliases_md = MarkdownVault.load_settings("command_aliases")
            aliases = MarkdownVault.parse_aliases(aliases_md)
            
            # Lowercase for comparison
            command_lower = command.lower().strip()
            
            # Check each alias 
            for alias, canonical in aliases.items():
                alias_lower = alias.lower()
                
                # Check if command starts with this alias
                if command_lower.startswith(alias_lower + " ") or command_lower == alias_lower:
                    # Replace only the alias part, preserve the rest of the command
                    remainder = command[len(alias):].strip()
                    return f"{canonical} {remainder}".strip()
                    
        except Exception as e:
            print(f"Warning: Could not apply command aliases: {str(e)}")
        
        # Return original command if no alias matched or if there was an error
        return command

    def process_command(self, actor, command, original_reason=None):
        """Process a command from an actor and return the result"""
        # Get the actor's current location
        actor_location = self.get_character_location(actor)
        if not actor_location:
            return {"success": False, "message": f"Error: {actor} is not in the world."}
        
        # Clean up and standardize command formatting
        command = self._apply_command_formatting(command)
        
        # Trim whitespace
        command = command.strip()
        
        # Stage 1: Pre-process to remove command markers and formatting
        # Handle patterns like "**COMMAND**: SAY Hello!" or "[COMMAND] SAY Hello"
        command_marker_pattern = r'^(?:\*\*COMMAND\*\*:|\[COMMAND\]|\{COMMAND\}|COMMAND:)\s*(.*?)$'
        command_match = re.search(command_marker_pattern, command, re.IGNORECASE)
        if command_match:
            command = command_match.group(1).strip()
        
        # Stage 2: Check for emote patterns
        # Classic MOO emote format: :waves hello
        if command.startswith(':') and len(command) > 1:
            return self.handle_emote_command(actor, command[1:].strip(), original_reason)
        
        # Asterisk-wrapped emote format: *waves hello*
        if (command.startswith('*') and command.endswith('*') and len(command) > 2):
            return self.handle_emote_command(actor, command[1:-1].strip(), original_reason)
        
        # Stage 3: Check for prefixxed quote mark as a shorthand for SAY
        # Example: "Hello!" -> interpreted as "say Hello!"
        #if (command.startswith('"') and 
        #    len(command.strip()) > 2 and  # Ensure it's not just empty quotes
        #    ' ' not in command.strip('"\' ')):  # No spaces outside quotes
        #    command = f"""say {command.strip('"')}"""
        
        # Stage 4: Check for character dialogue patterns
        # Example: "John says, "Hello!"" or "John: "Hello!""
        dialogue_pattern = r'^(?:.*?says?[,:]\s*|.*?[:]\s*)["\'](.*?)[\'\"]$'
        dialogue_match = re.search(dialogue_pattern, command, re.IGNORECASE)
        if dialogue_match:
            command = f"say {dialogue_match.group(1)}"
        
        # Lowercase for easier parsing while preserving the original for message content
        command_lower = command.lower().strip()
        
        # Stage 5: Handle "say:" and "emote:" formats
        if command_lower.startswith("say:"):
            command_lower = "say " + command_lower[4:].strip()
            command = "say " + command[4:].strip()  # Update original command too
        elif command_lower.startswith("emote:"):
            command_lower = "emote " + command_lower[6:].strip()
            command = "emote " + command[6:].strip()  # Update original command too
        
        # Stage 6: Remove surrounding quotes from say commands if present
        if command_lower.startswith("say "):
            message_part = command[4:].strip()
            if (message_part.startswith('"') and message_part.endswith('"')) or \
            (message_part.startswith("'") and message_part.endswith("'")):
                message = message_part[1:-1]  # Remove surrounding quotes
                command = "say " + message
                command_lower = command.lower()
        
        # Stage 7: Apply command aliases (convert aliased commands to canonical forms)
        command = self._apply_command_aliases(command)
        command_lower = command.lower().strip()
        
        # Process different command types - pass original_reason to handlers
        if command_lower == "look":
            result = self.handle_look_command(actor, original_reason)
        elif command_lower.startswith("go to "):
            destination = command[6:].strip()
            result = self.handle_go_command(actor, destination, original_reason)
        elif command_lower.startswith("fly to "):
            destination = command[7:].strip()
            result = self.handle_fly_command(actor, destination, original_reason)
        elif command_lower.startswith("say "):
            message = command[4:].strip()
            result = self.handle_say_command(actor, message, original_reason)
        elif command_lower.startswith("emote "):
            action = command[6:].strip()
            result = self.handle_emote_command(actor, action, original_reason)
        elif command_lower.startswith("shout "):
            message = command[6:].strip()
            result = self.handle_shout_command(actor, message, original_reason)
        elif command_lower.startswith("examine "):
            target = command[8:].strip()
            result = self.handle_examine_command(actor, target, original_reason)
        elif command_lower.startswith("dig "):
            location_name = command[4:].strip()
            result = self.handle_dig_command(actor, location_name, original_reason)
        elif command_lower.startswith("describe "):
            description = command[9:].strip()
            result = self.handle_describe_command(actor, description, original_reason)
        elif command_lower.startswith("note "):
            # This is a special command for miniminds to create notes
            # The world doesn't handle this directly
            result = {"success": True, "message": f"{actor} makes a mental note."}
        elif command_lower.startswith("dream"):
            result = self.handle_dream_command(actor, original_reason)
        else:
            # Invalid command format
            result = {"success": False, "message": f"⚠ Could not parse: {command}\n- Did you use the command correctly?"}
        
        # Special handling for error results - only notify the actor, not everyone in location
        if not result["success"]:
            # Create error data
            error_data = {
                "actor": actor,
                "location": actor_location,
                "message": result["message"],
                "description": f"{actor} {result['message']}",
                "type": "error",
                "is_error": True
            }
            
            # Add observer_locations to data for filtering
            observer_locations = {}
            for loc_name, loc_data in self.locations.items():
                for character in loc_data.get("characters", []):
                    observer_locations[character] = loc_name
            
            error_data["observer_locations"] = observer_locations
            
            # Use the event dispatcher directly
            try:
                from core.event_dispatcher import EventDispatcher
                dispatcher = EventDispatcher.get_instance()
                
                # Special error event handling - only notify the actor
                if actor in dispatcher.observers:
                    callback = dispatcher.observers[actor]
                    callback("error", result["message"], error_data)
            except ImportError:
                # Fallback if event dispatcher is not available
                pass
        
        # Return the result normally for command processing
        return result
    
    # Command handlers
    def handle_look_command(self, actor, original_reason=None):
        # Implementation remains the same as in original world.py
        location = self.get_character_location(actor)
        if not location:
            return {"success": False, "message": "You are nowhere."}
                    
        location_data = self.get_location_data(location)
        description = location_data.get("description", "Nothing to see here.")
                
        # Construct a description of the location and its contents
        prose = f"You LOOK around at 📍{location} and see:\n{description}"
        
        # Fake an "object" system for now so the agents are less confused
        prose += "\n🔧There are no objects to interact with here."
                
        # Show connections
        connections = location_data.get("connections", [])
        if connections:
            if len(connections) == 1:
                prose += f"\n🔧You can GO TO {connections[0]} from here."
            else:
                conn_list = ", ".join(connections[:-1]) + " or " + connections[-1]
                prose += f"\n🔧You can GO TO {conn_list} from here."
        else:
            prose += "\n🔧You see no where to GO TO from here."
                
        # List characters in the location
        characters = location_data.get("characters", [])
        
        # Ensure characters list has no duplicates
        characters = list(set(characters))
        
        # Filter out the actor from the character list
        other_chars = [char for char in characters if char != actor]
        
        if other_chars:
            if len(other_chars) == 1:
                prose += f"\n👥{other_chars[0]} is here, and they will hear what you SAY or SHOUT and see what you EMOTE."
            else:
                char_list = ", ".join(other_chars[:-1]) + " and " + other_chars[-1]
                prose += f"\n👥{char_list} are here, and they will hear what you SAY or SHOUT and see what you EMOTE."
        else:
            prose += "\n👥You are alone here, no one will hear what you SAY or see what you EMOTE, but someone may hear you SHOUT."
        
        # Share this observation with all characters in the location
        observation = f"{actor} looks around the {location}."
        self.notify_location(location, "observation", observation, {
            "actor": actor,
            "action": "looked around",
            "location": location,
            "original_reason": original_reason or "Unknown"  # Include original reason
        })
        
        return {
            "success": True,
            "message": prose,
            "data": {
                "location": location,
                "description": description,
                "connections": connections,
                "characters": other_chars,
                "original_reason": original_reason or "Unknown"  # Include original reason
            }
        }
    
    def handle_dream_command(self, actor, original_reason=None):
        """Handle the 'dream' command for introspective memory synthesis"""
        location = self.get_character_location(actor)
        if not location:
            return {"success": False, "message": "You are nowhere."}
        
        # Create a simple success response - the actual work happens in CommandProcessor
        dream_msg = f"{actor} enters a dreamlike state, processing memories and insights."
        
        # Notify others in the location about the dreaming
        self.notify_location(location, "observation", dream_msg, {
            "actor": actor,
            "action": "entered a dreamlike state",
            "location": location,
            "original_reason": original_reason or "Introspection"
        })
        
        
        return {
            "success": True,
            "message": "You enter a dreamlike state, reflecting on your memories and experiences...",
            "data": {
                "location": location,
                "dream": True,
                "original_reason": original_reason
            }
        }
    
    def handle_go_command(self, actor, destination, original_reason=None):
        """Handle the 'go to' command"""
        current_location = self.get_character_location(actor)
        if not current_location:
            return {"success": False, "message": "You are nowhere."}
                
        # Check if destination exists - case-insensitive search
        destination_key = None
        for loc in self.locations.keys():
            if loc.lower() == destination.lower():
                destination_key = loc
                break
                    
        if not destination_key:
            return {"success": False, "message": f"There is no location called '{destination}'."}
        
        # Check if the destination is connected - case-insensitive search
        current_connections = self.locations.get(current_location, {}).get("connections", [])
        is_connected = False
        for conn in current_connections:
            if conn.lower() == destination.lower():
                is_connected = True
                destination_key = conn  # Use the proper case from connections
                break
                    
        if not is_connected:
            return {"success": False, "message": f"There is no direct path to GO TO '{destination}' from here."}
        
        # Create unified movement data
        movement_data = {
            "actor": actor,
            "origin": current_location,
            "destination": destination_key,
            "original_reason": original_reason,
            "type": "movement",
            "via": "moved"  # Indicate this is normal movement
        }
        
        # Create movement message
        movement_msg = f"{actor} goes from {current_location} to {destination_key}."
        
        # Move actor to the destination
        self.move_character(actor, destination_key)
        
        # Notify both locations about the movement
        self.notify_location(current_location, "movement", movement_msg, movement_data.copy())
        self.notify_location(destination_key, "movement", movement_msg, movement_data.copy())
        
        # Get description of new location for the actor
        look_result = self.handle_look_command(actor, original_reason)
        
        # For player, create a simplified message that reduces redundancy
        if actor[0] == "⚪":  # Assuming player has this special character
            response_message = f"You go to the {destination_key}.\n\n{look_result['message']}"
        else:
            response_message = f"You go to the {destination_key}.\n\n{look_result['message']}"
        
        return {
            "success": True,
            "message": response_message,
            "data": {
                "previous_location": current_location,
                "new_location": destination_key,
                "look_data": look_result["data"],
                "location_update": True,  # Flag to indicate location update needed
                "original_reason": original_reason,
                "movement_type": "walking"
            }
        }

    def handle_fly_command(self, actor, destination, original_reason=None):
        """Handle the 'fly to' command"""
        current_location = self.get_character_location(actor)
        if not current_location:
            return {"success": False, "message": "You are nowhere."}
                
        # Check if destination exists - case-insensitive search
        destination_key = None
        for loc in self.locations.keys():
            if loc.lower() == destination.lower():
                destination_key = loc
                break
                    
        if not destination_key:
            return {"success": False, "message": f"There is no location called '{destination}'."}
        
        # Create unified movement data
        movement_data = {
            "actor": actor,
            "origin": current_location,
            "destination": destination_key,
            "original_reason": original_reason,
            "type": "movement",
            "via": "flew"  # Indicate this is flying movement
        }
        
        # Create movement message
        movement_msg = f"{actor} flies to {destination_key} from {current_location}."
        
        # Move actor to the destination
        self.move_character(actor, destination_key)
        
        # Notify both locations about the movement
        self.notify_location(current_location, "movement", movement_msg, movement_data.copy())
        self.notify_location(destination_key, "movement", movement_msg, movement_data.copy())
        
        # Get description of new location for the actor
        look_result = self.handle_look_command(actor, original_reason)
        
        return {
            "success": True,
            "message": f"You fly to the {destination_key}.\n\n{look_result['message']}",
            "data": {
                "previous_location": current_location,
                "new_location": destination_key,
                "look_data": look_result["data"],
                "location_update": True,  # Flag to indicate location update needed
                "original_reason": original_reason,
                "movement_type": "flying"
            }
        }

    
    def handle_say_command(self, actor, message, original_reason=None):
        """Handle the 'say' command"""
        location = self.get_character_location(actor)
        if not location:
            return {"success": False, "message": "You are nowhere."}
        
        # Format for the actor's confirmation
        self_msg = f"You say: \"{message}\""
        
        # Create data for notification
        event_data = {
            "actor": actor,
            "message": message,
            "location": location,
            "original_reason": original_reason,
            "description": f"{actor} says: \"{message}\"" 
        }
        
        # Notify all characters in the location
        self.notify_location(location, "speech", f"{actor} says: \"{message}\"", event_data)
        
        return {
            "success": True,
            "message": self_msg,
            "data": event_data
        }
    

    def handle_shout_command(self, actor, message, original_reason=None):
        # Implementation remains the same as in original world.py
        # Get the actor's location for context
        location = self.get_character_location(actor)
        if not location:
            return {"success": False, "message": "You are nowhere."}
        
        # Clean up the message if it has quotes
        if message.startswith('"') and message.endswith('"'):
            message = message[1:-1]
        
        # Create the shout message format for others - include the actual message
        shout_msg = f"{actor} shouts: \"{message}\""
        
        # Create the shout message format for self
        self_msg = f"You shout: \"{message}\""
        
        # Track all characters who will hear this
        all_characters = set()
        for loc_data in self.locations.values():
            all_characters.update(loc_data.get("characters", []))
        
        # Remove any potential duplicates
        all_characters = list(all_characters)
        
        # Create detailed data for the event - explicitly include the message
        shout_data = {
            "actor": actor,
            "message": message,  # Store the actual message
            "origin_location": location,  # Origin location of the shout
            "location": location,  # Include location for consistency
            "heard_by": all_characters,  # List of all who heard
            "type": "shout",
            "original_reason": original_reason
        }
        
        # Notify all characters about the shout
        self.notify_location(location, "shout", shout_msg, shout_data)
        
        return {
            "success": True,
            "message": self_msg,  # Return special format for the shouter
            "data": {
                "location": location,
                "origin_location": location,
                "message": message,  # Include the message in data
                "heard_by": all_characters,
                "original_reason": original_reason
            }
        }
    
    def handle_examine_command(self, actor, target, original_reason=None):
        # Implementation remains the same as in original world.py
        location = self.get_character_location(actor)
        if not location:
            return {"success": False, "message": "You are nowhere."}
                
        location_data = self.get_location_data(location)
        
        # Check if target is a character
        characters = location_data.get("characters", [])
        for char in characters:
            if target.lower() == char.lower():
                if char == actor:
                    message = f"You examine yourself."
                else:
                    message = f"You examine {char}. Nothing special."
                        
                # Notify others in the location
                examine_msg = f"{actor} examines {char} carefully."
                self.notify_location(location, "observation", examine_msg, {
                    "actor": actor,
                    "target": char,
                    "action": "examined",
                    "original_reason": original_reason  # Include original reason
                })
                    
                return {
                    "success": True,
                    "message": message,
                    "data": {
                        "target_type": "character",
                        "target": char,
                        "original_reason": original_reason  # Include original reason
                    }
                }
        
        # If it's not a character, check if it's an object
        objects = location_data.get("objects", {})
        if target.lower() in [obj.lower() for obj in objects.keys()]:
            # Find the actual object name (preserving case)
            obj_name = next(obj for obj in objects.keys() if obj.lower() == target.lower())
            obj_state = objects[obj_name]
            
            message = f"You examine the {obj_name}. It appears to be {obj_state}."
            
            # Notify others in the location
            examine_msg = f"{actor} examines the {obj_name}."
            self.notify_location(location, "observation", examine_msg, {
                "actor": actor,
                "target": obj_name,
                "action": "examined",
                "original_reason": original_reason  # Include original reason
            })
            
            return {
                "success": True,
                "message": message,
                "data": {
                    "target_type": "object",
                    "target": obj_name,
                    "state": obj_state,
                    "original_reason": original_reason  # Include original reason
                }
            }
        
        # If it's neither a character nor an object, give a generic response
        message = f"You examine '{target}'. Nothing special."
        
        # Notify others in the location
        examine_msg = f"{actor} examines the {target}."
        self.notify_location(location, "observation", examine_msg, {
            "actor": actor,
            "target": target,
            "action": "examined",
            "original_reason": original_reason  # Include original reason
        })
        
        return {
            "success": True,
            "message": message,
            "data": {
                "target_type": "generic",
                "target": target,
                "original_reason": original_reason  # Include original reason
            }
        }
    
    def handle_emote_command(self, actor, action, original_reason=None):
        """Handle the 'emote' command for expressing physical actions"""
        location = self.get_character_location(actor)
        if not location:
            return {"success": False, "message": "You are nowhere."}
        
        # Format the emote for others to see
        emote_msg = f"{actor} {action}"
        
        # Format the emote for the actor
        self_msg = f"{actor} {action}"
        
        # Notify all characters in the location
        self.notify_location(location, "emote", emote_msg, {
            "actor": actor,
            "action": action,
            "location": location,
            "original_reason": original_reason or "Character expression"
        })
        
        return {
            "success": True,
            "message": self_msg,  # Return special format for the actor
            "data": {
                "location": location,
                "action": action,
                "original_reason": original_reason  # Pass the reason in the result data
            }
        }
    
    def handle_dig_command(self, actor, location_name, original_reason=None):
        """Handle the 'dig' command for creating new locations"""
        current_location = self.get_character_location(actor)
        if not current_location:
            return {"success": False, "message": "You are nowhere."}
        
        # Clean location name - remove quotes if present
        if (location_name.startswith('"') and location_name.endswith('"')) or \
           (location_name.startswith("'") and location_name.endswith("'")):
            location_name = location_name[1:-1]
        
        # Check if the location name already exists
        location_exists = False
        existing_location = None
        for loc in self.locations.keys():
            if loc.lower() == location_name.lower():
                location_exists = True
                existing_location = loc  # Preserve existing capitalization
                break
        
        # If location doesn't exist, create it with default description
        if not location_exists:
            # Create new location
            success = self.create_new_location(
                location_name,
                "This location's description has not been written by the Builder yet.",
                [current_location],  # Connection from new location back to current
                {}  # No objects initially
            )
            
            if not success:
                return {"success": False, "message": f"Failed to create location '{location_name}'."}
            
            # Add connection from current location to new location
            if location_name not in self.locations[current_location]["connections"]:
                self.locations[current_location]["connections"].append(location_name)
                # Update the current location file
                self.update_location_file(current_location)
            
            dig_msg = f"{actor} creates a new location: {location_name}."
            emote_msg = f"{actor} creates a new path to {location_name}."
            
            # Notify characters in the current location
            self.notify_location(current_location, "observation", emote_msg, {
                "actor": actor,
                "action": f"dug a path to {location_name}",
                "location": current_location,
                "original_reason": original_reason or "World building"
            })
            
            return {
                "success": True,
                "message": f"You create a new location called '{location_name}' connected to {current_location}.",
                "data": {
                    "location": current_location,
                    "new_location": location_name,
                    "original_reason": original_reason
                }
            }
        else:
            # If location exists but isn't connected to current location, add connection
            if existing_location not in self.locations[current_location]["connections"]:
                # Add connection from current location to existing location
                self.locations[current_location]["connections"].append(existing_location)
                self.update_location_file(current_location)
                
                # Add connection from existing location back to current location
                if current_location not in self.locations[existing_location]["connections"]:
                    self.locations[existing_location]["connections"].append(current_location)
                    self.update_location_file(existing_location)
                
                dig_msg = f"{actor} connects {current_location} to {existing_location}."
                
                # Notify characters in the current location
                self.notify_location(current_location, "observation", dig_msg, {
                    "actor": actor,
                    "action": f"connected {current_location} to {existing_location}",
                    "location": current_location,
                    "original_reason": original_reason or "Connection building"
                })
                
                return {
                    "success": True,
                    "message": f"You connect {current_location} to the existing location '{existing_location}'.",
                    "data": {
                        "location": current_location,
                        "existing_location": existing_location,
                        "original_reason": original_reason
                    }
                }
            else:
                # Location exists and is already connected
                return {
                    "success": False,
                    "message": f"A path to '{existing_location}' already exists from here."
                }
    
    def handle_describe_command(self, actor, description, original_reason=None):
        """Handle the 'describe' command for updating location descriptions"""
        location = self.get_character_location(actor)
        if not location:
            return {"success": False, "message": "You are nowhere."}
        
        # Clean description - remove quotes if present
        if (description.startswith('"') and description.endswith('"')) or \
           (description.startswith("'") and description.endswith("'")):
            description = description[1:-1]
        
        # Update the location description
        if location in self.locations:
            # Store the old description for the notification
            old_description = self.locations[location]["description"]
            
            # Update description
            self.locations[location]["description"] = description
            
            # Update the location file
            self.update_location_file(location)
            
            # Create notification message
            describe_msg = f"{actor} changes the description of {location}."
            
            # Notify characters in the location
            self.notify_location(location, "observation", describe_msg, {
                "actor": actor,
                "action": f"changed the description of {location}",
                "location": location,
                "original_reason": original_reason or "Improving description"
            })
            
            return {
                "success": True,
                "message": f"You set the description of {location} to: {description}",
                "data": {
                    "location": location,
                    "old_description": old_description,
                    "new_description": description,
                    "original_reason": original_reason
                }
            }
        else:
            return {
                "success": False,
                "message": f"Cannot update description of {location}. Location not found."
            }
    
    # Utility methods
    def is_valid_location(self, location):
        """Check if a location exists and is connected to the current location"""
        if location not in self.locations:
            return False
            
        # If this is a direct connection from current location, it's valid
        current_connections = self.locations.get(self.current_location, {}).get("connections", [])
        if location in current_connections:
            return True
            
        # Otherwise, not accessible from current location
        return False
    
    def get_location_data(self, location):
        """Get data for a specific location"""
        return self.locations.get(location, {"description": "Unknown location", "characters": [], "objects": {}})
    
    def get_random_location(self):
        """Get a random location from the world"""
        if not self.locations:
            return None
        return random.choice(list(self.locations.keys()))
    
    def get_character_location(self, character):
        """Find what location a character is in"""
        for location, data in self.locations.items():
            if character in data["characters"]:
                return location
        return None
    
    def add_character_to_location(self, character, location):
        """Add a character to a location"""
        if location in self.locations:
            # Check if character is already in this location
            if character not in self.locations[location]["characters"]:
                self.locations[location]["characters"].append(character)
            # Ensure no duplicates in the characters list
            self.locations[location]["characters"] = list(set(self.locations[location]["characters"]))
            
            # Save the world state after adding the character
            self.save_world_state()
    
    def remove_character_from_location(self, character, location):
        """Remove a character from a location"""
        if location in self.locations and character in self.locations[location]["characters"]:
            self.locations[location]["characters"].remove(character)
    
    def move_character(self, character, destination):
        """Move a character from their current location to a new destination"""
        # Find character's current location
        current_location = self.get_character_location(character)
        
        if current_location:
            # Remove from current location
            self.locations[current_location]["characters"].remove(character)
        
        # Add to new location
        if destination in self.locations:
            # First check if character is already in the destination
            if character not in self.locations[destination]["characters"]:
                self.locations[destination]["characters"].append(character)
            
            # Ensure no duplicates in the character list
            self.locations[destination]["characters"] = list(set(self.locations[destination]["characters"]))
                
            # Update current location if the player is moving
            if character == "Player":
                self.current_location = destination
            
            # Save the world state after the move
            self.save_world_state()
                
    def add_object_to_location(self, location, object_name, object_state=None):
        """Add an object to a location with optional state"""
        if location in self.locations:
            self.locations[location]["objects"][object_name] = object_state or "normal"
            return True
        return False

    def update_object_state(self, location, object_name, new_state):
        """Update the state of an object in a location"""
        if (location in self.locations and 
            object_name in self.locations[location]["objects"]):
            self.locations[location]["objects"][object_name] = new_state
            return True
        return False

    def get_object_state(self, location, object_name):
        """Get the state of an object in a location"""
        if (location in self.locations and 
            object_name in self.locations[location]["objects"]):
            return self.locations[location]["objects"][object_name]
        return None

    def get_objects_in_location(self, location):
        """Get all objects in a location"""
        if location in self.locations:
            return self.locations[location]["objects"]
        return {}
    
    def create_new_location(self, name, description, connections=None, objects=None):
        """Create a new location with the given parameters"""
        # Check if location already exists
        if name in self.locations:
            return False
            
        # Format connections as markdown bullet list
        connections_md = ""
        if connections:
            for conn in connections:
                connections_md += f"- {conn}\n"
                
        # Format objects as markdown bullet list
        objects_md = ""
        if objects:
            for obj_name, obj_state in objects.items():
                objects_md += f"- {obj_name}: {obj_state}\n"
                
        # Create template data
        location_data = {
            "description": description,
            "connections": connections_md
        }
        
        if objects:
            location_data["objects"] = objects_md
            
        # Fill template
        content = MarkdownVault.fill_template(self.location_template, location_data)
        
        # Create location file
        locations_dir = os.path.join("world", "locations")
        os.makedirs(locations_dir, exist_ok=True)
        
        with open(os.path.join(locations_dir, f"{name}.md"), "w") as f:
            f.write(content)
            
        # Add to locations dictionary
        self.locations[name] = {
            "description": description,
            "connections": connections or [],
            "characters": [],
            "objects": objects or {}
        }
        
        # Update connections for other locations
        if connections:
            for conn in connections:
                if conn in self.locations and name not in self.locations[conn]["connections"]:
                    self.locations[conn]["connections"].append(name)
                    
                    # Update the connection file
                    self.update_location_file(conn)
                    
        return True
    
    def update_location_file(self, location_name):
        """Update a location file with current data"""
        if location_name not in self.locations:
            return False
            
        location_data = self.locations[location_name]
        
        # Format connections as markdown bullet list
        connections_md = ""
        for conn in location_data.get("connections", []):
            connections_md += f"- {conn}\n"
            
        # Format objects as markdown bullet list
        objects_md = ""
        for obj_name, obj_state in location_data.get("objects", {}).items():
            objects_md += f"- {obj_name}: {obj_state}\n"
            
        # Create template data
        template_data = {
            "description": location_data.get("description", "No description available."),
            "connections": connections_md
        }
        
        if objects_md:
            template_data["objects"] = objects_md
            
        # Fill template
        content = MarkdownVault.fill_template(self.location_template, template_data)
        
        # Write location file
        locations_dir = os.path.join("world", "locations")
        
        with open(os.path.join(locations_dir, f"{location_name}.md"), "w") as f:
            f.write(content)
            
        return True
