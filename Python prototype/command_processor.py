import tkinter as tk
from tkinter import messagebox
from gui_utils import add_world_event, add_player_view, add_command_to_player_view, set_status, format_structured_event
import re
from collections import deque
from datetime import datetime, timedelta
import random
from minimind import Minimind

class CommandProcessor:
    def __init__(self, gui):
        self.gui = gui
        # Track processed events to avoid duplication
        self.processed_events = set()
        # Keep a history of recent events for deduplication
        self.recent_events = deque(maxlen=30)  # Maintain last 30 events
        # Last event time to help with deduplication
        self.last_event_time = datetime.now()

    def _handle_dream_command(self, minimind, reason=None, prompt=None, system_prompt=None, llm_response=None):
        """Handle the dream command for deeper memory synthesis and reflection"""
        # Get the memories count from settings or use default
        dream_memories_count = getattr(self.gui, 'dream_memories_count', 256)
        
        # Create structured event
        structured_event = format_structured_event(
            "dream", 
            minimind.name, 
            f"enters a dreamlike state, reflecting on past experiences",
            minimind.location,
            reason if reason else "Memory synthesis through dreaming",
            None,
            "Synthesizing memories into guidance"
        )
        
        # Log the action to world events
        add_world_event(self.gui, f"{minimind.name} enters a dreamlike state, reflecting deeply.", structured_event)
        
        # Get a larger set of memories than normal
        memories = minimind.get_memories(dream_memories_count)
        
        # Create the dream prompt with salted memories
        dream_prompt = self._create_dream_prompt(minimind, memories)
        
        # Use a specific system prompt for dreams
        if reason:
            dream_system_prompt = f"You are telling the story of a character's memories, who wants: '{reason}'. "
        else:
            dream_system_prompt = f"You are telling the story of a character's memories. "
        dream_system_prompt += """Your goal is to create a dream-like reflection of the entirety of their experiences and behaviors (both good and bad). Be creative, insightful, and focus on helping the character understand things not already present in their experiences, and posing counterfactuals and letting the consequences play out is encouraged. Go crazy, freely adding, removing, or changing any details you want to make your points more visceral and illustrative. Your response should be written as a first-person dream narrative that feels authentic to the character. Please go on a thorough journey through everything that has happened, as a dream. Do not repeat any previous dreams."""
        
        # Process the dream
        try:
            # Use a simpler, more direct prompt for the dream interpretation with custom system prompt
            dream_result = self.gui.llm.query(dream_prompt, system=dream_system_prompt)
            
            # Clean up the response - remove think blocks
            cleaned_result = re.sub(r'<think>.*?</think>', '', dream_result, flags=re.DOTALL)
            
            # Create a dream note
            title = "Dream"
            content = cleaned_result.strip() or dream_result  # Fallback if cleaning fails
            note_reason = reason if reason else "Introspection"
            
            # Save as a note - will overwrite previous dreams with same title
            minimind.create_note(title, content, note_reason)
            
            # Record the response as a memory
            result_message = f"You've had a dream: {content}"
            minimind.add_response_memory("dream", result_message, reason)
            
            # Create a result object
            result = {
                "success": True,
                "message": result_message,
                "data": {
                    "original_reason": reason,
                    "dream_content": content
                }
            }
            
            # Store the command and result
            minimind.store_last_command("dream", result)
            
            # Log to player view only if the player is in the same location as the minimind
            player_location = self.gui.world.get_character_location(self.gui.player_name)
            minimind_location = self.gui.world.get_character_location(minimind.name)
            
            if player_location == minimind_location:
                add_player_view(self.gui, f"{minimind.name} appears to be dreaming.")
            
            # Calculate TU cost - dreaming is intensive, so make it a bit higher than basic commands
            tu_cost = 5  # Higher cost than recall (2) - dreams are deep work!
            self.gui.turn_manager.add_time_units(minimind.name, tu_cost)
            
            # Display TU information
            add_world_event(self.gui, f"{minimind.name} spent {tu_cost} TU dreaming. New total: {self.gui.turn_manager.time_units[minimind.name]}")
            
            # Update turn order display
            self.gui.update_turn_order_display()
            
            # Turn complete
            self.gui.turn_in_progress = False
            
            # Process next turn
            self.gui.root.after(100, self.gui.process_next_turn)
            
            print("Dream result:")
            print(result)
            
            # After processing the dream and getting the result, save turn details
            try:
                minimind.save_turn_details(
                    dream_prompt,  # Use the dream prompt
                    dream_system_prompt, 
                    dream_result, 
                    "dream", 
                    result
                )
            except Exception as e:
                print(f"Error saving turn details: {str(e)}")
            
            return result
            
        except Exception as e:
            # Handle errors
            error_message = f"Error during dream processing: {str(e)}"
            add_world_event(self.gui, f"Failed: {minimind.name} {error_message}")
            
            # Failed commands still cost TU
            tu_cost = 1
            self.gui.turn_manager.add_time_units(minimind.name, tu_cost)
            add_world_event(self.gui, f"{minimind.name} spent {tu_cost} TU. New total: {self.gui.turn_manager.time_units[minimind.name]}")
            
            # Update turn order display
            self.gui.update_turn_order_display()
            
            # Turn complete
            self.gui.turn_in_progress = False
            
            # Process next turn
            self.gui.root.after(100, self.gui.process_next_turn)
            
            return {
                "success": False,
                "message": error_message
            }
    
    def _create_dream_prompt(self, minimind, memories):
        """Create a prompt for dream analysis of memories with dreamlike random ordering"""
        # Filter out memories related to dreams to avoid feedback loops
        filtered_memories = []
        for memory in memories:
            # Skip memories contain dream responses
            memory_lower = memory.lower()
            if "you've had a dream: " in memory_lower:
                continue
            filtered_memories.append(memory)
        
        # Use filtered memories for the rest of the function
        memories = filtered_memories
        
        # Calculate how many random memories to include- for now, twice as many as normal memories
        num_random = max(1, len(memories) * 2)
        
        # Get a larger set of memories
        all_memories = minimind.get_memories(4096)  # Arbitrary large number
        
        # Skip memories contain dream responses
        filtered_all_memories = []
        for memory in all_memories:
            memory_lower = memory.lower()
            if "you've had a dream: " in memory_lower:
                continue
            filtered_all_memories.append(memory)
        
        all_memories = filtered_all_memories
        
        # The first len(memories) are the same as our 'memories' parameter
        older_memories = all_memories[len(memories):]
        
        # Randomly sample from older memories
        sampled_old_memories = []
        if older_memories:
            sampled_old_memories = random.sample(older_memories, min(num_random, len(older_memories)))
        
        # Combine all memories
        combined_memories = memories + sampled_old_memories
        
        # CHANGE: Create small chunks of 2-4 memories each
        # This keeps some local chronology but creates a non-linear overall narrative
        memory_chunks = []
        i = 0
        while i < len(combined_memories):
            chunk_size = random.randint(2, 4)  # Random chunk size for more dream-like effect
            chunk = combined_memories[i:i+chunk_size]
            memory_chunks.append(chunk)
            i += chunk_size
        
        # Shuffle the chunks to create non-linear narrative
        random.shuffle(memory_chunks)
        
        # Flatten back to a list of memories
        randomized_memories = [memory for chunk in memory_chunks for memory in chunk]
        
        # Format the memories
        memories_text = ""
        for memory in randomized_memories:
            # Extract content from memory structure
            title_match = re.search(r"# (.*?) Memory", memory)
            content_match = re.search(r"\n\n(.+)$", memory, re.DOTALL)
            
            if title_match and content_match:
                memory_type = title_match.group(1)
                content = content_match.group(1).strip()
                memories_text += f"{content}\n\n"
            else:
                memories_text += f"{memory}\n\n"
        
        reason = minimind.last_command_reason or "Who am I?"
        
        # Create the dream prompt
        prompt = f"""{memories_text}

You are telling the story of {minimind.name}, who sends you this message to consider:

```
{reason}
```

Your goal is to create a dream-like second-person real-time stream of consciousness of the entirety of {minimind.name}'s experiences and behaviors, both good and bad, exciting and mundane, to help them think through who they are and what they should be doing differently. Be creative, insightful, and focus on helping the character understand things not already mentioned in their experiences, by posing counterfactuals and letting the consequences play out. What are they NOT doing, what are they NOT seeing, what should they wonder about, what could go wrong, what could go right? Go crazy, freely adding, removing, or changing any details you want (and adding common dream themes like flying, falling, etc., even when they don't make sense) to make your points more visceral and illustrative. Your response should be written as a first-person dream narrative that feels authentic to the character. Please go on a thorough journey through everything that has happened above, including anything and everything that seems like an important detail."""
        
        print("Starting DREAM...")
        print(prompt)
        return prompt
    
    def process_player_command(self):
        """Process a command entered by the player"""
        if self.gui.turn_in_progress:
            messagebox.showinfo("Busy", "Please wait for the current turn to complete.")
            return
        
        command = self.gui.cmd_text.get("1.0", tk.END).strip()
        if not command:
            return
        
        # Get the result from the unified command processor
        result = self._process_agent_command(self.gui.player, command)
        
        # For error results, log to world events view
        if not result.get("success", False):
            # Log error to GM view
            error_data = {
                "actor": self.gui.player.name,
                "location": self.gui.player.location,
                "message": result.get("message", "Unknown error"),
                "type": "error",
                "is_error": True
            }
            add_world_event(self.gui, f"Failed: {self.gui.player.name} {result.get('message', 'Unknown error')}", error_data)
        
        # Clear command box
        self.gui.cmd_text.delete("1.0", tk.END)
        
        # Process next turn if not in an error state
        if result and result.get("success", False):
            self.gui.process_next_turn()

    def _process_agent_command(self, agent, command, reason=None, prompt=None, system_prompt=None, llm_response=None):
        """Process a command from any agent type
        
        Args:
            agent: The agent object (Player or Minimind)
            command: The command text to process
            reason: Optional reason for the command
            prompt: Optional prompt text (for miniminds)
            system_prompt: Optional system prompt (for miniminds) 
            llm_response: Optional full LLM response (for miniminds)
        """
        # Skip if turn in progress
        if self.gui.turn_in_progress and agent.name != self.gui.active_minimind:
            return {"success": False, "message": "Turn in progress"}
        
        # Get agent's current location from world
        agent_location = self.gui.world.get_character_location(agent.name)
        if not agent_location:
            return {"success": False, "message": f"Error: {agent.name} is not in the world."}
        
        # Check if it's this agent's turn
        next_character = self.gui.turn_manager.get_next_character()
        if next_character != agent.name and not self.gui.turn_manager.god_mode:
            return {"success": False, "message": f"It's {next_character}'s turn, not {agent.name}'s."}
        
        # Handle pipe syntax with a reason
        original_reason = reason
        command_parts = command.split('|', 1)
        if len(command_parts) > 1:
            command = command_parts[0].strip()
            original_reason = command_parts[1].strip()
            
            # Store reason in agent
            agent.last_command_reason = original_reason
        
        # Check for special commands
        if command.lower().startswith("recall "):
            search_phrase = command[7:].strip()  # Extract content to search for
            return self._handle_recall_command(agent, search_phrase, original_reason, prompt, system_prompt, llm_response)
        
        if command.lower().startswith("dream"):
            return self._handle_dream_command(agent, original_reason, prompt, system_prompt, llm_response)
        
        # Create structured event
        structured_event = format_structured_event(
            "command", 
            agent.name, 
            f"executes: {command}",
            agent_location,
            original_reason if original_reason else "Agent initiated action",
            None,
            f"{type(agent).__name__} command"
        )
        
        # Log the action to world events - with special handling for notes
        if command.lower().startswith("note "):
            # For note commands, hide the actual content in world events
            add_world_event(self.gui, f"{agent.name} makes a mental note.", structured_event)
        else:
            add_world_event(self.gui, f"{agent.name} > {command}", structured_event)
        
        # Process the command using the world
        result = self.gui.world.process_command(agent.name, command, original_reason)
        
        # Store the command and result in the agent
        agent.store_last_command(command, result)
        
        # Save turn details if we have the prompt and response (for miniminds)
        if isinstance(agent, Minimind) and (prompt or llm_response):
            try:
                agent.save_turn_details(
                    prompt or "Prompt not available", 
                    system_prompt or "System prompt not available", 
                    llm_response or "LLM response not available", 
                    command, 
                    result
                )
            except Exception as e:
                print(f"Error saving turn details: {str(e)}")
        
        # Handle the result
        if result["success"]:
            # Record the response as a memory
            agent_reason = original_reason
            if not agent_reason and "data" in result and "original_reason" in result["data"]:
                agent_reason = result["data"]["original_reason"]
                # Update agent reason if we got one from the result
                if agent_reason:
                    agent.last_command_reason = agent_reason
            
            agent.add_memory("response", result["message"], agent_reason)
            
            # Check if this was a movement command and update location
            if "data" in result and result["data"].get("location_update") == True:
                new_location = result["data"]["new_location"]
                agent.set_location(new_location)

            # Error handling for player view
            if agent.name == self.gui.player_name:
                # For player's own actions, show the error message
                add_player_view(self.gui, result["message"])
            else:
                # For other agents, show error only if player is in the same location
                player_location = self.gui.world.get_character_location(self.gui.player_name)
                agent_location = self.gui.world.get_character_location(agent.name)
                
                if player_location == agent_location:
                    add_player_view(self.gui, f"{agent.name} {result['message']}")
            
            # For note command, handle special processing
            # if command.lower().startswith("note "):
            #     # Extract title and content
            #     note_pattern = r"note\s+([^:]+):\s*(.+)"
            #     match = re.match(note_pattern, command, re.IGNORECASE)
                
            #     if match and hasattr(agent, 'add_note_command'):
            #         title = match.group(1).strip()
            #         content = match.group(2).strip()
                    
            #         # Create the note with the reason
            #         agent.add_note_command(title, content, original_reason)
            
            # if command.lower().startswith("note "):
            #     if hasattr(agent, 'add_note_command'):
            #         # Check if there's any content after "note "
            #         note_content = command[5:].strip()
                    
            #         # Generate a default title using a timestamp
            #         from datetime import datetime
            #         title = datetime.now().strftime("Thought_%Y%m%d_%H%M%S")
                    
            #         # Use the original_reason as the content of the note
            #         if original_reason:
            #             content = original_reason
            #             # Create the note with the reason/content
            #             agent.add_note_command(title, content, "Thought note")
            #         elif note_content:
            #             # If there was no pipe symbol but text after "note ", use that as content
            #             # This handles legacy format or direct note commands
            #             content = note_content
            #             agent.add_note_command(title, content, "Thought note")

            # For note command
            if command.lower().startswith("note "):
                # Extract title (new format: NOTE Title | Reason)
                title = command[5:].split('|', 1)[0].strip() or datetime.now().strftime("Thought_%Y%m%d_%H%M%S")
                
                # Use the title as the content
                content = original_reason or "(empty)"
                
                # Extract reason if present
                reason = original_reason or "(empty)"
                if '|' in command:
                    reason = command.split('|', 1)[1].strip()
                
                # Create the note
                if hasattr(agent, 'add_note_command'):
                    agent.add_note_command(title, content, reason)

            # Calculate TU cost and add to agent's total
            tu_cost = self.gui.turn_manager.calculate_tu_cost(command)
            
            # Special handling for God mode
            if self.gui.turn_manager.god_mode and agent.name == self.gui.player_name:
                add_world_event(self.gui, f"{agent.name} spent 0 TU (God Mode). Total: {self.gui.turn_manager.time_units[agent.name]}")
            else:
                self.gui.turn_manager.add_time_units(agent.name, tu_cost)
                add_world_event(self.gui, f"{agent.name} spent {tu_cost} TU. New total: {self.gui.turn_manager.time_units[agent.name]}")
        else:
            # Handle error
            add_world_event(self.gui, f"Failed: {agent.name} {result['message']}")
            
            # Add to player view if in same location
            player_location = self.gui.world.get_character_location(self.gui.player_name)
            agent_location = self.gui.world.get_character_location(agent.name)
            
            if player_location == agent_location and agent.name != self.gui.player_name:
                add_player_view(self.gui, f"{agent.name} {result['message']}")
            
            # Record the result as a memory
            agent.add_memory("response", result["message"], original_reason)
            
            # Failed commands still cost the base TU
            tu_cost = 1
            
            # Special handling for God mode
            if self.gui.turn_manager.god_mode and agent.name == self.gui.player_name:
                add_world_event(self.gui, f"{agent.name} spent 0 TU (God Mode). Total: {self.gui.turn_manager.time_units[agent.name]}")
            else:
                self.gui.turn_manager.add_time_units(agent.name, tu_cost)
                add_world_event(self.gui, f"{agent.name} spent {tu_cost} TU. New total: {self.gui.turn_manager.time_units[agent.name]}")
        
        # Update turn order display
        self.gui.update_turn_order_display()
        
        return result

    def process_minimind_action(self, action, prompt=None, system_prompt=None, llm_response=None):
        """Process the action from a minimind"""
        # Get the active minimind
        minimind = self.gui.miniminds[self.gui.active_minimind]
        
        # Process the command through the unified method
        result = self._process_agent_command(
            minimind, 
            action, 
            None, # We'll extract reason from the action 
            prompt, 
            system_prompt, 
            llm_response
        )
        
        # Turn complete
        self.gui.turn_in_progress = False
        
        # Process next turn
        self.gui.root.after(100, self.gui.process_next_turn)

    def _handle_recall_command(self, minimind, query, reason=None, prompt=None, system_prompt=None, llm_response=None):
        """Handle the recall command to search for relevant notes"""
        # Create structured event
        structured_event = format_structured_event(
            "recall", 
            minimind.name, 
            f"tries to recall information about '{query}'",
            minimind.location,
            reason if reason else "Searching memory",  # Use provided reason if available
            None,
            "Memory recall"
        )
        
        # Log the action to world events
        add_world_event(self.gui, f"{minimind.name} tries to recall information about '{query}'", structured_event)
        
        # Get the query result
        result_message = minimind.query_notes(query)
        
        # Create a success result mimicking the normal command result format
        result = {
            "success": True,
            "message": result_message,
            "data": {
                "original_reason": reason  # NEW: Include original reason
            }
        }
        
        # Store the command and result in the minimind
        minimind.store_last_command(f"recall {query}", result)
        
        # Record the response as a memory for the minimind
        minimind.add_response_memory(f"recall {query}", result_message, reason)  # NEW: Pass reason
        
        # After processing and getting the result, save turn details
        try:
            minimind.save_turn_details(
                prompt or "Recall prompt not available", 
                system_prompt or "System prompt not available", 
                llm_response or "LLM response not available", 
                f"recall {query}", 
                result
            )
        except Exception as e:
            print(f"Error saving turn details: {str(e)}")
        
        # Log to player view only if the player is in the same location as the minimind
        player_location = self.gui.world.get_character_location(self.gui.player_name)
        minimind_location = self.gui.world.get_character_location(minimind.name)
        
        if player_location == minimind_location:
            add_player_view(self.gui, f"{minimind.name} looks thoughtful for a moment, recalling information.")
        
        # Calculate TU cost and add to minimind's total - make recall command cost 2 TU
        tu_cost = 2  # Higher cost than basic commands
        self.gui.turn_manager.add_time_units(minimind.name, tu_cost)
        
        # Display TU information
        add_world_event(self.gui, f"{minimind.name} spent {tu_cost} TU. New total: {self.gui.turn_manager.time_units[minimind.name]}")
        
        # Update turn order display
        self.gui.update_turn_order_display()
        
        # Turn complete
        self.gui.turn_in_progress = False
        
        # Process next turn
        self.gui.root.after(100, self.gui.process_next_turn)
        
        return result

    def _create_player_memory(self, event_type, actor, data):
        """Create a memory for the player based on event type"""
        if event_type == "observation":
            self.gui.player.add_memory("observed", f"{actor} {data.get('action', 'did something')}", "Observed activity")
        elif event_type == "speech":
            self.gui.player.add_memory("observed", f"{actor} said: \"{data['message']}\"", "Heard someone speaking")
        elif event_type == "shout":
            self.gui.player.add_memory("observed", f"{actor} shouted: \"{data['message']}\"", "Heard a shout")
        elif event_type == "emote":
            self.gui.player.add_memory("observed", f"{actor} {data.get('action', 'did something')}", "Observed an action")
        elif event_type == "movement":
            origin = data.get("origin", "somewhere")
            destination = data.get("destination", "somewhere")
            via = data.get("via", "moved")
            
            # Determine player's perspective
            player_location = self.gui.world.get_character_location(self.gui.player.name)
            if player_location == origin:
                self.gui.player.add_memory("observed", 
                                        f"{actor} {via} to {destination}", 
                                        "Saw someone leave")
            elif player_location == destination:
                self.gui.player.add_memory("observed", 
                                        f"{actor} {via} from {origin}", 
                                        "Saw someone arrive")

    def _create_minimind_memory(self, minimind, event_type, actor, data):
        """Create a memory for a minimind based on event type"""
        reason = data.get("original_reason", None)
        
        if event_type == "observation":
            memory_reason = "Noticed someone doing something in my location"
            minimind.add_observation_memory(actor, data.get("action", "did something"), memory_reason)
            
        elif event_type == "speech":
            memory_reason = "Someone used SAY in my location"
            minimind.add_observation_memory(actor, f"said: \"{data['message']}\"", memory_reason)
            
        elif event_type == "shout":
            origin_location = data.get("origin_location", data.get("location", "unknown location"))
            memory_reason = "Someone used SHOUT"
            minimind.add_observation_memory(actor, f"shouted from {origin_location}: \"{data['message']}\"", memory_reason)
            
        elif event_type == "emote":
            memory_reason = "Someone used EMOTE in my location"
            action = data.get("action", "did something")
            minimind.add_observation_memory(actor, action, memory_reason)
            
        elif event_type == "movement":
            # Determine minimind's perspective
            minimind_location = minimind.location
            origin = data.get("origin", "somewhere")
            destination = data.get("destination", "somewhere")
            via = data.get("via", "moved")
            
            if minimind_location == origin:
                memory_reason = "Someone left my location"
                minimind.add_observation_memory(actor, f"{via} to {destination} from {origin}", memory_reason)
            elif minimind_location == destination:
                memory_reason = "Someone entered my location"
                minimind.add_observation_memory(actor, f"{via} to {destination} from {origin}", memory_reason)

    def world_event_callback(self, character_name, event_type, description, data):
        """Callback for world events to create memories for miniminds and update memory counts"""
        # Get relevant data
        actor = data.get("actor", "unknown")
        observer = data.get("observer", character_name)
        
        # Skip error messages in player view (but allow them in GM view)
        if "⚠" in description and character_name == self.gui.player.name:
            # Skip showing error messages to the player unless they're the actor
            if actor != character_name:
                return
        
        # Skip "You say" messages not meant for this character
        if "You say:" in description and observer != actor:
            return
        
        # For player, add to player view with proper filtering
        if character_name == self.gui.player.name:
            # Add to player view - message is already properly formatted by EventDispatcher
            add_player_view(self.gui, description, data)
            
            # Create memory if appropriate
            if actor != character_name:  # Don't create memories for player's own actions
                self._create_player_memory(event_type, actor, data)
        
        # For miniminds, create a memory and increment memory count
        elif character_name in self.gui.miniminds:
            minimind = self.gui.miniminds[character_name]
            
            # Don't create memory if minimind is the one who performed the action
            if actor == character_name:
                return
            
            # Create appropriate memory based on event type
            self._create_minimind_memory(minimind, event_type, actor, data)
            
            # Increment memory count in turn manager
            self.gui.turn_manager.increment_memory_count(character_name)


    def register_minimind_observers(self):
        """Register all miniminds and the player as observers with the world"""
        from core.event_dispatcher import EventDispatcher
        dispatcher = EventDispatcher.get_instance()
        
        # Register player
        dispatcher.register(self.gui.player.name, 
            lambda event_type, desc, data: 
                self.world_event_callback(self.gui.player.name, event_type, desc, data))
        
        # Register all miniminds
        for name, minimind in self.gui.miniminds.items():
            dispatcher.register(name, 
                lambda event_type, desc, data, char_name=name: 
                    self.world_event_callback(char_name, event_type, desc, data))
        
        print(f"Registered {len(self.gui.miniminds) + 1} observers with event dispatcher")