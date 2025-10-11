import math
from collections import deque
from tkinter import messagebox
from markdown_utils import MarkdownVault

class TurnManager:
    def __init__(self):
        # Dictionary of {character_name: TU_count}
        self.time_units = {}
        # Queue to track who went when (for tie-breaking)
        self.turn_history = deque()
        # Track last turn time for each character
        self.last_turn_time = {}
        # Player name
        self.player_name = None
        # God mode toggle (player can act anytime without accruing TU)
        self.god_mode = False
        # Turn mode - "time_units" or "memories"
        self.turn_mode = "time_units"
        # Dictionary to track new memories/observations since last turn
        self.new_memories_count = {}
        
        # Load turn rules from the vault
        self.load_turn_rules()
        
    def load_turn_rules(self):
        """Load turn rules from the markdown settings"""
        try:
            turn_rules_md = MarkdownVault.load_settings("turn_rules")
            turn_rules = MarkdownVault.parse_settings(turn_rules_md)
            
            # Apply rules if available
            self.base_cost = turn_rules.get("Base Cost", 1)
            self.scale_with_content = turn_rules.get("Scale With Content", True)
            
            # Set TU cost multipliers from settings or use defaults
            self.say_multiplier = turn_rules.get("Say TU Multiplier", 3)
            self.shout_multiplier = turn_rules.get("Shout TU Multiplier", 2)
            self.note_multiplier = turn_rules.get("Note TU Multiplier", 7)
            self.dig_cost = turn_rules.get("Dig TU Cost", 5)  # Higher cost for world-building
            self.describe_cost = turn_rules.get("Describe TU Cost", 3)  # Cost for describing locations
            
            # Get the turn mode from settings if available
            self.turn_mode = turn_rules.get("Turn Mode", "time_units")
            
            print(f"Loaded turn rules from vault (Mode: {self.turn_mode})")
        except Exception as e:
            print(f"Warning: Could not load turn rules: {str(e)}")
            # Use default values
            self.base_cost = 1
            self.scale_with_content = True
            self.say_multiplier = 3
            self.shout_multiplier = 2
            self.note_multiplier = 7
            self.dig_cost = 5
            self.describe_cost = 3
            self.turn_mode = "time_units"
    
    def set_turn_mode(self, mode):
        """Set the turn mode to either 'time_units' or 'memories'"""
        if mode in ["time_units", "memories"]:
            self.turn_mode = mode
            return True
        return False
        
    def register_character(self, name, is_player=False):
        """Add a character to the turn system"""
        if name not in self.time_units:
            # Only non-player agents start with 1 TU
            self.time_units[name] = 0 if is_player else 1
            self.last_turn_time[name] = 0
            self.new_memories_count[name] = 0
            
            # If this is the player, store their name
            if is_player:
                self.player_name = name
            
    def set_god_mode(self, enabled):
        """Toggle God mode on/off"""
        self.god_mode = enabled
        return self.god_mode
            
    def remove_character(self, name):
        """Remove a character from the turn system"""
        if name in self.time_units:
            del self.time_units[name]
            if name in self.last_turn_time:
                del self.last_turn_time[name]
            if name in self.new_memories_count:
                del self.new_memories_count[name]
            
    def calculate_tu_cost(self, command):
        """Calculate TU cost for a command based on rules"""
        # Base cost (ante)
        cost = self.base_cost
        
        # If scaling is disabled, return base cost for all commands
        if not self.scale_with_content:
            return cost
        
        # Extract command type and content
        command_lower = command.lower().strip()
        
        # SAY command: +1 for every X words (from settings)
        if command_lower.startswith("say "):
            message = command[4:].strip()
            word_count = len(message.split())
            cost += math.ceil(word_count / self.say_multiplier)
            
        # EMOTE command: +1 for every X words (same as NOTE)
        elif command_lower.startswith("emote "):
            message = command[6:].strip()
            word_count = len(message.split())
            cost += math.ceil(word_count / self.note_multiplier)
            
        # SHOUT command: +1 for every X words (from settings)
        elif command_lower.startswith("shout "):
            message = command[6:].strip()
            word_count = len(message.split())
            cost += math.ceil(word_count / self.shout_multiplier)
            
        # NOTE command: +1 for every X words (from settings)
        elif command_lower.startswith("note "):
            # Extract content part (after the title)
            parts = command[5:].strip().split(":", 1)
            if len(parts) > 1:
                content = parts[1].strip()
                word_count = len(content.split())
                cost += math.ceil(word_count / self.note_multiplier)
                
        # DIG command: fixed higher cost (from settings)
        elif command_lower.startswith("dig "):
            cost += self.dig_cost
            
        # DESCRIBE command: fixed cost + word count (from settings)
        elif command_lower.startswith("describe "):
            description = command[9:].strip()
            word_count = len(description.split())
            cost += self.describe_cost + math.ceil(word_count / (self.note_multiplier * 2))
            
        # DREAM command: fixed higher cost (like recall, but more intensive)
        elif command_lower.startswith("dream"):
            cost += 14  # Higher cost for deep introspection and synthesis
            
        # GO TO command: just the ante (already accounted for)
        
        return cost
    
    def increment_memory_count(self, character, count=1):
        """Increment the number of new memories/observations for a character"""
        if character in self.new_memories_count:
            self.new_memories_count[character] += count
    
    def add_time_units(self, character, tu_cost):
        """Add TU to a character's total with special handling for player vs AI agents"""
        if character not in self.time_units:
            return
        
        # In God mode, player doesn't accrue TU but still follows turn order
        if self.god_mode and character == self.player_name:
            # Update turn history but don't add costs
            pass
        else:
            # Get the turn order to determine next character
            turn_order = self.get_turn_order()
            
            # Find the position of the current character
            try:
                current_index = turn_order.index(character)
            except ValueError:
                current_index = -1
            
            # Different handling for player vs AI agents
            if character == self.player_name:
                # For player: never cost more than just enough to pass
                # Get the TU of the next character if there is one
                if len(turn_order) > 1 and current_index == 0:
                    next_char = turn_order[1]
                    next_tu = self.time_units[next_char]
                    # Cap the TU cost to just enough to go after next character
                    capped_cost = max(1, next_tu - self.time_units[character] + 1)
                    # Use the smaller of calculated cost or capped cost
                    tu_cost = min(tu_cost, capped_cost)
            else:
                # For AI agents: cost min of (1 + action cost) OR enough to go after next agent
                # Calculate the minimum pass cost - what it would take to go after next character
                pass_cost = 0
                if len(turn_order) > 1 and current_index == 0:
                    next_char = turn_order[1]
                    next_tu = self.time_units[next_char]
                    pass_cost = next_tu - self.time_units[character] + 1
                
                # Use the maximum of calculated cost or pass cost
                # This ensures agents don't get multiple turns in a row
                tu_cost = max(tu_cost, pass_cost)
                
            # Apply the adjusted cost
            self.time_units[character] += tu_cost
                
        # Update turn history and last turn time
        self.turn_history.append(character)
        self.last_turn_time[character] = len(self.turn_history)
        
        # Reset memory count after the character takes their turn
        self.new_memories_count[character] = 0
        
        # Normalize TU values after updating
        self.normalize_tu()
    
    def get_next_character(self):
        """Get the next character based on current turn mode"""
        if not self.time_units:
            return None
            
        if self.turn_mode == "memories":
            return self._get_next_character_by_memories()
        else:
            return self._get_next_character_by_tu()
    
    def _get_next_character_by_tu(self):
        """Get the character with the lowest TU (ties broken by who went longest ago)"""
        # Find candidates with the minimum TU
        min_tu = min(self.time_units.values())
        candidates = [char for char, tu in self.time_units.items() if tu == min_tu]
        
        if len(candidates) == 1:
            return candidates[0]
        
        # If there's a tie, break it by who went longest ago
        return min(candidates, key=lambda c: self.last_turn_time.get(c, 0))
    
    def _get_next_character_by_memories(self):
        """Get the character with the most new memories (ties broken by who went longest ago)"""
        # In God mode, player always goes first
        if self.god_mode and self.player_name in self.time_units:
            return self.player_name
            
        # Find candidates with the maximum memory count
        if any(count > 0 for count in self.new_memories_count.values()):
            # Only consider characters with at least one new memory
            max_memories = max(self.new_memories_count.values())
            # Only select from those with the maximum number of memories
            candidates = [char for char, count in self.new_memories_count.items() 
                         if count == max_memories and count > 0]
        else:
            # If no one has new memories, everyone is a candidate
            candidates = list(self.time_units.keys())
        
        if len(candidates) == 1:
            return candidates[0]
        
        # If there's a tie, break it by who went longest ago (lowest last_turn_time)
        return min(candidates, key=lambda c: self.last_turn_time.get(c, 0))
    
    def normalize_tu(self):
        """Normalize TU values by subtracting the minimum from all"""
        if not self.time_units:
            return
            
        min_tu = min(self.time_units.values())
        if min_tu > 0:
            for character in self.time_units:
                self.time_units[character] -= min_tu
    
    def get_turn_order(self):
        """Get the current turn order based on current turn mode"""
        if self.turn_mode == "memories":
            return self._get_turn_order_by_memories()
        else:
            return self._get_turn_order_by_tu()
    
    def _get_turn_order_by_tu(self):
        """Get turn order based on TU values"""
        # In God mode, player is always first
        if self.god_mode and self.player_name in self.time_units:
            # Get all characters except player
            other_chars = [c for c in self.time_units.keys() if c != self.player_name]
            # Sort other characters by TU, then by last turn time
            sorted_other = sorted(
                other_chars,
                key=lambda c: (self.time_units[c], self.last_turn_time.get(c, 0))
            )
            # Return player followed by others
            return [self.player_name] + sorted_other
        else:
            # Normal sorting by TU and last turn time
            sorted_chars = sorted(
                self.time_units.keys(),
                key=lambda c: (self.time_units[c], self.last_turn_time.get(c, 0))
            )
            return sorted_chars
    
    def _get_turn_order_by_memories(self):
        """Get turn order based on memory counts"""
        # In God mode, player is always first
        if self.god_mode and self.player_name in self.time_units:
            # Get all characters except player
            other_chars = [c for c in self.time_units.keys() if c != self.player_name]
            # Sort other characters by memory count (descending), then by last turn time (ascending)
            sorted_other = sorted(
                other_chars,
                key=lambda c: (-self.new_memories_count.get(c, 0), self.last_turn_time.get(c, 0))
            )
            # Return player followed by others
            return [self.player_name] + sorted_other
        else:
            # Sort all characters by memory count (descending), then by last turn time (ascending)
            sorted_chars = sorted(
                self.time_units.keys(),
                key=lambda c: (-self.new_memories_count.get(c, 0), self.last_turn_time.get(c, 0))
            )
            return sorted_chars
    
    def pass_turn(self, character):
        """Pass turn, updating memory counts or TU as appropriate"""
        # In God mode, player can't pass
        if self.god_mode and character == self.player_name:
            return False
            
        if character in self.time_units and len(self.time_units) > 1:
            if self.turn_mode == "memories":
                # In memory mode, set this character's memory count to 0
                self.new_memories_count[character] = 0
            else:
                # In TU mode, add TU as in the original implementation
                # Get the character with the second lowest TU
                sorted_chars = self.get_turn_order()
                if sorted_chars[0] != character:
                    # Character is not currently up, can't pass
                    return False
                    
                if len(sorted_chars) > 1:
                    # Get next character's TU
                    next_char = sorted_chars[1]
                    next_tu = self.time_units[next_char]
                    self.time_units[character] = next_tu + 1
                else:
                    # Just add a minimal TU if there's only one character
                    self.time_units[character] += 1
            
            # Update turn history
            self.turn_history.append(character)
            self.last_turn_time[character] = len(self.turn_history)
            
            # Normalize TU values if in TU mode
            if self.turn_mode == "time_units":
                self.normalize_tu()
                
            return True
        return False
