import tkinter as tk
import customtkinter as ctk
import threading
from tkinter import simpledialog, messagebox
from core.player import Player
from ui_panels import setup_minimind_panel, setup_interaction_panel, setup_debug_panel
from command_processor import CommandProcessor
from event_handler import EventHandler
from minimind import Minimind
from world import World
from llm_interface import OllamaInterface
from turn_manager import TurnManager
from markdown_utils import MarkdownVault

class MinimindGUI:
    def __init__(self, root, settings=None):
        self.root = root
        
        # Initialize base state
        self.miniminds = {}
        self.active_minimind = None
        self.turn_in_progress = False
        self.stop_streaming = threading.Event()
        
        # Apply settings if provided
        if settings:
            self.apply_settings(settings)
        else:
            # Default values if no settings provided
            self.memories_count = 64
            self.notes_count = 16
            
            # Initialize LLM with default settings
            self.llm = OllamaInterface()
        
        # Initialize the player agent
        player_name = settings.get("app", {}).get("player_name", "⚪") if settings else "⚪"
        self.player = Player(name=player_name, llm_interface=self.llm)
        self.player_name = self.player.name
        
        # Create an alias for compatibility
        self.llm_interface = self.llm
        
        # Add turn manager
        self.turn_manager = TurnManager()
        
        # Setup the layout
        self.setup_layout()
        
        # Create command processor and event handler
        self.command_processor = CommandProcessor(self)
        self.event_handler = EventHandler(self)
        
        # Initialize world first (this loads locations and saved state)
        self.world = World()
        
        # Load miniminds BEFORE player initialization
        self.load_miniminds()
        
        # Register miniminds as observers
        self.command_processor.register_minimind_observers()
        
        # Now initialize player in the world
        self.initialize_world()
        
        # Now that everything is loaded, do the initial look command
        player_location = self.world.get_character_location(self.player_name)
        if player_location:
            result = self.world.process_command(self.player_name, "look")
            if result["success"]:
                self.add_player_view(result["message"])
        
        # Start with updating turn order display
        self.update_turn_order_display()
        
        # Set status based on whose turn it is
        next_character = self.turn_manager.get_next_character()
        if next_character == self.player_name:
            self.set_status(f"Your turn. Enter a command or action.")
        else:
            self.set_status(f"It's {next_character}'s turn. Click 'Execute Next Turn'.")

    def apply_settings(self, settings):
        """Apply settings from the vault"""
        app_settings = settings.get("app", {})
        llm_settings = settings.get("llm", {})
        
        # Apply memory and note settings
        self.memories_count = app_settings.get("Default Memory Count", 64)
        self.notes_count = app_settings.get("Default Notes Count", 16)
        
        # Dream memories count - how many memories to analyze during dreaming
        self.dream_memories_count = app_settings.get("Dream Memories Count", 128)
        
        # Initialize LLM with settings
        model = llm_settings.get("Model", "deepseek-r1:14b")
        temperature = llm_settings.get("Temperature", 0.8)
        context_tokens = llm_settings.get("Context Tokens", 32768)
        repeat_penalty = llm_settings.get("Repeat Penalty", 1.2)
        embedding_model = llm_settings.get("Embedding Model", "all-minilm")
        
        # Get stop tokens if defined
        stop_tokens = []
        for i in range(1, 10):  # Look for up to 10 stop tokens
            token_key = f"Stop Token {i}"
            if token_key in llm_settings:
                stop_tokens.append(llm_settings[token_key])
        
        # Initialize LLM
        self.llm = OllamaInterface(
            model=model,
            temperature=temperature,
            context_tokens=context_tokens,
            repeat_penalty=repeat_penalty,
            embedding_model=embedding_model,
            stop_tokens=stop_tokens if stop_tokens else None
        )

    def setup_layout(self):
        """Create the main GUI layout using a grid-based approach"""
        # Configure grid for the main window
        self.root.grid_columnconfigure(0, weight=1)  # Left panel
        self.root.grid_columnconfigure(1, weight=3)  # Middle panel
        self.root.grid_columnconfigure(2, weight=2)  # Right panel
        self.root.grid_rowconfigure(0, weight=1)
        
        # Left panel - Miniminds
        left_frame = ctk.CTkFrame(self.root)
        left_frame.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")
        
        # Middle panel - Interaction
        middle_frame = ctk.CTkFrame(self.root)
        middle_frame.grid(row=0, column=1, padx=5, pady=5, sticky="nsew")
        
        # Right panel - Debug
        right_frame = ctk.CTkFrame(self.root)
        right_frame.grid(row=0, column=2, padx=5, pady=5, sticky="nsew")
        
        # Set up each panel
        setup_minimind_panel(self, left_frame)
        setup_interaction_panel(self, middle_frame)
        setup_debug_panel(self, right_frame)

    def initialize_world(self):
        """Initialize the world and add the player"""
        # Check if player already has a location from world state
        player_location = self.world.get_character_location(self.player.name)
        
        if not player_location and self.world.locations:
            initial_location = self.world.get_random_location()
            self.world.add_character_to_location(self.player.name, initial_location)
            self.player.set_location(initial_location)
            
            # Log to world events (GM view)
            self.add_world_event(f"{self.player.name} enters the world in the {initial_location}.")
            
            # Log to player view (MUD/MOO style)
            self.add_player_view(f"You find yourself in the {initial_location}.")
        elif player_location:
            # Update player's location property
            self.player.set_location(player_location)
        
        # Register the player as an observer to receive world events
        self.world.register_observer(self.player.name, 
            lambda event_type, desc, data: 
                self.command_processor.world_event_callback(self.player.name, event_type, desc, data))
        
        self.player_observer_registered = True
                
        # Register player with turn manager as a player character
        self.turn_manager.register_character(self.player.name, is_player=True)

    def load_miniminds(self):
        """Load existing miniminds from disk"""
        for item in Minimind.get_all_miniminds():
            # Pass the LLM interface to the minimind for embeddings
            minimind = Minimind(item, self.llm_interface)
            
            # Check if minimind already has a location in the world state
            location = self.world.get_character_location(minimind.name)
            
            # If not, place in a random location
            if not location and self.world.locations:
                location = self.world.get_random_location()
                minimind.set_location(location)
                # Add the minimind to the location
                self.world.add_character_to_location(minimind.name, location)
            elif location:
                # Set the minimind's location property to match world state
                minimind.set_location(location)
            
            self.miniminds[minimind.name] = minimind
            self.mind_list.insert("end", item)
            
            # Register minimind with turn manager
            self.turn_manager.register_character(minimind.name)
            
            # If we don't have a selected minimind yet, select this one
            if not self.active_minimind:
                self.active_minimind = minimind.name
                self.mind_list.select([0])
            
            # Index all notes for the minimind if they have the embedding model
            if self.llm_interface:
                threading.Thread(
                    target=minimind.index_all_notes,
                    daemon=True
                ).start()

    def reload_all_miniminds(self):
        """Reload all miniminds and templates from disk"""
        # Display status
        self.set_status("Reloading miniminds and templates...")
        
        # Clear existing miniminds
        self.miniminds = {}
        
        # Clear the miniminds list in the UI
        for widget in self.mind_list_frame.winfo_children():
            widget.destroy()
        
        # Reset active minimind
        self.active_minimind = None
        
        # Re-load the miniminds
        self.load_miniminds()
        
        # Reload world state
        self.world.load_world_state()
        
        # Re-register minimind observers
        self.command_processor.register_minimind_observers()
        
        # Update turn order display
        self.update_turn_order_display()
        
        # Update status
        self.set_status("All miniminds and templates reloaded successfully!")

    def update_turn_order_display(self):
        """Update the display of the turn order and button states"""
        turn_order = self.turn_manager.get_turn_order()
        display_text = ""
        
        for i, character in enumerate(turn_order):
            # Different display based on turn mode
            if self.turn_manager.turn_mode == "memories":
                # When in memory mode, show memory counts
                mem_count = self.turn_manager.new_memories_count[character]
                if i == 0:
                    display_text += f"► {character} ({mem_count} memories) ◄\n"
                else:
                    display_text += f"{i+1}. {character} ({mem_count} memories)\n"
            else:
                # When in TU mode, show TU counts
                tu = self.turn_manager.time_units[character]
                if i == 0:
                    display_text += f"► {character} ({tu} TU) ◄\n"
                else:
                    display_text += f"{i+1}. {character} ({tu} TU)\n"
        
        self.turn_order_var.set(display_text)
        
        # Update button states based on whose turn it is
        next_character = self.turn_manager.get_next_character()
        is_player_turn = (next_character == self.player_name)
        
        # Enable/disable submit and pass buttons based on whose turn it is
        self.submit_btn.configure(state="normal" if is_player_turn else "disabled")
        self.pass_btn.configure(state="normal" if is_player_turn else "disabled")
        
        # Check auto-execute and auto-pass
        if is_player_turn and self.auto_pass_var.get():
            # If it's player's turn and auto-pass is enabled, automatically pass
            self.root.after(1000, lambda: self.pass_turn(auto_triggered=True))
        elif not is_player_turn and self.auto_execute_var.get():
            # If it's a minimind's turn and auto-execute is enabled, automatically execute
            self.root.after(1000, self.execute_minimind_turn)

    def create_minimind(self):
        """Create a new minimind"""
        name = simpledialog.askstring("New Minimind", "Enter name for new minimind:")
        if not name:
            return
            
        if name in self.miniminds:
            messagebox.showerror("Error", f"A minimind named '{name}' already exists.")
            return
        
        # Create the minimind with LLM interface
        minimind = Minimind.create_new(name, self.llm_interface)
            
        # Add to list and dictionary
        if self.world.locations:
            location = self.world.get_random_location()
            minimind.set_location(location)
            self.world.add_character_to_location(name, location)
            
            # Add world event and player view about the new character
            self.add_world_event(f"{name} has entered the world and is now in the {location}.")
            
            # Only show in player view if player is in the same location
            player_location = self.world.get_character_location(self.player_name)
            if player_location == location:
                self.add_player_view(f"{name} has entered the {location}.")
        
        self.miniminds[name] = minimind
        self.mind_list.insert("end", name)
        self.on_select_minimind(name)
        
        # Register the new minimind with the turn manager
        self.turn_manager.register_character(name)
        self.update_turn_order_display()
        
        # Register the new minimind as an observer
        self.world.register_observer(name, 
            lambda event_type, desc, data, char_name=name: 
                self.command_processor.world_event_callback(char_name, event_type, desc, data))

    def edit_minimind(self):
        """Edit the selected minimind's profile"""
        if not self.active_minimind:
            messagebox.showinfo("No Selection", "Please select a minimind to edit.")
            return
            
        minimind = self.miniminds[self.active_minimind]
        minimind.edit_profile(self.root)

    def view_memories(self):
        """View the selected minimind's memories"""
        if not self.active_minimind:
            messagebox.showinfo("No Selection", "Please select a minimind to view memories.")
            return
            
        minimind = self.miniminds[self.active_minimind]
        from memory import MemoryViewer
        MemoryViewer(self.root, minimind)

    def view_notes(self):
        """View the selected minimind's notes"""
        if not self.active_minimind:
            messagebox.showinfo("No Selection", "Please select a minimind to view notes.")
            return
            
        minimind = self.miniminds[self.active_minimind]
        from memory import NoteEditor
        NoteEditor(self.root, minimind)

    def on_select_minimind(self, selection):
        """Handle selection of a minimind from the list"""
        if selection:
            self.active_minimind = selection
            self.set_status(f"Selected {self.active_minimind}")

    def execute_minimind_turn(self):
        """Execute a turn for the next minimind"""
        # Check if it's a minimind's turn
        next_character = self.turn_manager.get_next_character()
        
        if next_character == self.player_name:
            messagebox.showinfo("Not Minimind's Turn", "It's your turn, not a minimind's.")
            return
            
        if next_character not in self.miniminds:
            messagebox.showinfo("Error", f"Unknown character: {next_character}")
            return
            
        if self.turn_in_progress:
            return
                
        # Set the active minimind to the one whose turn it is
        self.active_minimind = next_character
        
        # Call the event handler to process the minimind's turn
        self.event_handler.execute_minimind_turn()

    def process_player_command(self):
        """Process a command entered by the player"""
        self.command_processor.process_player_command()

    def toggle_turn_mode(self):
        """Toggle between time units and memory-based turn modes"""
        current_mode = self.turn_manager.turn_mode
        
        # Toggle to the opposite mode
        new_mode = "memories" if current_mode == "time_units" else "time_units"
        
        # Set the new mode in turn manager
        self.turn_manager.set_turn_mode(new_mode)
        
        # Update the mode display text
        mode_display = "Memory-Based" if new_mode == "memories" else "Time Units"
        self.turn_mode_var.set(mode_display)
        
        # Display info about the mode change
        mode_name = "Memory-Based" if new_mode == "memories" else "Time Units"
        self.add_world_event(f"* SYSTEM: Turn mode changed to {mode_name} *")
        
        # Update the turn order display to reflect new mode
        self.update_turn_order_display()

    def pass_turn(self, auto_triggered=False):
        """Pass the player's turn"""
        if self.turn_in_progress:
            return
                
        next_character = self.turn_manager.get_next_character()
        if next_character != self.player_name:
            if not auto_triggered:  # Only show the dialog if not auto-triggered
                messagebox.showinfo("Not Your Turn", "It's not your turn to pass.")
            return
                
        # Execute pass turn
        if self.turn_manager.pass_turn(self.player_name):
            self.add_world_event(f"{self.player_name} passes turn.")
            # Update TU display
            self.update_turn_order_display()
                
            # Update status for next character
            next_character = self.turn_manager.get_next_character()
            if next_character == self.player_name:
                self.set_status(f"Your turn. Enter a command or action.")
            else:
                self.set_status(f"It's {next_character}'s turn. Click 'Execute Next Turn'.")
        else:
            if not auto_triggered:  # Only show the dialog if not auto-triggered
                messagebox.showinfo("Error", "Cannot pass turn.")
            
    def process_next_turn(self):
        """Process the next turn based on the turn order"""
        if self.turn_in_progress:
            return
            
        # Get the next character
        next_character = self.turn_manager.get_next_character()
        
        # Update turn order display - this will now also update button states
        self.update_turn_order_display()
        
        # Update status
        if next_character == self.player_name:
            self.set_status(f"Your turn. Enter a command or action.")
            
            # Check for auto-pass
            if self.auto_pass_var.get():
                self.root.after(1500, lambda: self.pass_turn(auto_triggered=True))
        else:
            self.set_status(f"It's {next_character}'s turn. Click 'Execute Next Turn'.")
            
            # If it's a minimind's turn and auto-execute is enabled, automatically execute
            if self.auto_execute_var.get():
                self.root.after(1000, self.execute_minimind_turn)

    def toggle_god_mode(self):
        """Toggle God mode on/off based on the checkbox state"""
        god_mode_enabled = self.god_mode_var.get()
        self.turn_manager.set_god_mode(god_mode_enabled)
        
        if god_mode_enabled:
            status_message = "God Mode activated! Player actions cost 0 TU."
        else:
            status_message = "God Mode deactivated."
        
        self.set_status(status_message)
        
        # Update turn order display to reflect changes
        self.update_turn_order_display()
        
        # Update world event log
        self.add_world_event(f"* SYSTEM: {status_message} *")
    
    # Helper methods for UI updates (forwarding to utility functions)
    def add_world_event(self, text, structured_data=None):
        """Add text to the World Events log"""
        from gui_utils import add_world_event
        add_world_event(self, text, structured_data)
    
    def add_player_view(self, text, structured_data=None):
        """Add text to the Player View"""
        from gui_utils import add_player_view
        add_player_view(self, text, structured_data)
    
    def set_status(self, message):
        """Set the status message"""
        from gui_utils import set_status
        set_status(self, message)
