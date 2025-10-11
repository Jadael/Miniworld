# Miniworld Codebase Documentation

This document contains the complete source code for the Miniworld project.

## app.py

---python
import os
import customtkinter as ctk
from main_gui import MinimindGUI
from markdown_utils import MarkdownVault
from core.player import Player

def ensure_directories():
    """Create necessary directories if they don't exist"""
    # Create the vault structure with default files
    MarkdownVault.ensure_vault_directories()
    
    # Create other required directories that might not be part of the vault
    additional_dirs = [
        "miniminds",
        "world"
    ]
    for directory in additional_dirs:
        os.makedirs(directory, exist_ok=True)

def load_app_settings():
    """Load application settings from markdown config"""
    try:
        app_settings = MarkdownVault.load_settings("app_settings")
        llm_settings = MarkdownVault.load_settings("llm_settings")
        turn_rules = MarkdownVault.load_settings("turn_rules")
        
        # Parse settings
        app_config = MarkdownVault.parse_settings(app_settings)
        llm_config = MarkdownVault.parse_settings(llm_settings)
        turn_config = MarkdownVault.parse_settings(turn_rules)
        
        return {
            "app": app_config,
            "llm": llm_config,
            "turn": turn_config
        }
    except Exception as e:
        print(f"Warning: Could not load settings from vault: {str(e)}")
        return {}  # Return empty dict if settings can't be loaded

def main():
    # Ensure all directories exist
    ensure_directories()
    
    # Load settings from the vault
    settings = load_app_settings()
    
    # Extract LLM settings if available
    llm_settings = settings.get("llm", {})
    app_settings = settings.get("app", {})
    turn_settings = settings.get("turn", {})
    
    # Initialize the player agent
    player_name = app_settings.get("player_name", "⚪")
    player = Player(player_name)
    
    # Set appearance mode and color theme for CustomTkinter
    appearance = app_settings.get("appearance_mode", "dark")
    theme = app_settings.get("color_theme", "blue")
    
    ctk.set_appearance_mode(appearance)
    ctk.set_default_color_theme(theme)
    
    # Create root window
    root = ctk.CTk()
    root.title("Minimind")
    
    # Get window size from settings or use default
    window_width = app_settings.get("window_width", 1500)
    window_height = app_settings.get("window_height", 800)
    root.geometry(f"{window_width}x{window_height}")
    
    # Initialize app - passing settings if MinimindGUI accepts them,
    # otherwise fall back to old initialization for backward compatibility
    try:
        app = MinimindGUI(root, settings)
    except TypeError:
        # If MinimindGUI doesn't accept settings parameter, fall back to original
        print("Note: Using legacy initialization (no settings parameter)")
        app = MinimindGUI(root)
        
        # Apply settings after initialization if possible
        if hasattr(app, 'apply_settings'):
            app.apply_settings(settings)
        
        # Set memory and note counts if attributes exist
        if 'Default Memory Count' in app_settings and hasattr(app, 'memories_count'):
            app.memories_count = app_settings['Default Memory Count']
            
        if 'Default Notes Count' in app_settings and hasattr(app, 'notes_count'):
            app.notes_count = app_settings['Default Notes Count']
    
    # Set turn mode from settings if available
    if hasattr(app, 'turn_manager') and 'Turn Mode' in turn_settings:
        mode = turn_settings['Turn Mode']
        if mode in ["memories", "time_units"]:
            app.turn_manager.set_turn_mode(mode)
            # Also update the UI if available
            if hasattr(app, 'turn_mode_var'):
                app.turn_mode_var.set("Memory-Based" if mode == "memories" else "Time Units")
    
    # Start the main loop
    root.mainloop()

if __name__ == "__main__":
    main()
---

## archive\gui.py

---python
import tkinter as tk
from tkinter import ttk, scrolledtext, simpledialog, messagebox
import threading
import time
import re
from minimind import Minimind
from world import World
from memory import MemoryViewer, NoteEditor
from llm_interface import OllamaInterface
from datetime import datetime

class MinimindGUI:
    def __init__(self, root):
        self.root = root
        
        # Initialize state
        self.world = World()
        self.miniminds = {}
        self.active_minimind = None
        self.player_name = "Player"
        self.turn_in_progress = False
        self.stop_streaming = threading.Event()
        
        # LLM interface
        self.llm = OllamaInterface()
        
        # Setup the GUI
        self.setup_theme()
        self.setup_layout()
        
        # Initialize world and miniminds
        self.load_miniminds()
        
        # Start with player's turn
        self.set_status("Your turn. Enter a command or action.")
        
        # Process "look" command initially to show the environment
        self.process_look_command()

    def setup_theme(self):
        """Configure the dark theme for the GUI"""
        style = ttk.Style()
        style.configure('.',
            background='#2b2b2b',
            foreground='#ffffff',
            fieldbackground='#2b2b2b'
        )
        
        # Create custom styles
        style.configure('Dark.TFrame', background='#2b2b2b')
        style.configure('Dark.TLabel', background='#2b2b2b', foreground='#ffffff')
        style.configure('Dark.TButton', background='#3d3d3d', foreground='#ffffff')
        style.map('Dark.TButton', 
                  background=[('active', '#4d4d4d')],
                  foreground=[('active', '#ffffff')])
        style.configure('Dark.TLabelframe', background='#2b2b2b', foreground='#ffffff', bordercolor='#555555')
        style.configure('Dark.TLabelframe.Label', background='#2b2b2b', foreground='#ffffff')

    def setup_layout(self):
        """Create the main GUI layout"""
        # Main paned window - three columns
        main_paned = ttk.PanedWindow(self.root, orient=tk.HORIZONTAL)
        main_paned.pack(fill="both", expand=True, padx=5, pady=5)
        
        # Left panel - Miniminds
        left_frame = ttk.Frame(main_paned, style='Dark.TFrame')
        
        # Middle panel - Interaction
        middle_frame = ttk.Frame(main_paned, style='Dark.TFrame')
        
        # Right panel - Debug
        right_frame = ttk.Frame(main_paned, style='Dark.TFrame')
        
        main_paned.add(left_frame, weight=1)
        main_paned.add(middle_frame, weight=2)
        main_paned.add(right_frame, weight=2)
        
        # Set up each panel
        self.setup_minimind_panel(left_frame)
        self.setup_interaction_panel(middle_frame)
        self.setup_debug_panel(right_frame)

    def setup_minimind_panel(self, parent):
        """Set up the minimind management panel"""
        minds_frame = ttk.LabelFrame(parent, text="Miniminds", padding=5, style='Dark.TLabelframe')
        minds_frame.pack(fill="both", expand=True)
        
        # Minimind controls
        controls_frame = ttk.Frame(minds_frame, style='Dark.TFrame')
        controls_frame.pack(fill="x", pady=(0, 5))
        
        ttk.Button(controls_frame, text="Create New", command=self.create_minimind, style='Dark.TButton').pack(side="left", padx=2)
        ttk.Button(controls_frame, text="Edit Selected", command=self.edit_minimind, style='Dark.TButton').pack(side="left", padx=2)
        ttk.Button(controls_frame, text="View Memories", command=self.view_memories, style='Dark.TButton').pack(side="left", padx=2)
        ttk.Button(controls_frame, text="View Notes", command=self.view_notes, style='Dark.TButton').pack(side="left", padx=2)
        
        # Minimind list
        self.mind_list = tk.Listbox(minds_frame, bg='#2b2b2b', fg='#ffffff', 
                                   selectbackground='#454545', selectforeground='#ffffff')
        self.mind_list.pack(fill="both", expand=True)
        self.mind_list.bind('<<ListboxSelect>>', self.on_select_minimind)

    def setup_interaction_panel(self, parent):
        """Set up the interaction panel"""
        # Prose log area (narration of what happens)
        prose_frame = ttk.LabelFrame(parent, text="World Events", padding=5, style='Dark.TLabelframe')
        prose_frame.pack(fill="both", expand=True, pady=(0, 5))
        
        self.prose_text = scrolledtext.ScrolledText(prose_frame, wrap=tk.WORD,
                                             bg='#2b2b2b', fg='#ffffff', insertbackground='#ffffff')
        self.prose_text.pack(fill="both", expand=True)
        
        # Log area (record of commands/actions)
        log_frame = ttk.LabelFrame(parent, text="Action Log", padding=5, style='Dark.TLabelframe')
        log_frame.pack(fill="both", expand=True, pady=(0, 5))
        
        self.log_text = scrolledtext.ScrolledText(log_frame, wrap=tk.WORD, height=8,
                                             bg='#2b2b2b', fg='#ffffff', insertbackground='#ffffff')
        self.log_text.pack(fill="both", expand=True)
        
        # Turn information
        turn_frame = ttk.Frame(parent, style='Dark.TFrame')
        turn_frame.pack(fill="x", pady=(0, 5))
        
        self.status_var = tk.StringVar(value="Ready")
        status_label = ttk.Label(turn_frame, textvariable=self.status_var, style='Dark.TLabel')
        status_label.pack(side="left")
        
        ttk.Button(turn_frame, text="Execute Minimind Turn", 
                  command=self.execute_minimind_turn, style='Dark.TButton').pack(side="right", padx=2)
        
        # User command entry
        cmd_frame = ttk.LabelFrame(parent, text="Your Action", padding=5, style='Dark.TLabelframe')
        cmd_frame.pack(fill="x")
        
        self.cmd_text = scrolledtext.ScrolledText(cmd_frame, height=3, wrap=tk.WORD,
                                             bg='#2b2b2b', fg='#ffffff', insertbackground='#ffffff')
        self.cmd_text.pack(fill="both", expand=True, pady=(0, 5))
        
        ttk.Button(cmd_frame, text="Submit", command=self.process_player_command, 
                  style='Dark.TButton').pack(side="right")
        
        # Bind Enter key to submit
        self.cmd_text.bind("<Control-Return>", lambda e: self.process_player_command())

    def setup_debug_panel(self, parent):
        """Set up the debug panel"""
        # Create vertical paned window for debug section
        debug_paned = ttk.PanedWindow(parent, orient=tk.VERTICAL)
        debug_paned.pack(fill="both", expand=True)
        
        # LLM settings at the top
        llm_frame = ttk.LabelFrame(debug_paned, text="LLM Settings", padding=5, style='Dark.TLabelframe')
        
        llm_controls = ttk.Frame(llm_frame, style='Dark.TFrame')
        llm_controls.pack(fill="x")
        
        ttk.Label(llm_controls, text="Model:", style='Dark.TLabel').pack(side="left")
        self.model_var = tk.StringVar(value=self.llm.model)
        model_entry = ttk.Entry(llm_controls, textvariable=self.model_var, width=20)
        model_entry.pack(side="left", padx=5)
        
        ttk.Label(llm_controls, text="Temperature:", style='Dark.TLabel').pack(side="left", padx=(10, 0))
        self.temp_var = tk.DoubleVar(value=self.llm.temperature)
        temp_entry = ttk.Entry(llm_controls, textvariable=self.temp_var, width=5)
        temp_entry.pack(side="left", padx=5)
        
        ttk.Label(llm_controls, text="Context Tokens:", style='Dark.TLabel').pack(side="left", padx=(10, 0))
        self.context_var = tk.IntVar(value=self.llm.context_tokens)
        context_entry = ttk.Entry(llm_controls, textvariable=self.context_var, width=6)
        context_entry.pack(side="left", padx=5)
        
        debug_paned.add(llm_frame, weight=1)
        
        # LLM prompt debug
        prompt_frame = ttk.LabelFrame(debug_paned, text="LLM Prompt", padding=5, style='Dark.TLabelframe')
        self.prompt_text = scrolledtext.ScrolledText(prompt_frame, wrap=tk.WORD,
                                               bg='#2b2b2b', fg='#ffffff', insertbackground='#ffffff')
        self.prompt_text.pack(fill="both", expand=True)
        debug_paned.add(prompt_frame, weight=3)
        
        # LLM response debug
        response_frame = ttk.LabelFrame(debug_paned, text="LLM Response (Streaming)", padding=5, style='Dark.TLabelframe')
        self.response_text = scrolledtext.ScrolledText(response_frame, wrap=tk.WORD,
                                                 bg='#2b2b2b', fg='#ffffff', insertbackground='#ffffff')
        self.response_text.pack(fill="both", expand=True)
        debug_paned.add(response_frame, weight=3)

    def load_miniminds(self):
        """Load existing miniminds from disk"""
        for item in Minimind.get_all_miniminds():
            minimind = Minimind(item)
            
            # Place the minimind in a random location
            if self.world.locations:
                minimind.set_location(self.world.get_random_location())
                # Add the minimind to the location
                self.world.add_character_to_location(minimind.name, minimind.location)
            
            self.miniminds[minimind.name] = minimind
            self.mind_list.insert(tk.END, minimind.name)
            
            # If we don't have a selected minimind yet, select this one
            if not self.active_minimind:
                self.active_minimind = minimind.name
                self.mind_list.selection_set(0)

    def create_minimind(self):
        """Create a new minimind"""
        name = simpledialog.askstring("New Minimind", "Enter name for new minimind:")
        if not name:
            return
            
        if name in self.miniminds:
            messagebox.showerror("Error", f"A minimind named '{name}' already exists.")
            return
        
        # Create the minimind
        minimind = Minimind.create_new(name)
            
        # Add to list and dictionary
        if self.world.locations:
            location = self.world.get_random_location()
            minimind.set_location(location)
            self.world.add_character_to_location(name, location)
            
            # Add prose about the new character
            self.add_prose(f"{name} has entered the world and is now in the {location}.")
        
        self.miniminds[name] = minimind
        self.mind_list.insert(tk.END, name)
        self.mind_list.selection_clear(0, tk.END)
        self.mind_list.selection_set(tk.END)
        self.on_select_minimind(None)

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
        MemoryViewer(self.root, minimind)

    def view_notes(self):
        """View the selected minimind's notes"""
        if not self.active_minimind:
            messagebox.showinfo("No Selection", "Please select a minimind to view notes.")
            return
            
        minimind = self.miniminds[self.active_minimind]
        NoteEditor(self.root, minimind)

    def on_select_minimind(self, event):
        """Handle selection of a minimind from the list"""
        selection = self.mind_list.curselection()
        if not selection:
            return
            
        self.active_minimind = self.mind_list.get(selection[0])
        self.set_status(f"Selected {self.active_minimind}")

    def process_player_command(self):
        """Process a command entered by the player"""
        if self.turn_in_progress:
            messagebox.showinfo("Busy", "Please wait for the current turn to complete.")
            return
            
        command = self.cmd_text.get("1.0", tk.END).strip()
        if not command:
            return
            
        # Log the command
        self.log_text.insert(tk.END, f"\n[{self.player_name}]: {command}\n")
        self.log_text.see(tk.END)
        
        # Create a memory for all miniminds about this action
        for minimind in self.miniminds.values():
            if minimind.location == self.world.current_location:
                minimind.add_observation_memory(self.player_name, command)
        
        # Clear command box
        self.cmd_text.delete("1.0", tk.END)
        
        # Handle basic commands
        if command.lower() == "look":
            self.process_look_command()
        elif command.lower().startswith("go to "):
            self.process_go_command(command)
        elif command.lower().startswith("say "):
            self.process_say_command(command)
        elif command.lower().startswith("examine "):
            self.process_examine_command(command)
        else:
            # Generic action
            self.add_prose(f"{self.player_name} {command}.")
        
        # Set status for minimind's turn
        self.set_status("Miniminds' turns next. Click 'Execute Minimind Turn' to continue.")

    def process_look_command(self):
        """Process the 'look' command to examine surroundings"""
        location = self.world.current_location
        location_data = self.world.get_location_data(location)
        description = location_data.get("description", "Nothing to see here.")
        
        # Construct a description of the location and its contents
        prose = f"You look around the {location}. {description}\n\n"
        
        # Show connections
        connections = location_data.get("connections", [])
        if connections:
            if len(connections) == 1:
                prose += f"You can go to the {connections[0]} from here.\n"
            else:
                conn_list = ", ".join(connections[:-1]) + " and " + connections[-1]
                prose += f"You can go to the {conn_list} from here.\n"
        
        # List characters in the location
        characters = location_data.get("characters", [])
        if len(characters) > 1:  # More than just the player
            other_chars = [char for char in characters if char != self.player_name]
            if other_chars:
                if len(other_chars) == 1:
                    prose += f"{other_chars[0]} is here.\n"
                else:
                    char_list = ", ".join(other_chars[:-1]) + " and " + other_chars[-1]
                    prose += f"{char_list} are here.\n"
        
        # Add the prose to the log
        self.add_prose(prose)

    def process_go_command(self, command):
        """Process a 'go to' command to move to a different location"""
        destination = command[6:].strip()
        if self.world.is_valid_location(destination):
            # Move player to new location
            self.world.move_character(self.player_name, destination)
            
            # Add prose
            self.add_prose(f"You go to the {destination}.")
            
            # Automatically look around
            self.process_look_command()
        else:
            if destination in self.world.locations:
                self.add_prose(f"You can't go to '{destination}' from here. It's not connected to your current location.")
            else:
                self.add_prose(f"There is no location called '{destination}'.")

    def process_say_command(self, command):
        """Process a 'say' command to speak"""
        message = command[4:].strip()
        self.add_prose(f"{self.player_name} says: \"{message}\"")

    def process_examine_command(self, command):
        """Process an 'examine' command to look at an object or character"""
        target = command[8:].strip()
        
        location = self.world.current_location
        location_data = self.world.get_location_data(location)
        
        # Check if it's a character
        characters = location_data.get("characters", [])
        for char in characters:
            if target.lower() == char.lower():
                if char == self.player_name:
                    self.add_prose(f"You examine yourself. You appear to be in good health.")
                elif char in self.miniminds:
                    # Get description from the minimind
                    traits = self.miniminds[char].get_traits()
                    if traits:
                        self.add_prose(f"You examine {char}. They appear to be {traits}.")
                    else:
                        self.add_prose(f"You examine {char}. They appear to be a normal person.")
                return
        
        # If it's not a character, give a generic response
        self.add_prose(f"You examine the {target}. Nothing special about it.")

    def execute_minimind_turn(self):
        """Execute a turn for the selected minimind"""
        if not self.active_minimind:
            messagebox.showinfo("No Selection", "Please select a minimind to execute its turn.")
            return
            
        if self.turn_in_progress:
            return
            
        self.turn_in_progress = True
        self.set_status(f"Processing {self.active_minimind}'s turn...")
        
        # Reset stop streaming flag
        self.stop_streaming.clear()
        
        # Clear response text
        self.response_text.delete("1.0", tk.END)
        
        # Start in a separate thread to avoid blocking the UI
        threading.Thread(target=self.run_minimind_turn, daemon=True).start()

    def run_minimind_turn(self):
        """Run the minimind turn in a separate thread"""
        try:
            # Get the active minimind
            minimind = self.miniminds[self.active_minimind]
            
            # Get location data
            location_data = self.world.get_location_data(minimind.location)
            
            # Construct prompt for the LLM
            prompt = minimind.construct_prompt(location_data)
            
            # Update LLM settings
            self.llm.model = self.model_var.get()
            self.llm.temperature = self.temp_var.get()
            self.llm.context_tokens = self.context_var.get()
            
            # Show prompt in debug window
            self.root.after(0, lambda: self.update_prompt_text(prompt))
            
            # Call LLM to get minimind's action with streaming
            self.llm.query_streaming(
                prompt, 
                on_chunk=self.handle_response_chunk,
                on_complete=self.handle_response_complete,
                on_error=self.handle_response_error
            )
            
            # Wait for streaming to complete
            while self.turn_in_progress and not self.stop_streaming.is_set():
                time.sleep(0.1)
                
        except Exception as e:
            self.root.after(0, lambda: self.set_status(f"Error: {str(e)}"))
            self.turn_in_progress = False

    def handle_response_chunk(self, chunk):
        """Handle a chunk of text from the streaming response"""
        self.root.after(0, lambda text=chunk: self.append_response_text(text))

    def handle_response_complete(self, full_response):
        """Handle completion of the response"""
        # Clean action - parse the response to extract just the command
        cleaned_action = self.clean_llm_response(full_response)
        
        # Process the action
        self.root.after(0, lambda: self.process_minimind_action(cleaned_action))
        
        # Set the stop event
        self.stop_streaming.set()

    def handle_response_error(self, error):
        """Handle an error from the LLM"""
        self.root.after(0, lambda: self.update_response_text(f"Error: {str(error)}\n"))
        self.turn_in_progress = False
        self.stop_streaming.set()

    def clean_llm_response(self, response):
        """Clean the LLM response to extract just the command"""
        
        # First, check if there's a <think>...</think> block and remove it
        think_pattern = re.compile(r'<think>.*?</think>', re.DOTALL)
        response_cleaned = think_pattern.sub('', response).strip()
        
        # If there's anything left after removing thinking blocks, use that
        if response_cleaned:
            # Split into lines and find the first non-empty line
            lines = response_cleaned.strip().split('\n')
            for line in lines:
                line = line.strip()
                if line:
                    return line
        
        # If we removed everything or the pattern didn't match, use the original cleaning logic
        lines = response.strip().split('\n')
        for line in lines:
            # Skip empty lines, thinking sections, or explanation lines
            line = line.strip()
            if not line or line.startswith('<') or line.startswith('#') or line.startswith('-'):
                continue
            return line
                
        # Fallback to the stripped response
        return response.strip()

    def process_minimind_action(self, action):
        """Process the action from a minimind"""
        # Get the active minimind
        minimind = self.miniminds[self.active_minimind]
        
        # Log the action
        self.log_text.insert(tk.END, f"\n[{self.active_minimind}]: {action}\n")
        self.log_text.see(tk.END)
        
        # Create a memory for the minimind about this action
        minimind.add_action_memory(action)
        
        # Create a memory for all other miniminds about this action
        for other_name, other_minimind in self.miniminds.items():
            if other_name != self.active_minimind and other_minimind.location == minimind.location:
                other_minimind.add_observation_memory(self.active_minimind, action)
        
        # Handle basic commands
        if action.lower() == "look":
            self.process_minimind_look(minimind)
        elif action.lower().startswith("go to "):
            self.process_minimind_go(minimind, action)
        elif action.lower().startswith("say "):
            self.process_minimind_say(minimind, action)
        elif action.lower().startswith("talk to "):
            self.process_minimind_talk(minimind, action)
        elif action.lower().startswith("examine "):
            self.process_minimind_examine(minimind, action)
        else:
            # Generic action
            self.add_prose(f"{self.active_minimind} {action}.")
        
        # Turn complete
        self.turn_in_progress = False
        self.set_status("Your turn. Enter a command or action.")

    def process_minimind_look(self, minimind):
        """Process a minimind's 'look' command"""
        self.add_prose(f"{minimind.name} looks around the {minimind.location}.")

    def process_minimind_go(self, minimind, action):
        """Process a minimind's 'go to' command"""
        destination = action[6:].strip()
        
        # Check if destination exists and is connected
        current_location = minimind.location
        current_connections = self.world.locations.get(current_location, {}).get("connections", [])
        
        if destination in self.world.locations and destination in current_connections:
            # Move minimind to new location
            self.world.move_character(minimind.name, destination)
            minimind.set_location(destination)
            
            # Add prose
            self.add_prose(f"{minimind.name} goes to the {destination}.")
        else:
            if destination in self.world.locations:
                self.add_prose(f"{minimind.name} tries to go to {destination}, but can't reach it from their current location.")
            else:
                self.add_prose(f"{minimind.name} tries to go to {destination}, but can't find it.")

    def process_minimind_say(self, minimind, action):
        """Process a minimind's 'say' command"""
        message = action[4:].strip()
        self.add_prose(f"{minimind.name} says: \"{message}\"")

    def process_minimind_talk(self, minimind, action):
        """Process a minimind's 'talk to' command"""
        target = action[8:].strip()
        
        # Check if target is in the same location
        location_data = self.world.get_location_data(minimind.location)
        characters_here = location_data.get("characters", [])
        
        if target in characters_here:
            self.add_prose(f"{minimind.name} engages {target} in conversation.")
            
            # Create a memory of this interaction for both characters
            if target != self.player_name and target in self.miniminds:
                self.miniminds[target].add_observation_memory(minimind.name, "talked to me")
        else:
            self.add_prose(f"{minimind.name} wants to talk to {target}, but they aren't here.")

    def process_minimind_examine(self, minimind, action):
        """Process a minimind's 'examine' command"""
        target = action[8:].strip()
        self.add_prose(f"{minimind.name} examines {target} carefully.")

    def add_prose(self, text):
        """Add prose text to the world events log"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.prose_text.insert(tk.END, f"[{timestamp}] {text}\n\n")
        self.prose_text.see(tk.END)

    def update_prompt_text(self, text):
        """Update the prompt text debug area"""
        self.prompt_text.delete("1.0", tk.END)
        self.prompt_text.insert(tk.END, text)
        self.prompt_text.see(tk.END)

    def update_response_text(self, text):
        """Update the response text debug area"""
        self.response_text.delete("1.0", tk.END)
        self.response_text.insert(tk.END, text)
        self.response_text.see(tk.END)

    def append_response_text(self, text):
        """Append text to the response text debug area"""
        self.response_text.insert(tk.END, text)
        self.response_text.see(tk.END)

    def set_status(self, message):
        """Set the status message"""
        self.status_var.set(message)
        self.root.update_idletasks()---

## command_processor.py

---python
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

---
{reason}
---

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
            if command.lower().startswith("note "):
                # Extract title and content
                note_pattern = r"note\s+([^:]+):\s*(.+)"
                match = re.match(note_pattern, command, re.IGNORECASE)
                
                if match and hasattr(agent, 'add_note_command'):
                    title = match.group(1).strip()
                    content = match.group(2).strip()
                    
                    # Create the note with the reason
                    agent.add_note_command(title, content, original_reason)
            
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

    def world_event_callback(self, character_name, event_type, description, data):
        """Callback for world events to create memories for miniminds and update memory counts"""
        # Get the event and character locations
        event_location = data.get("location", None)
        
        # Extract actor from data
        actor = data.get("actor", "unknown")
        
        # For movement events, we need both origin and destination
        origin_location = data.get("origin", None)
        destination_location = data.get("destination", None)
        
        # If location isn't specified directly, try to get it from the actor
        if not event_location and actor in data:
            event_location = self.gui.world.get_character_location(actor)
        
        char_location = self.gui.world.get_character_location(character_name)
        
        # Create a unique ID for UI event deduplication
        ui_event_id = f"ui:{event_type}:{actor}:{description}"
        
        # Check if an original reason exists in the data
        original_reason = data.get("original_reason", None)
        
        # Create structured event data for logging
        reason = None
        additional_info = None
        
        # Use original_reason if available
        if original_reason:
            reason = original_reason
        else:
            # Default reasons based on event type
            if event_type == "speech":
                reason = "Communication"
                additional_info = f"Said message: {data.get('message', 'unknown')}"
            elif event_type == "shout":
                reason = "Loud communication heard by everyone"
                additional_info = f"Shouted message: {data.get('message', 'unknown')}"
            elif event_type == "emote":
                reason = "Character expression or action"
                additional_info = f"Action: {data.get('action', 'unknown')}"
            elif event_type == "movement":
                reason = "Movement between locations"
                additional_info = f"From {origin_location} to {destination_location} via {data.get('via', 'walking')}"
            elif event_type == "observation":
                reason = "Observed activity"
                additional_info = f"Observed: {data.get('action', 'unknown')}"
        
        # Create list of observers - who actually saw/heard this event
        observers = []
        if event_type == "shout":
            # For shouts, all characters hear it regardless of location
            for loc_data in self.gui.world.locations.values():
                observers.extend(loc_data.get("characters", []))
        elif event_type == "movement":
            # For movements, characters in both origin and destination locations are observers
            for loc_name, loc_data in self.gui.world.locations.items():
                if loc_name == origin_location or loc_name == destination_location:
                    observers.extend(loc_data.get("characters", []))
        else:
            # For other events, only characters in the relevant location saw it
            for loc_name, loc_data in self.gui.world.locations.items():
                if loc_name == event_location:
                    observers.extend(loc_data.get("characters", []))

        # Remove duplicates
        observers = list(set(observers))

        # Create detailed data for the event - explicitly include the message
        if event_type == "movement":
            additional_info = f"From {origin_location} to {destination_location} via {data.get('via', 'walking')}"
        elif event_type == "emote":
            additional_info = f"Performed action: {data.get('action', 'unknown')}"
        else:
            additional_info = f"Standard {event_type} event"

        # Create structured event for logging with observers
        structured_event = format_structured_event(
            event_type, 
            actor, 
            description.replace(f"{actor} ", ""),  # Remove actor from description
            event_location or destination_location or origin_location or "unknown",
            reason,
            data.get("target", None),
            additional_info,
            observers  # Pass the observers list to the function
        )
        
        # Add type to structured event for better filtering
        structured_event["type"] = event_type
        
        # Explicitly add message or action for speech, shout, and emote events
        if event_type in ["speech", "shout"] and "message" in data:
            structured_event["message"] = data["message"]
        elif event_type == "emote" and "action" in data:
            structured_event["action"] = data["action"]
        
        # Create event data for deduplication
        event_data = {
            "actor": actor,
            "action": description,
            "location": event_location or destination_location or origin_location,
            "timestamp": structured_event["timestamp"],
            "type": event_type
        }
        
        # Check for duplicates
        is_duplicate = False
        for recent in self.recent_events:
            if (recent["actor"] == event_data["actor"] and 
                recent["action"] == event_data["action"] and
                recent["location"] == event_data["location"] and
                recent["type"] == event_data["type"]):
                
                # Check time proximity
                recent_time = datetime.strptime(recent["timestamp"], "%H:%M:%S") 
                current_time = datetime.strptime(event_data["timestamp"], "%H:%M:%S")
                
                # If events happened within 2 seconds, consider duplicate
                if abs((current_time - recent_time).total_seconds()) < 2:
                    is_duplicate = True
                    break
        
        # Only log if not a duplicate
        if not is_duplicate:
            # Add to recent events
            self.recent_events.append(event_data)
            
            # Log event to World Events panel (GM view)
            if ui_event_id not in self.processed_events:
                self.processed_events.add(ui_event_id)
                
                # Enhanced logging with structured format
                location_info = f"in {event_location}" if event_location else ""
                if event_type == "movement":
                    location_info = f"from {origin_location} to {destination_location}"
                        
                add_world_event(self.gui, f"[{event_type}] {location_info}: {description}", structured_event)
        
        # Determine if character should be aware of this event
        should_process = False
        
        # For shouts, all characters hear it regardless of location
        if event_type == "shout":
            should_process = True
        # For movement events, character should be aware if they are in either the origin or destination
        elif event_type == "movement":
            if char_location == origin_location or char_location == destination_location:
                should_process = True
        # Standard same-location check for other events
        elif char_location == event_location:
            should_process = True
                
        # If character shouldn't process this event, exit
        if not should_process:
            return
        
        # Character is in a relevant location, process the event
        
        # For player, add to player view and create memory
        if character_name == self.gui.player.name:
            # Skip redundant messages for player's own actions
            if actor == character_name:
                # For player's own movements, we'll just show the look result from the destination
                # Don't show movement notifications for the player's own movements
                if event_type == "movement":
                    return
                    
                # For player's own speech, don't echo it back
                if event_type == "speech" or event_type == "shout":
                    return
                    
                # For player's own observations or emotes, don't echo them back
                if event_type in ["observation", "emote"]:
                    return
                    
            # For other events, show them with the structured data for better formatting
            add_player_view(self.gui, description, structured_event)
            
            # Create a memory for the player
            if actor != character_name:  # Don't create memories for the player's own actions
                if event_type == "observation":
                    self.gui.player.add_memory("observed", f"{actor} {data.get('action', 'did something')}", "Observed activity")
                elif event_type == "speech":
                    self.gui.player.add_memory("observed", f"{actor} said: \"{data['message']}\"", "Heard someone speaking")
                elif event_type == "shout":
                    self.gui.player.add_memory("observed", f"{actor} shouted: \"{data['message']}\"", "Heard a shout")
                elif event_type == "emote":
                    self.gui.player.add_memory("observed", f"{actor} {data.get('action', 'did something')}", "Observed an action")
                elif event_type == "movement":
                    if char_location == origin_location:
                        self.gui.player.add_memory("observed", 
                                                  f"{actor} {data.get('via', 'moved')} to {destination_location}", 
                                                  "Saw someone leave")
                    elif char_location == destination_location:
                        self.gui.player.add_memory("observed", 
                                                  f"{actor} {data.get('via', 'moved')} from {origin_location}", 
                                                  "Saw someone arrive")
        
        # For miniminds, create a memory of the event and increment memory count
        elif character_name in self.gui.miniminds:
            minimind = self.gui.miniminds[character_name]
            
            # Don't create memory if minimind is the one who performed the action
            if actor == character_name:
                # For actions the agent itself performed, use its original reason
                return
            
            # Create appropriate memory based on event type
            if event_type == "observation":
                memory_reason = "Noticed someone doing something in my location"
                minimind.add_observation_memory(actor, data.get("action", "did something"), memory_reason)
                
            elif event_type == "speech":
                memory_reason = "Heard someone speaking in my location"
                minimind.add_observation_memory(actor, f"said: \"{data['message']}\"", memory_reason)
                
            elif event_type == "shout":
                # Get the origin location for the shout from the data
                origin_location = data.get("origin_location", data.get("location", "unknown location"))
                memory_reason = "Heard someone shouting a message"
                # Include the origin location in the memory
                minimind.add_observation_memory(actor, f"shouted from {origin_location}: \"{data['message']}\"", memory_reason)
                
            elif event_type == "emote":
                memory_reason = "Observed someone performing an action"
                # Extract the action from the data
                action = data.get("action", "did something")
                minimind.add_observation_memory(actor, action, memory_reason)
                
            elif event_type == "movement":
                # Create different observations based on character's perspective
                if char_location == origin_location:
                    # Character was in the origin location - they saw someone leave
                    movement_type = data.get("via", "moved")
                    memory_reason = "Someone left my location"
                    minimind.add_observation_memory(actor, f"{movement_type} to {destination_location} from {origin_location}", memory_reason)
                elif char_location == destination_location:
                    # Character was in the destination location - they saw someone arrive
                    movement_type = data.get("via", "moved")
                    memory_reason = "Someone entered my location"
                    minimind.add_observation_memory(actor, f"{movement_type} to {destination_location} from {origin_location}", memory_reason)
            
            # Increment memory count in turn manager
            # Don't increment for events the character itself created
            if actor != character_name:
                self.gui.turn_manager.increment_memory_count(character_name)

    def register_minimind_observers(self):
        """Register all miniminds and the player as observers with the world"""
        from core.event_bus import EventBus
        event_bus = EventBus.get_instance()
        
        # Only register player if not already registered
        if not hasattr(self, 'player_observer_registered') or not self.player_observer_registered:
            event_bus.register(self.gui.player.name, 
                lambda event_type, desc, data: 
                    self.world_event_callback(self.gui.player.name, event_type, desc, data))
        
        # Then register all miniminds
        for name, minimind in self.gui.miniminds.items():
            event_bus.register(name, 
                lambda event_type, desc, data, char_name=name: 
                    self.world_event_callback(char_name, event_type, desc, data))
        
        # Log that observers are registered
        print(f"Registered {len(self.gui.miniminds) + 1} observers with event bus")---

## core\__init__.py

---python
# Initializes the core package
# This file makes the 'core' directory a Python package

# Version info
__version__ = "0.1.0"
---

## core\agent.py

---python
import os
from datetime import datetime
import uuid
import re

class Agent:
    """
    Base class for all agents (players and miniminds)
    
    This provides the common functionality that both player and minimind agents
    will share, ensuring consistent behavior and state management.
    """
    def __init__(self, name):
        """Initialize an agent with the given name"""
        self.name = name
        self.path = None  # To be set by subclasses
        self.location = None
        self.last_command = None
        self.last_command_result = None
        self.last_command_reason = None
        self.last_thought_chain = None
        
    def get_location(self):
        """Get the agent's current location"""
        return self.location
        
    def set_location(self, location):
        """Set the agent's location"""
        self.location = location
    
    def add_memory(self, memory_type, content, reason=None):
        """
        Add a memory to the agent's memory store
        
        Args:
            memory_type: Type of memory (e.g., 'action', 'observed', 'response')
            content: The content of the memory
            reason: The reason for creating this memory
        """
        raise NotImplementedError("Subclasses must implement this method")
    
    def get_memories(self, max_count=64):
        """
        Get the agent's recent memories
        
        Args:
            max_count: Maximum number of memories to retrieve
            
        Returns:
            List of memory objects
        """
        raise NotImplementedError("Subclasses must implement this method")
    
    def get_relevant_memories(self, query, max_count=10):
        """
        Get memories relevant to a specific query
        
        Args:
            query: The search query
            max_count: Maximum number of relevant memories to retrieve
            
        Returns:
            List of relevant memories
        """
        raise NotImplementedError("Subclasses must implement this method")
    
    def create_note(self, title, content, reason=None):
        """
        Create a new note or update an existing one
        
        Args:
            title: The note title
            content: The note content
            reason: Reason for creating the note
            
        Returns:
            The filename of the created/updated note
        """
        raise NotImplementedError("Subclasses must implement this method")
    
    def get_notes(self, max_count=5):
        """
        Get the agent's recent notes
        
        Args:
            max_count: Maximum number of notes to retrieve
            
        Returns:
            List of note objects
        """
        raise NotImplementedError("Subclasses must implement this method")
    
    def store_last_command(self, command, result):
        """
        Store the last command and its result
        
        Args:
            command: The command that was executed
            result: The result of the command
        """
        self.last_command = command
        self.last_command_result = result
    
    def store_thought_chain(self, thought_chain):
        """
        Store the agent's chain of thought
        
        Args:
            thought_chain: The chain of thought text
        """
        self.last_thought_chain = thought_chain
    
    def get_last_thought_chain(self):
        """Get the agent's last chain of thought"""
        return getattr(self, 'last_thought_chain', None)
    
    def get_last_command_info(self):
        """
        Get the agent's last command and result
        
        Returns:
            Tuple of (command, result)
        """
        command = getattr(self, 'last_command', None)
        result = getattr(self, 'last_command_result', None)
        return command, result
---

## core\event_bus.py

---python
from datetime import datetime
from collections import defaultdict

class EventBus:
    """Central event bus for all world events"""
    
    _instance = None
    
    @classmethod
    def get_instance(cls):
        """Get the singleton instance of the EventBus"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
    
    def __init__(self):
        """Initialize the event bus"""
        # Store observers by character name
        self.observers = defaultdict(list)  # {character_name: [callbacks]}
        # Track recent events for deduplication
        self.recent_events = []
        self.max_recent_events = 30
    
    def register(self, character_name, callback):
        """Register an observer to receive events
        
        Args:
            character_name: The name of the character to receive events
            callback: Function to call with (event_type, description, data)
        """
        if callback not in self.observers[character_name]:
            self.observers[character_name].append(callback)
    
    def unregister(self, character_name, callback=None):
        """Unregister an observer
        
        Args:
            character_name: The name of the character
            callback: Specific callback to remove, or None to remove all
        """
        if callback is None:
            # Remove all callbacks for this character
            self.observers[character_name] = []
        else:
            # Remove specific callback
            if character_name in self.observers and callback in self.observers[character_name]:
                self.observers[character_name].remove(callback)
    
    def is_duplicate_event(self, event):
        """Check if an event is a duplicate of a recent event
        
        Args:
            event: The event to check
            
        Returns:
            bool: True if the event is a duplicate
        """
        for recent in self.recent_events:
            if (recent["actor"] == event["actor"] and 
                recent["action"] == event["action"] and
                recent["location"] == event["location"] and
                recent["event_type"] == event["event_type"]):
                
                # If event happened within last 2 seconds, consider duplicate
                recent_time = datetime.strptime(recent["timestamp"], "%Y-%m-%d %H:%M:%S")
                current_time = datetime.strptime(event["timestamp"], "%Y-%m-%d %H:%M:%S")
                
                if abs((current_time - recent_time).total_seconds()) < 2:
                    return True
        return False
    
    def publish(self, event_type, description, data, recipients=None):
        """Publish an event to relevant observers
        
        Args:
            event_type: Type of event (e.g., 'speech', 'movement')
            description: Human-readable description of the event
            data: Dictionary with event details
            recipients: List of character names to receive the event,
                        or None to determine automatically
        """
        # Add timestamp to data
        if "timestamp" not in data:
            data["timestamp"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Add event type to data for easier handling
        data["event_type"] = event_type
        
        # Create event record for deduplication
        event_record = {
            "actor": data.get("actor", "unknown"),
            "action": description,
            "location": data.get("location", "unknown"),
            "timestamp": data["timestamp"],
            "event_type": event_type
        }
        
        # Check for duplicates
        if self.is_duplicate_event(event_record):
            return
        
        # Add to recent events
        self.recent_events.append(event_record)
        if len(self.recent_events) > self.max_recent_events:
            self.recent_events.pop(0)  # Remove oldest
        
        # Determine recipients if not specified
        if recipients is None:
            recipients = self._determine_recipients(event_type, data)
        
        # Notify all recipients
        for character in recipients:
            if character in self.observers:
                for callback in self.observers[character]:
                    try:
                        callback(event_type, description, data)
                    except Exception as e:
                        print(f"Error notifying {character}: {str(e)}")
    
    def _determine_recipients(self, event_type, data):
        """Determine which characters should receive an event
        
        Args:
            event_type: Type of event
            data: Event data
            
        Returns:
            list: Character names that should receive the event
        """
        # Access World to determine recipients based on location
        from world import World
        world = World.get_instance()
        
        location = data.get("location")
        origin = data.get("origin")
        destination = data.get("destination")
        
        recipients = []
        
        if event_type == "shout":
            # Shouts are heard by everyone
            for loc_data in world.locations.values():
                recipients.extend(loc_data.get("characters", []))
        elif event_type == "movement":
            # Characters in origin and destination locations
            for loc_name, loc_data in world.locations.items():
                if loc_name == origin or loc_name == destination:
                    recipients.extend(loc_data.get("characters", []))
        elif location:
            # For other events, only characters in the location
            if location in world.locations:
                recipients.extend(world.locations[location].get("characters", []))
        
        # Remove duplicates
        return list(set(recipients))---

## core\player.py

---python
import os
from datetime import datetime
import uuid
import re
from core.agent import Agent
from markdown_utils import MarkdownVault

class Player(Agent):
    """
    Player agent implementation that inherits from Agent base class
    
    Represents the human player in the system, with the same capabilities
    as minimind agents but with different UI interaction.
    """
    def __init__(self, name="⚪", llm_interface=None):
        """Initialize a player with the given name"""
        super().__init__(name)
        self.path = os.path.join("agents", "player")
        self.llm_interface = llm_interface
        
        # Ensure directories exist
        self._ensure_directories()
        
        # Create default profile if it doesn't exist
        if not os.path.exists(os.path.join(self.path, "profile.md")):
            self._create_default_profile()
        
        # Load profile
        self.profile = self._load_profile()
        
        # Load templates
        self.memory_format = MarkdownVault.load_template("memory_format")
        self.note_format = MarkdownVault.load_template("note_format")
    
    def _ensure_directories(self):
        """Ensure required directories exist"""
        os.makedirs(self.path, exist_ok=True)
        os.makedirs(os.path.join(self.path, "memories"), exist_ok=True)
        os.makedirs(os.path.join(self.path, "notes"), exist_ok=True)
    
    def _create_default_profile(self):
        """Create a default profile for the player"""
        profile_content = "# Player Profile\n\n"
        profile_content += "## Traits\nCurious, adaptable, observant\n\n"
        profile_content += "## Background\nA visitor exploring the world of Smallville.\n\n"
        profile_content += "## Goals\nTo understand and interact with the residents of Smallville."
        
        with open(os.path.join(self.path, "profile.md"), "w") as f:
            f.write(profile_content)
    
    def _load_profile(self):
        """Load the player's profile"""
        profile_path = os.path.join(self.path, "profile.md")
        if os.path.exists(profile_path):
            with open(profile_path, "r") as f:
                return f.read()
        return ""
    
    def get_memories(self, max_count=64):
        """Get the player's recent memories"""
        memories_path = os.path.join(self.path, "memories")
        memory_files = []
        
        if os.path.exists(memories_path):
            for item in os.listdir(memories_path):
                if item.endswith(".md"):
                    memory_files.append(item)
            
            # Sort by timestamp (newest first)
            memory_files.sort(reverse=True)
            
            # Take most recent memories
            memories = []
            for mem_file in memory_files[:max_count]:
                with open(os.path.join(memories_path, mem_file), "r") as f:
                    memories.append(f.read())
            
            return memories
        
        return []
    
    def get_relevant_memories(self, query, max_count=10):
        """
        Get memories relevant to a specific query
        For the player, this is a simple implementation that could be
        enhanced later with vector search like the minimind version
        """
        # For now, just return recent memories
        memories = self.get_memories(max_count * 2)
        
        # Do basic keyword matching
        relevant_memories = []
        for memory in memories:
            if query.lower() in memory.lower():
                relevant_memories.append(memory)
                if len(relevant_memories) >= max_count:
                    break
        
        # If we didn't find enough relevant memories, add recent ones
        if len(relevant_memories) < max_count:
            for memory in memories:
                if memory not in relevant_memories:
                    relevant_memories.append(memory)
                    if len(relevant_memories) >= max_count:
                        break
        
        return relevant_memories
    
    def get_notes(self, max_count=5):
        """Get the player's most recent notes"""
        notes_path = os.path.join(self.path, "notes")
        note_files = []
        
        if os.path.exists(notes_path):
            # Get all note files with their modification times
            note_files_with_times = []
            for item in os.listdir(notes_path):
                if item.endswith(".md"):
                    file_path = os.path.join(notes_path, item)
                    mod_time = os.path.getmtime(file_path)
                    note_files_with_times.append((item, mod_time))
            
            # Sort by modification time (newest first)
            note_files_with_times.sort(key=lambda x: x[1], reverse=True)
            
            # Take most recent notes
            notes = []
            for note_file, _ in note_files_with_times[:max_count]:
                with open(os.path.join(notes_path, note_file), "r") as f:
                    notes.append(f.read())
            
            return notes
        
        return []
    
    def create_note(self, title, content, reason=None):
        """Create a new note or update an existing one"""
        # Create a safe filename without timestamp
        safe_title = re.sub(r'[^\w\s-]', '', title).strip().replace(' ', '-').lower()
        
        # Check if a note with this title already exists
        notes_dir = os.path.join(self.path, "notes")
        os.makedirs(notes_dir, exist_ok=True)
        
        existing_file = None
        for filename in os.listdir(notes_dir):
            if filename.endswith('.md'):
                file_path = os.path.join(notes_dir, filename)
                with open(file_path, 'r') as f:
                    first_line = f.readline().strip()
                    if first_line == f"# {title}":
                        existing_file = filename
                        break
        
        # Determine the note_id and filename to use
        if existing_file:
            note_id = os.path.splitext(existing_file)[0]  # Remove .md extension
            final_filename = existing_file
        else:
            # Create a note ID based on the title
            note_id = safe_title
            final_filename = f"{note_id}.md"
        
        # Get current time and location for metadata
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        location = self.location or "unknown location"
        
        # Prepare data for note template
        note_data = {
            "title": title,
            "title_lower": title.lower(),
            "characters": self.name,  # Just include player for now
            "location": location,
            "current_time": current_time,
            "reason": reason or "Personal note",
            "content": content
        }
        
        # Fill the note template
        note_content = MarkdownVault.fill_template(self.note_format, note_data)
        
        # Create or update the note file
        file_path = os.path.join(notes_dir, final_filename)
        with open(file_path, "w") as f:
            f.write(note_content)
        
        return final_filename
    
    def add_memory(self, memory_type, content, reason=None):
        """Add a memory to the player's memory store"""
        self._add_memory(memory_type, content, reason)
    
    def _add_memory(self, memory_type, content, reason=None):
        """Internal method to add a memory to the player's memory store"""
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        memory_id = str(uuid.uuid4())[:8]  # Create a short unique ID
        filename = f"{timestamp}-{memory_type}.md"
        
        memories_dir = os.path.join(self.path, "memories")
        os.makedirs(memories_dir, exist_ok=True)
        memory_path = os.path.join(memories_dir, filename)
        
        # Get current time for the memory
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Use the provided reason or a default
        why = reason or "Player experience"
        
        # Prepare data for memory template
        memory_data = {
            "memory_type": memory_type.capitalize(),
            "memory_id": memory_id,
            "who": self.name,
            "what": content,
            "where": self.location or "unknown",
            "when": current_time,
            "why": why,
            "how": memory_type
        }
        
        # Fill the memory template
        memory_content = MarkdownVault.fill_template(self.memory_format, memory_data)
        
        with open(memory_path, "w") as f:
            f.write(memory_content)
    
    def add_response_memory(self, action, response, reason=None):
        """Add a memory of a response to an action"""
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        memory_id = str(uuid.uuid4())[:8]
        memory_path = os.path.join(self.path, "memories", f"{timestamp}-response.md")
        
        # Get current time for the memory
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Use the provided reason or a default
        why = reason or "Response to action"
        
        # Prepare memory data
        memory_data = {
            "memory_type": "Response",
            "memory_id": memory_id,
            "who": self.name,
            "what": response,
            "where": self.location or "unknown",
            "when": current_time,
            "why": why,
            "how": action
        }
        
        # Fill the memory template
        memory_content = MarkdownVault.fill_template(self.memory_format, memory_data)
        
        # Ensure the memories directory exists
        memories_dir = os.path.join(self.path, "memories")
        os.makedirs(memories_dir, exist_ok=True)
        
        # Save the memory
        with open(memory_path, "w") as f:
            f.write(memory_content)
            
    def save_turn_details(self, prompt, system_prompt, llm_response, parsed_command, command_result):
        """Save details of a turn to a file for analysis
        
        Args:
            prompt: The full prompt sent to the LLM
            system_prompt: The system prompt used (if any)
            llm_response: The full response from the LLM
            parsed_command: The parsed command extracted from the response
            command_result: The result of executing the command
        """
        # Create a turns directory if it doesn't exist
        turns_dir = os.path.join(self.path, "turns")
        os.makedirs(turns_dir, exist_ok=True)
        
        # Create a timestamped filename
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        filename = f"{timestamp}-turn.md"
        filepath = os.path.join(turns_dir, filename)
        
        # Format the content
        content = f"""# Turn Details for {self.name} at {timestamp}

    ## Prompt
    {prompt or "None provided"}


    ## Response
    {llm_response or "None provided"}


    ## Parsed Command
    {parsed_command or "None provided"}


    ## Result
    {command_result or "None provided"}"""
        
        # Write to file
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        
        return filepath---

## cot_perturb.py

---python
import random
import re

def perturb_chain_of_thought(cot_text):
    """
    Perturbs a chain of thought to maintain semantic content while breaking repetition patterns.
    Uses a combination of paragraph sampling, shuffling, and selective token masking.
    
    Args:
        cot_text (str): The original chain of thought text
        
    Returns:
        str: A perturbed version of the chain of thought
    """
    if not cot_text or len(cot_text) < 20:
        return cot_text
        
    # Split into paragraphs (preserving any line breaks)
    paragraphs = [p for p in re.split(r'\n\s*\n', cot_text) if p.strip()]
    
    if len(paragraphs) <= 1:
        # If there's only one paragraph, split by sentences instead
        sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', cot_text) if s.strip()]
        
        if len(sentences) <= 3:
            # For very short content, just do light masking
            return mask_tokens(cot_text)
            
        # Sample 70-90% of sentences
        sampling_ratio = random.uniform(0.7, 0.9)
        num_to_keep = max(3, int(len(sentences) * sampling_ratio))
        kept_sentences = random.sample(sentences, num_to_keep)
        
        # Shuffle the order slightly (not completely)
        if len(kept_sentences) > 3:
            segments = chunk_list(kept_sentences, max(2, len(kept_sentences) // 3))
            random.shuffle(segments)
            kept_sentences = [sent for segment in segments for sent in segment]
        
        # Apply light token masking
        for i in range(len(kept_sentences)):
            kept_sentences[i] = mask_tokens(kept_sentences[i], mask_probability=0.08)
        
        return ' '.join(kept_sentences)
    else:
        # For multi-paragraph text
        # Sample 60-80% of paragraphs
        sampling_ratio = random.uniform(0.6, 0.8)
        num_to_keep = max(2, int(len(paragraphs) * sampling_ratio))
        kept_paragraphs = random.sample(paragraphs, num_to_keep)
        
        # Shuffle the order slightly (keeping some logical flow)
        if len(kept_paragraphs) > 3:
            segments = chunk_list(kept_paragraphs, max(2, len(kept_paragraphs) // 3))
            random.shuffle(segments)
            kept_paragraphs = [para for segment in segments for para in segment]
        
        # Apply token masking and return
        perturbed_paragraphs = [mask_tokens(p, mask_probability=0.05) for p in kept_paragraphs]
        return '\n\n'.join(perturbed_paragraphs)

def mask_tokens(text, mask_probability=0.1):
    """Mask random tokens/words in text, focusing on adjectives and adverbs"""
    # Skip very short texts
    if len(text) < 15:
        return text
    
    # Split into words, preserving spaces and punctuation
    tokens = re.findall(r'\b\w+\b|[^\w\s]|\s+', text)
    
    # Define adjective/adverb ending patterns (higher chance of masking these)
    adj_adv_patterns = [r'ly$', r'ous$', r'ful$', r'ish$', r'ive$', r'est$']
    
    for i, token in enumerate(tokens):
        if not re.match(r'\w+', token):  # Skip punctuation and whitespace
            continue
            
        # Higher probability for longer words and adjectives/adverbs
        token_probability = mask_probability
        
        # Increase probability for longer words
        if len(token) > 6:
            token_probability *= 1.5
            
        # Increase probability for likely adjectives/adverbs
        if any(re.search(pattern, token.lower()) for pattern in adj_adv_patterns):
            token_probability *= 2
            
        # Lower probability for important structural words
        if token.lower() in ['i', 'me', 'my', 'mine', 'is', 'are', 'was', 'were', 
                            'the', 'a', 'an', 'this', 'that', 'these', 'those',
                            'not', 'no', 'yes']:
            token_probability *= 0.3
        
        # Apply masking based on calculated probability
        if random.random() < token_probability:
            # Use varying mask styles
            mask_styles = ['[...]', '[•••]', '[---]', '[___]']
            tokens[i] = random.choice(mask_styles)
    
    return ''.join(tokens)

def chunk_list(lst, chunk_size):
    """Split a list into chunks of approximately equal size, preserving order within chunks"""
    return [lst[i:i + chunk_size] for i in range(0, len(lst), chunk_size)]
---

## event_handler.py

---python
import threading
import time
import re
from tkinter import messagebox
import gui_utils
from gui_utils import set_status, update_prompt_text, update_response_text, append_response_text

class EventHandler:
    def __init__(self, gui):
        self.gui = gui
        # Initialize buffers and state for streaming response handling
        self.complete_response = ""
        self.post_thinking_buffer = ""
        self.thinking_complete = False
        self.command_detected = False
        self.detected_command = None
        self.has_early_stopped = False
        # Add a lock for thread safety
        self.response_lock = threading.Lock()
        # Add a completion event for coordinating turn completion
        self.turn_completed = threading.Event()
    
    def execute_minimind_turn(self):
        """Execute a turn for the selected minimind"""
        # Check if it's a minimind's turn
        next_character = self.gui.turn_manager.get_next_character()
        
        if next_character == self.gui.player_name:
            messagebox.showinfo("Not Minimind's Turn", "It's your turn, not a minimind's.")
            return
            
        if next_character not in self.gui.miniminds:
            messagebox.showinfo("Error", f"Unknown character: {next_character}")
            return
            
        if self.gui.turn_in_progress:
            return
        
        # Reset turn completion event
        self.turn_completed.clear()
        
        # Set the active minimind to the one whose turn it is
        self.gui.active_minimind = next_character
            
        self.gui.turn_in_progress = True
        set_status(self.gui, f"Processing {self.gui.active_minimind}'s turn...")
        
        # Reset stop streaming flag
        self.gui.stop_streaming.clear()
        
        # Reset streaming state variables
        with self.response_lock:
            self.complete_response = ""
            self.post_thinking_buffer = ""
            self.thinking_complete = False
            self.command_detected = False
            self.detected_command = None
            self.has_early_stopped = False
        
        # Clear response text
        self.gui.response_text.delete("1.0", "end")
        
        # Start in a separate thread to avoid blocking the UI
        threading.Thread(target=self.run_minimind_turn, daemon=True).start()

    def run_minimind_turn(self):
        """Run the minimind turn in a separate thread"""
        try:
            # Get the active minimind
            minimind = self.gui.miniminds[self.gui.active_minimind]
            
            # Get location data from the world
            location = minimind.location
            location_data = self.gui.world.get_location_data(location)
            
            # Update LLM settings
            self.gui.llm.model = self.gui.model_var.get()
            self.gui.llm.temperature = self.gui.temp_var.get()
            self.gui.llm.context_tokens = self.gui.context_var.get()
            
            # Update memory and note count settings
            self.gui.memories_count = self.gui.memories_var.get()
            self.gui.notes_count = self.gui.notes_var.get()
            
            # Construct prompt for the LLM with updated settings, now returns (prompt, system_prompt)
            prompt_result = minimind.construct_prompt(location_data, self.gui.memories_count, self.gui.notes_count)
            
            # Handle both the prompt and system_prompt
            if isinstance(prompt_result, tuple) and len(prompt_result) == 2:
                prompt, system_prompt = prompt_result
            else:
                # Backward compatibility for older method that just returns prompt
                prompt = prompt_result
                system_prompt = None
            
            # Store prompt and system prompt for saving with turn details
            self.prompt = prompt
            self.system_prompt = system_prompt
            
            # Show prompt in debug window
            self.gui.root.after(0, lambda: update_prompt_text(self.gui, prompt))
            
            # Call LLM to get minimind's action with streaming
            self.gui.llm.query_streaming(
                prompt, 
                on_chunk=self.handle_response_chunk,
                on_complete=self.handle_response_complete,
                on_error=self.handle_response_error,
                system=system_prompt  # Pass the system prompt if available
            )
            
            # Wait for streaming to complete with a more definitive check
            while self.gui.turn_in_progress and not self.gui.stop_streaming.is_set():
                time.sleep(0.1)
            
            # Check if streaming is actually complete
            if not self.gui.llm.wait_for_completion(timeout=3.0):
                print("Forcibly cancelling incomplete streaming after timeout")
                self.gui.llm.cancel_streaming()
            
            # Wait for turn to be fully completed
            self.turn_completed.wait(timeout=5.0)
            
            # Final cleanup
            if self.gui.turn_in_progress:
                print("Turn was never properly completed - forcing cleanup")
                self.gui.turn_in_progress = False
                set_status(self.gui, "Turn processing timed out.")
                
        except Exception as e:
            # Fix: Capture the exception message in a variable first
            error_msg = str(e)
            # Then use that variable in the lambda
            self.gui.root.after(0, lambda msg=error_msg: set_status(self.gui, f"Error: {msg}"))
            self.gui.turn_in_progress = False
            
            # Make sure to cancel any ongoing streaming
            self.gui.llm.cancel_streaming()
            
            # Signal turn completion
            self.turn_completed.set()

    def handle_response_chunk(self, chunk):
        """Handle a chunk of text from the streaming response"""
        # Use lock to prevent race conditions
        with self.response_lock:
            # If we've already detected a command, no need to process further
            if self.command_detected:
                return
                
            # Append chunk to UI
            self.gui.root.after(0, lambda text=chunk: append_response_text(self.gui, text))
            
            # Add to complete response
            self.complete_response += chunk
            
            # Look for end of thinking section if we haven't found it yet
            if not self.thinking_complete:
                think_end_match = re.search(r'</think>', self.complete_response)
                if think_end_match:
                    self.thinking_complete = True
                    # Extract everything after </think>
                    end_pos = think_end_match.end()
                    self.post_thinking_buffer = self.complete_response[end_pos:].strip()
            else:
                # Append to post-thinking buffer
                self.post_thinking_buffer += chunk
            
            # Only start looking for commands after the thinking stage
            if self.thinking_complete:
                # Check if this looks like a valid command from a complete line
                command = self.extract_command_from_buffer(self.post_thinking_buffer)
                if command:
                    # Debug: Print the detected command to the console
                    print(f"Detected command: {command}")
                    
                    self.command_detected = True
                    self.detected_command = command
                    
                    # Signal early stopping of the generation
                    self.has_early_stopped = True
                    self.gui.stop_streaming.set()
                    
                    # Store thinking part in the minimind
                    self.store_thinking_chain()
                    
                    # Cancel the streaming request explicitly
                    self.gui.llm.cancel_streaming()
                    
                    # Process the command with prompt and response data
                    self.gui.root.after(500, lambda cmd=command: 
                        self.process_command_safely(
                            cmd,
                            getattr(self, 'prompt', None),
                            getattr(self, 'system_prompt', None),
                            self.complete_response
                        )
                    )

    def process_command_safely(self, command, prompt=None, system_prompt=None, llm_response=None):
        """Process command with additional safety checks"""
        try:
            # Verify no active streaming is happening anymore
            self.gui.llm.wait_for_completion(timeout=2.0)
            
            # Proceed with command processing
            print(f"Processing command safely: {command}")
            self.gui.command_processor.process_minimind_action(
                command,
                prompt,
                system_prompt,
                llm_response
            )
            
            # Signal turn completion after processing
            self.turn_completed.set()
        except Exception as e:
            print(f"Error processing command: {str(e)}")
            self.gui.turn_in_progress = False
            self.turn_completed.set()

    def handle_response_complete(self, full_response):
        """Handle completion of the response"""
        with self.response_lock:
            # Don't process if we've already detected and processed a command
            if self.has_early_stopped:
                return
                    
            # Update complete response
            self.complete_response = full_response
            
            # Store thinking chain if we have one
            self.store_thinking_chain()
            
            # Wait to make sure any cancellation hasn't happened
            time.sleep(0.2)
            
            # Check again if we've been early-stopped during the delay
            if self.has_early_stopped:
                return
            
            # Clean action - parse the response to extract just the command
            if not self.detected_command:
                cleaned_action = self.clean_llm_response(full_response)
                
                # Process the action through the command processor with prompt and response data
                self.gui.root.after(0, lambda act=cleaned_action: 
                    self.safe_process_full_response(
                        act, 
                        getattr(self, 'prompt', None),
                        getattr(self, 'system_prompt', None),
                        full_response
                    )
                )
            
            # Set the stop event after a delay to allow processing to complete
            self.gui.root.after(200, lambda: self.gui.stop_streaming.set())

    def safe_process_full_response(self, action, prompt=None, system_prompt=None, llm_response=None):
        """Process a full response safely"""
        try:
            # Wait for any pending operations to complete
            time.sleep(0.3)
            
            # Process the action if we haven't already
            if not self.has_early_stopped and self.gui.turn_in_progress:
                self.gui.command_processor.process_minimind_action(
                    action, 
                    prompt,
                    system_prompt,
                    llm_response
                )
            
            # Signal turn completion
            self.turn_completed.set()
        except Exception as e:
            print(f"Error processing full response: {str(e)}")
            self.gui.turn_in_progress = False
            self.turn_completed.set()

    def handle_response_error(self, error):
        """Handle an error from the LLM"""
        self.gui.root.after(0, lambda: update_response_text(self.gui, f"Error: {str(error)}\n"))
        self.gui.turn_in_progress = False
        self.gui.stop_streaming.set()
        
        # Signal turn completion
        self.turn_completed.set()
    
    def store_thinking_chain(self):
        """Extract and store the thinking chain from the complete response"""
        thought_chain = None
        think_pattern = re.compile(r'<think>(.*?)</think>', re.DOTALL)
        think_match = think_pattern.search(self.complete_response)
        
        if think_match:
            thought_chain = think_match.group(1).strip()
            minimind = self.gui.miniminds[self.gui.active_minimind]
            minimind.store_thought_chain(thought_chain)
    
    def extract_command_from_buffer(self, buffer):
        """Check if the buffer contains a valid command and extract it"""
        if not buffer:
            return None
        
        # Only process buffer if it contains at least one complete line
        # or if we've reached the end of the response
        buffer_ends_with_newline = buffer.endswith('\n')
        contains_newline = '\n' in buffer
        
        # If no complete line and buffer doesn't end with newline, wait for more content
        if not contains_newline and not buffer_ends_with_newline:
            return None
            
        # Split into lines
        lines = buffer.split('\n')
        
        # Process all complete lines (all lines except last if buffer doesn't end with newline)
        processable_lines = lines[:-1] if not buffer_ends_with_newline else lines
        
        for line in processable_lines:
            line = line.strip()
            if not line:
                continue
                
            # Skip lines that look like formatting or explanations
            if line.startswith(('*', '#', '-', '>', '"')) or "command" in line.lower():
                continue
            
            # Check if this looks like a known command type
            cmd_lower = line.lower()
            if any(cmd_lower.startswith(prefix) for prefix in ['go to', 'say', 'note', 'recall', 'shout']):
                # Extract reason if present
                if '|' in line:
                    parts = line.split('|', 1)
                    command = parts[0].strip()
                    reason = parts[1].strip() if len(parts) > 1 else None
                    
                    # Store reason
                    if reason:
                        minimind = self.gui.miniminds[self.gui.active_minimind]
                        minimind.last_command_reason = reason
                    
                    return command
                else:
                    return line
            
            # Check if line matches a proper command but ignoring case and excess whitespace
            command_prefixes = [
                (r'^\s*GO\s+TO\s+', 'go to'),
                (r'^\s*SAY\s+', 'say'),
                (r'^\s*SHOUT\s+', 'shout'),
                (r'^\s*NOTE\s+', 'note'),
                (r'^\s*RECALL\s+', 'recall')
            ]
            
            for pattern, prefix in command_prefixes:
                match = re.match(pattern, line, re.IGNORECASE)
                if match:
                    # This is a command, extract content and fix formatting
                    content = line[match.end():].strip()
                    
                    # Handle special case for NOTE command which should have a title and content
                    if prefix == 'note' and ':' in content:
                        title, body = content.split(':', 1)
                        return f"{prefix} {title.strip()}: {body.strip()}"
                    
                    return f"{prefix} {content}"
        
        # No valid command found in this buffer yet
        return None

    def clean_llm_response(self, response):
        """Clean the LLM response to extract just the command"""
        # If we've already detected a command during streaming, return it
        if self.detected_command:
            return self.detected_command
            
        # First, check if there's a <think>...</think> block - this should already be stored
        think_pattern = re.compile(r'<think>.*?</think>', re.DOTALL)
        response_cleaned = think_pattern.sub('', response).strip()
        
        # Process the response line by line
        lines = response_cleaned.split('\n')
        for line in lines:
            line = line.strip()
            if not line:
                continue
                
            # Skip lines that look like formatting or explanations
            if line.startswith(('*', '#', '-', '>', '"')) or "command" in line.lower():
                continue
            
            # Check if line has a pipe symbol for reasoning
            if '|' in line:
                parts = line.split('|', 1)
                command = parts[0].strip()
                reason = parts[1].strip() if len(parts) > 1 else None
                
                # Check if command is valid
                cmd_lower = command.lower()
                if any(cmd_lower.startswith(prefix) for prefix in ['go to', 'say', 'note', 'recall', 'shout']):
                    # Store reason if provided
                    if reason:
                        minimind = self.gui.miniminds[self.gui.active_minimind]
                        minimind.last_command_reason = reason
                    return command
            
            # Check if line is a valid command without reasoning
            cmd_lower = line.lower()
            if any(cmd_lower.startswith(prefix) for prefix in ['go to', 'say', 'note', 'recall', 'shout']):
                return line
        
        # Fallback to first non-empty line
        for line in lines:
            line = line.strip()
            if line and not line.startswith(('*', '#', '-', '>')):
                return line
        
        # If all else fails, return the cleaned response
        return response_cleaned
---

## gui_utils.py

---python
from datetime import datetime
import customtkinter as ctk
import re

def format_structured_event(event_type, actor, action, location, reason=None, target=None, additional_info=None, observers=None):
    """Format an event in a consistent structured format for all views"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    event_id = f"{timestamp}-{event_type[:3]}"
    
    # Format the structured event
    who = actor
    what = action
    where = location
    when = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    why = reason if reason else f"Standard {event_type} event"
    how = additional_info if additional_info else event_type
    
    # Add observers information if provided
    observers_text = ""
    if observers:
        observers_text = f"{','.join(observers)}"
    
    # Create structured data part with all components including observers
    structured_data = f"📅{when} in 📍{where}: 👥{who},💡{what} (❓{why},🔧{how},👁{observers_text})"
    
    # Create human-readable part
    readable_text = f"{actor} {action}"
    if target and target != actor:
        readable_text += f" with {target}"
    
    # Extract message for speech and shout events
    message = None
    if event_type in ["speech", "shout"]:
        # Try to extract message from additional_info
        if additional_info and "message:" in additional_info.lower():
            message_part = additional_info.split("message:", 1)[1].strip()
            message = message_part
        elif ":" in action:
            # Try to extract from action
            message = action.split(":", 1)[1].strip().strip('"')
    
    result = {
        "timestamp": timestamp,
        "structured": structured_data,
        "readable": readable_text,
        "actor": actor,
        "action": action,
        "location": location,
        "observers": observers,
        "reason": why,  # Include reason in the return value for easier access
        "type": event_type  # Include event type for easier filtering
    }
    
    # For movement events, extract origin and destination from additional_info if present
    if event_type == "movement" and additional_info:
        # Try to parse origin and destination from additional_info
        if "From " in additional_info and " to " in additional_info:
            parts = additional_info.split("From ")[1].split(" to ")
            if len(parts) == 2:
                origin = parts[0].strip()
                # Extract destination (might have additional text after)
                destination_part = parts[1].strip()
                destination = destination_part.split(" via ")[0].strip()
                
                # Add to result
                result["origin"] = origin
                result["destination"] = destination
                
                # Extract movement method if present
                if " via " in destination_part:
                    result["via"] = destination_part.split(" via ")[1].strip()
    
    # Add message explicitly for speech/shout events
    if message:
        result["message"] = message
    
    return result

def add_world_event(gui, text, structured_data=None):
    """Add text to the World Events log (GM view - shows everything happening in the world)
    
    The GM view presents events from an omnipresent third party observer perspective,
    with full context and metadata but without redundancy.
    """
    
    # Skip emoji-formatted entries when we have structured data
    if structured_data:
        # # Extract key information
        timestamp = structured_data.get("timestamp", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        event_type = structured_data.get("type", "event")
        actor = structured_data.get("actor", "unknown")
        location = structured_data.get("location", "unknown")
        reason = structured_data.get("reason", "unknown")
        target = structured_data.get("target", None)
        message = structured_data.get("message", "unknown")
        action = structured_data.get("action", "unknown")
        # For movement, show origin and destination
        origin = structured_data.get("origin", "somewhere")
        destination = structured_data.get("destination", "somewhere")
        via = structured_data.get("via", "walking")
        observers = structured_data.get("observers", "none")
        
        gui.prose_text.insert("end", f"👥{actor} in 📍{location}: 💡{action} | ❓{reason} 👁{observers} 📅{timestamp}\n")
        gui.prose_text.see("end")
    else:
        # Handle non-structured data (legacy format)
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        gui.prose_text.insert("end", f"📅{timestamp} 📝{text}\n")
        gui.prose_text.see("end")

def add_player_view(gui, text, structured_data=None):
    """Add text to the Player View (MUD/MOO style interface - only what the player sees)
    
    Now formats events more consistently with timestamps and avoids redundant information.
    """
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Format structured events in a clean, consistent way
    if structured_data:
        # Only show specific types of events based on the structured data
        event_type = structured_data.get("type", "")
        actor = structured_data.get("actor", "")
        player_name = gui.player_name
        
        # Skip echoing player commands and redundant messages
        if actor == player_name and event_type in ["command", "observation"]:
            return
        
        # Skip echoing commands- player view should be only what the player "sees" from the world
        if event_type == "command":
            return
            
        # Format based on event type
        if event_type == "speech":
            # For speech, just show who said what
            message = structured_data.get('message', '')
            
            # Clean up message - remove extra quotes if present
            if message.startswith('"') and message.endswith('"'):
                message = message[1:-1]
                
            formatted_text = f"{actor} says, \"{message}\""
            
        elif event_type == "emote":
            # For emotes, present as "Actor does something"
            action = structured_data.get('action', '')
            formatted_text = f"{actor} {action}"
            
        elif event_type == "shout":
            # For shouts, add source location for context - use actual location
            location = structured_data.get("origin_location", structured_data.get("location", "somewhere"))
            
            # Get the message from all possible sources
            message = structured_data.get("message", "")
            
            # Check if the message is in the readable text when empty
            if not message and "shouted" in structured_data.get("readable", ""):
                try:
                    # Try to extract it from the readable text
                    readable = structured_data.get("readable", "")
                    if ': "' in readable:
                        message = readable.split(': "', 1)[1].rstrip('"')
                except:
                    # Fallback to data field
                    if "data" in structured_data:
                        message = structured_data["data"].get("message", "")
            
            # Debug: Add notice if message is still empty
            if not message:
                # Try direct access to original data
                if "data" in structured_data:
                    message = structured_data["data"].get("message", "[Empty message]")
                else:
                    message = "[Empty message]"
            
            # Clean up message - remove extra quotes if present
            if message.startswith('"') and message.endswith('"'):
                message = message[1:-1]
                
            formatted_text = f"{actor} shouts from {location}, \"{message}\""
            
        elif event_type == "movement":
            # For movement, format based on perspective and movement type
            origin = structured_data.get("origin", "somewhere")
            destination = structured_data.get("destination", "somewhere")
            via = structured_data.get("via", "moved")
            
            # Determine if the player is at the origin or destination
            player_location = gui.world.get_character_location(gui.player_name)
            
            if player_location == origin:
                # Player is at the origin - they see someone leaving
                formatted_text = f"{actor} {via} from {origin} to {destination}."
            else:
                # Player is at the destination - they see someone arriving
                formatted_text = f"{actor} {via} from {origin} to {destination}."

        else:
            # For other types, use the provided text
            formatted_text = text
            
        gui.log_text.insert("end", f"{formatted_text}\n\n")
    else:
        # Legacy format - keep for backward compatibility
        gui.log_text.insert("end", f"{text}\n\n")
    
    gui.log_text.see("end")

def add_command_to_player_view(gui, character, command):
    """Add a command issued by a character to the Player View
    
    Modified to only show the player's own commands and format them better.
    """
    # Skip command echo in player view - we'll just see the results
    return

    # Previous implementation:
    # gui.log_text.insert("end", f"> {character}: {command}\n")
    # gui.log_text.see("end")

def set_status(gui, message):
    """Set the status message"""
    gui.status_var.set(message)
    gui.root.update_idletasks()

def update_prompt_text(gui, text):
    """Update the prompt text debug area"""
    gui.prompt_text.delete("1.0", "end")
    gui.prompt_text.insert("end", text)
    gui.prompt_text.see("end")

def update_response_text(gui, text):
    """Update the response text debug area"""
    gui.response_text.delete("1.0", "end")
    gui.response_text.insert("end", text)
    gui.response_text.see("end")

def append_response_text(gui, text):
    """Append text to the response text debug area"""
    gui.response_text.insert("end", text)
    gui.response_text.see("end")

def is_duplicate_event(event, recent_events, time_window=5):
    """Check if an event is a duplicate of a recent event
    
    Args:
        event: The event to check
        recent_events: List of recent events
        time_window: Time window in seconds to check for duplicates
    
    Returns:
        Boolean indicating if the event is a duplicate
    """
    for recent in recent_events:
        if (event['actor'] == recent['actor'] and 
            event['action'] == recent['action'] and
            event['location'] == recent['location']):
            # Calculate time difference
            event_time = datetime.strptime(event['timestamp'], "%Y-%m-%d %H:%M:%SS")
            recent_time = datetime.strptime(recent['timestamp'], "%Y-%m-%d %H:%M:%S")
            
            # If the times are on different days, this gets tricky with just H:M:S format
            # For simplicity, we'll just check if they're the exact same time
            if event_time == recent_time:
                return True
            
    return False
---

## llm_interface.py

---python
import requests
import json
import threading
import numpy as np
import time

class OllamaInterface:
    def __init__(self, model="deepseek-r1:14b", temperature=0.7, context_tokens=32768, repeat_penalty=1.1, embedding_model="all-minilm", stop_tokens=None, system=""):
        """Initialize the Ollama API interface"""
        self.base_url = "http://localhost:11434/api"
        self.model = model
        self.embedding_model = embedding_model
        self.temperature = temperature
        self.context_tokens = context_tokens
        self.repeat_penalty = repeat_penalty
        # Default stop tokens for cutting off explanations
        # We avoid using newline as a stop token to preserve the thinking process
        self.stop_tokens = stop_tokens or ["Explanation:", "Let me explain:", "To explain my reasoning:"]
        
        # Default to empty system message
        self.system = system
        
        # Add tracking for active streaming requests
        self.active_stream_thread = None
        self.stream_canceled = threading.Event()
        self.stream_completed = threading.Event()
        
        # Add thread lock for thread management
        self.thread_lock = threading.Lock()
    
    def query(self, prompt, system=None):
        """Query the Ollama API and get a response
        
        Args:
            prompt: The prompt to send to the API
            system: Optional system message to use (overrides the default)
        """
        # Use provided system message or fall back to the default
        system_message = system if system is not None else self.system
        
        payload = {
            "model": self.model,
            "prompt": prompt,
            "system": system_message,
            "stream": False,
            "options": {
                "temperature": self.temperature,
                "num_ctx": self.context_tokens,
                "repeat_penalty": self.repeat_penalty,
                "stop": self.stop_tokens
            }
        }
        
        try:
            response = requests.post(
                f"{self.base_url}/generate",
                json=payload
            )
            
            if response.status_code != 200:
                return f"Error: API returned status code {response.status_code}"
                
            result = response.json()
            return result.get("response", "")
        except Exception as e:
            return f"Error: {str(e)}"
    
    def query_streaming(self, prompt, on_chunk=None, on_complete=None, on_error=None, system=None):
        """Query the Ollama API with streaming responses
        
        Args:
            prompt: The prompt to send to the API
            on_chunk: Callback for each chunk of the response
            on_complete: Callback when the response is complete
            on_error: Callback for errors
            system: Optional system message to use (overrides the default)
        """
        # Reset cancellation and completion flags
        self.stream_canceled.clear()
        self.stream_completed.clear()
        
        # Use provided system message or fall back to the default
        system_message = system if system is not None else self.system
        
        payload = {
            "model": self.model,
            "prompt": prompt,
            "system": system_message,
            "stream": True,
            "options": {
                "temperature": self.temperature,
                "num_ctx": self.context_tokens,
                "repeat_penalty": self.repeat_penalty,
                "stop": self.stop_tokens
            }
        }
        
        # Create and start a new streaming thread with thread-safe handling
        with self.thread_lock:
            # Create a new thread
            new_thread = threading.Thread(
                target=self._stream_response,
                args=(payload, on_chunk, on_complete, on_error),
                daemon=True
            )
            
            # Store the thread reference
            self.active_stream_thread = new_thread
            
            # Start the thread
            new_thread.start()
    
    def _stream_response(self, payload, on_chunk, on_complete, on_error):
        """Process a streaming response"""
        response = None
        try:
            response = requests.post(
                f"{self.base_url}/generate",
                json=payload,
                stream=True
            )
            
            if response.status_code != 200:
                if on_error:
                    on_error(f"API returned status code {response.status_code}")
                self.stream_completed.set()
                return
                
            # Buffer for full response
            full_response = ""
            
            for line in response.iter_lines():
                # Check if the stream has been canceled
                if self.stream_canceled.is_set():
                    if response and hasattr(response, 'close'):
                        response.close()
                    break
                    
                if line:
                    try:
                        data = json.loads(line)
                        if 'response' in data:
                            chunk = data['response']
                            full_response += chunk
                            
                            # Call the callback for each chunk
                            if on_chunk:
                                on_chunk(chunk)
                        
                        # Check if done
                        if data.get('done', False):
                            if on_complete and not self.stream_canceled.is_set():
                                on_complete(full_response)
                            self.stream_completed.set()
                            return
                    except json.JSONDecodeError:
                        continue
                        
            # If we exit the loop without hitting 'done', make sure we mark as completed
            self.stream_completed.set()
            
        except Exception as e:
            if on_error:
                on_error(str(e))
            # Make sure to set the completed flag even on error
            self.stream_completed.set()
        finally:
            # Clean up the response if it exists
            if response and hasattr(response, 'close'):
                response.close()
            self.stream_completed.set()

    def cancel_streaming(self):
        """Cancel any ongoing streaming request"""
        # Get current thread for comparison
        current_thread = threading.current_thread()
        
        # Use thread-safe access to active_stream_thread
        with self.thread_lock:
            stream_thread = self.active_stream_thread
            
            if stream_thread and stream_thread.is_alive():
                # Set the canceled flag
                self.stream_canceled.set()
                
                # Wait for the streaming to actually stop (with timeout)
                completed = self.stream_completed.wait(timeout=2.0)
                
                # Only join if we're not trying to join ourselves
                if stream_thread != current_thread:
                    try:
                        # Force joining the thread to make sure it's done
                        stream_thread.join(timeout=1.0)
                    except RuntimeError as e:
                        # Log the error but continue
                        print(f"Warning: Could not join thread: {e}")
                
                # Reset the active thread reference
                self.active_stream_thread = None
                
                return completed
                
        return True
        
    def wait_for_completion(self, timeout=5.0):
        """Wait for the current streaming request to complete"""
        # Get current thread for comparison
        current_thread = threading.current_thread()
        
        # Use thread-safe access to active_stream_thread
        with self.thread_lock:
            stream_thread = self.active_stream_thread
            
            if stream_thread and stream_thread.is_alive():
                # Wait for the completion event with timeout
                completed = self.stream_completed.wait(timeout=timeout)
                
                # If still not complete, try to cancel
                if not completed:
                    # Set the canceled flag first
                    self.stream_canceled.set()
                    
                    # Only join if we're not trying to join ourselves
                    if stream_thread != current_thread:
                        try:
                            # Try to join with timeout
                            stream_thread.join(timeout=1.0)
                        except RuntimeError as e:
                            # Log the error but continue
                            print(f"Warning: Could not join thread: {e}")
                    
                    # Reset the active thread reference
                    self.active_stream_thread = None
                    
                return self.stream_completed.is_set()
                
        return True

    def get_embeddings(self, texts, model=None):
        """Generate embeddings for a single text or list of texts
        
        Args:
            texts: A string or list of strings to generate embeddings for
            model: Optional model to use for embeddings (defaults to self.embedding_model)
            
        Returns:
            A list of embedding vectors (list of floats)
        """
        if model is None:
            model = self.embedding_model
            
        # Handle single text input
        if isinstance(texts, str):
            texts = [texts]
            
        payload = {
            "model": model,
            "input": texts,
            "truncate": True  # Automatically truncate to fit context
        }
        
        try:
            response = requests.post(
                f"{self.base_url}/embed",
                json=payload
            )
            
            if response.status_code != 200:
                raise Exception(f"API returned status code {response.status_code}")
                
            result = response.json()
            embeddings = result.get("embeddings", [])
            
            if not embeddings:
                raise Exception("No embeddings returned from API")
                
            return embeddings
            
        except Exception as e:
            print(f"Error generating embeddings: {str(e)}")
            # Return zero vectors as fallback
            dimension = 384  # Default dimension for all-minilm model
            return [np.zeros(dimension).tolist() for _ in range(len(texts))]
            
    def get_combined_embedding(self, title, content, weights=(0.3, 0.7)):
        """Get embeddings for title and content, and combine them with weighted average
        
        Args:
            title: The title text
            content: The content text
            weights: Tuple of (title_weight, content_weight)
            
        Returns:
            Tuple of (title_embedding, content_embedding, combined_embedding)
        """
        # Get embeddings for title and content
        embeddings = self.get_embeddings([title, content])
        
        if len(embeddings) != 2:
            # Handle error case - return zero vectors
            dimension = 384  # Default dimension
            zero_vec = np.zeros(dimension).tolist()
            return zero_vec, zero_vec, zero_vec
            
        title_embedding = embeddings[0]
        content_embedding = embeddings[1]
        
        # Calculate weighted average
        title_weight, content_weight = weights
        title_array = np.array(title_embedding)
        content_array = np.array(content_embedding)
        
        combined = title_weight * title_array + content_weight * content_array
        
        # Normalize the combined vector
        norm = np.linalg.norm(combined)
        if norm > 0:
            combined = combined / norm
            
        return title_embedding, content_embedding, combined.tolist()
---

## main_gui.py

---python
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
---

## markdown_utils.py

---python
import os
import re
import json
from datetime import datetime

class MarkdownVault:
    """Utility class for managing Markdown content in a vault-like structure"""
    
    @staticmethod
    def ensure_vault_directories():
        """Create the necessary directory structure for the Markdown vault"""
        directories = [
            "vault",
            "vault/templates",
            "vault/settings",
            "vault/world",
            "vault/world/locations",
            "miniminds"
        ]
        
        for directory in directories:
            os.makedirs(directory, exist_ok=True)
            
        # Create default templates and settings if they don't exist
        MarkdownVault.create_default_files()
    
    @staticmethod
    def create_default_files():
        """Create default template and settings files if they don't exist"""
        default_files = {
            #Templates
            "vault/templates/prompt_template.md": DEFAULT_PROMPT_TEMPLATE,
            "vault/templates/default_profile.md": DEFAULT_PROFILE_TEMPLATE,
            "vault/templates/memory_format.md": DEFAULT_MEMORY_FORMAT,
            "vault/templates/note_format.md": DEFAULT_NOTE_FORMAT,
            "vault/templates/agent_system_prompt.md": DEFAULT_AGENT_SYSTEM_PROMPT,
            
            # Settings
            "vault/settings/app_settings.md": DEFAULT_APP_SETTINGS,
            "vault/settings/llm_settings.md": DEFAULT_LLM_SETTINGS,
            "vault/settings/commands.md": DEFAULT_COMMANDS,
            "vault/settings/turn_rules.md": DEFAULT_TURN_RULES,
            "vault/settings/command_aliases.md": DEFAULT_COMMAND_ALIASES,  # Add this line
        }
        
        for filepath, content in default_files.items():
            if not os.path.exists(filepath):
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(content)
    
    @staticmethod
    def load_template(template_name):
        """Load a template from the vault"""
        template_path = f"vault/templates/{template_name}.md"
        
        if not os.path.exists(template_path):
            print(f"Warning: Template {template_name} not found, using default")
            return MarkdownVault.get_default_template(template_name)
        
        with open(template_path, "r", encoding="utf-8") as f:
            return f.read()
    
    @staticmethod
    def load_settings(settings_name):
        """Load settings from the vault"""
        settings_path = f"vault/settings/{settings_name}.md"
        
        if not os.path.exists(settings_path):
            print(f"Warning: Settings file {settings_name} not found, using default")
            return MarkdownVault.get_default_settings(settings_name)
        
        with open(settings_path, "r", encoding="utf-8") as f:
            return f.read()
    
    @staticmethod
    def get_default_template(template_name):
        """Get default template content"""
        templates = {
            "prompt_template": DEFAULT_PROMPT_TEMPLATE,
            "default_profile": DEFAULT_PROFILE_TEMPLATE,
            "memory_format": DEFAULT_MEMORY_FORMAT,
            "note_format": DEFAULT_NOTE_FORMAT
        }
        return templates.get(template_name, "# Empty Template")
    
    @staticmethod
    def get_default_settings(settings_name):
        """Get default settings content"""
        settings = {
            "app_settings": DEFAULT_APP_SETTINGS,
            "llm_settings": DEFAULT_LLM_SETTINGS,
            "commands": DEFAULT_COMMANDS,
            "turn_rules": DEFAULT_TURN_RULES,
            "command_aliases": DEFAULT_COMMAND_ALIASES  # Add this line
        }
        return settings.get(settings_name, "# Empty Settings")
    
    @staticmethod
    def parse_settings(settings_content):
        """Parse settings from Markdown content"""
        settings = {}
        
        # Extract YAML frontmatter if present
        frontmatter_match = re.search(r"^---\n(.*?)\n---", settings_content, re.DOTALL)
        if frontmatter_match:
            try:
                yaml_content = frontmatter_match.group(1)
                # Simple YAML-like parsing (without requiring PyYAML)
                for line in yaml_content.split("\n"):
                    if ":" in line:
                        key, value = line.split(":", 1)
                        key = key.strip()
                        value = value.strip()
                        
                        # Convert to appropriate type
                        if value.lower() == "true":
                            value = True
                        elif value.lower() == "false":
                            value = False
                        elif value.isdigit():
                            value = int(value)
                        elif value.replace(".", "", 1).isdigit() and value.count(".") == 1:
                            value = float(value)
                            
                        settings[key] = value
            except Exception as e:
                print(f"Error parsing YAML frontmatter: {e}")
        
        # Parse key-value pairs from list items (- Key: Value)
        for line in settings_content.split("\n"):
            if line.strip().startswith("- ") and ":" in line:
                try:
                    key_value = line.strip()[2:]  # Remove the "- " prefix
                    key, value = key_value.split(":", 1)
                    key = key.strip()
                    value = value.strip()
                    
                    # Handle comments at the end of the line
                    if "#" in value:
                        value = value.split("#", 1)[0].strip()
                    
                    # Convert to appropriate type
                    if value.lower() == "true":
                        value = True
                    elif value.lower() == "false":
                        value = False
                    elif value.isdigit():
                        value = int(value)
                    elif value.replace(".", "", 1).isdigit() and value.count(".") == 1:
                        value = float(value)
                        
                    settings[key] = value
                except Exception as e:
                    print(f"Error parsing list item: {e}")
        
        return settings
    
    @staticmethod
    def parse_aliases(aliases_content):
        """Parse command aliases from Markdown content"""
        aliases = {}
        
        # Process line by line
        for line in aliases_content.split('\n'):
            line = line.strip()
            
            # Skip empty lines, headers, and comments
            if not line or line.startswith('#') or line.startswith('>'):
                continue
                
            # Check for bullet points
            if line.startswith('- '):
                line = line[2:].strip()
                
                # Look for different separator formats
                for separator in ['=>', '->', '=', ':', ' as ']:
                    if separator in line:
                        alias, command = line.split(separator, 1)
                        aliases[alias.strip().upper()] = command.strip().upper()
                        break
        
        return aliases
    
    @staticmethod
    def fill_template(template, data):
        """Fill a template with data"""
        result = template
        
        # Handle conditional blocks first
        def replace_conditionals(match):
            condition_var = match.group(1).strip()
            content = match.group(2)
            
            # Check if the condition variable exists and is truthy
            if condition_var in data and data[condition_var]:
                return content
            return ""
        
        # Replace {{#if var}}...{{/if}} blocks
        result = re.sub(r'\{\{#if\s+([^}]+)\}\}(.*?)\{\{/if\}\}', replace_conditionals, result, flags=re.DOTALL)
        
        # Replace simple variables {{var}}
        for key, value in data.items():
            if isinstance(value, (str, int, float, bool)):
                placeholder = f"{{{{{key}}}}}"
                result = result.replace(placeholder, str(value))
        
        return result

# Define default templates and settings
DEFAULT_AGENT_SYSTEM_PROMPT = """Think and act as your assigned character would think and act, always working in their best interest given the available information.

Formatted as a command, what do you do next and why? Remember the current situation. As you read these memories, identify: (1) which of your goals has received the least attention, (2) what information you're missing that would help you most, and (3) what new approach could yield better results than your recent actions. Before deciding your next action, reflect: Have your recent actions made meaningful progress toward your goals? If you've been repeating similar approaches without new results, prioritize a different type of action now. When making notes, identify if you're stuck in a pattern (e.g., only asking questions or only observing). Your notes are most valuable when they suggest specific new approaches to try rather than just documenting what happened. The most effective agents regularly cycle between different action types (SAY, GO TO, NOTE, etc.) rather than repeating the same command type in different locations. If you've used one command type multiple times recently, consider using a different one now.

Basic commands:

  GO TO <location name> | <reason for going>
  SAY <one line message> | <reason for saying>
  SHOUT <message> | <reason for shouting>
  EMOTE <physical action> | <reason for acting>
  NOTE <title>: <observations implications plans follow-up questions related topics etc> | <reason for noting>
  RECALL <example note content> | <reason for recalling>
  LOOK | <reason for looking/passing>

Your reason after `|` should explain the context and desired outcome of WHY you're taking this action along with the relevant clues which led to this action. The SAY command sends a message to everyone in the same location, while the SHOUT command sends a message to everyone in all locations everywhere. The EMOTE command lets you express physical actions or emotions (e.g., "EMOTE smiles warmly" will appear to others as `{{name}} smiles warmly`). EMOTE makes no changes on the world so it is only for self-expression. The NOTE feature is for private mental guidance for your future self. Recent and relevant notes to the current situation are automatically shown on your future turns using semantic matching to your WHY. Notes automatically document time and date, location, and who is present, so you don't need to include those details. If you suspect there might be other notes available, the RECALL command semantically searches your notes for matches to a given hypothetical example which you should craft. Note titles are used as unique filenames so avoid overwiting existing notes without good reason such as removing incorrect information. Notes are extremely powerful especially if there is important information in your oldest memories which needs to be preserved before they fade or if you notice questions you haven't seen tested yet in your memories. Read your notes and memories critically and don't trust them! Your past self could have been wrong or misled and passed on incorrect information, so everything needs to be tested. Consider counterfactuals. Don't re-explain existing memories and notes so much, instead think about potential and desired futures they lead towards- those types of thoughts are much more useful to your future self as notes, because you're making about their world instead of yours. If you don't see up-to-date notes about your goals then making one with theories on what try next and why should be your first priority and then acting to test and correct those theories.

IMPORTANT: Your ENTIRE RESPONSE must be only a SINGLE command on ONE LINE by itself with no other text or labels or formatting or prose etc before or after the one-line command. Your reason cannot contain linebreaks or commas or pipes. You cannot repeat your previous command."""


DEFAULT_PROMPT_TEMPLATE = """You are {{name}}. Thinking as {{name}}, staying true and faithful to how {{name}} would think, use your memories, notes, and situation to decide your next action. {{profile}}

---

{{#if memories}}
### Recent Memories
{{memories}}

---
{{/if}}

{{#if notes}}
### Recent and/or Relevant Mental Notes
{{notes}}

---
{{/if}}

{{#if last_thought}}
## Previous Thinking (fragments to consider or discard)
{{last_thought}}

---
{{/if}}

{{#if last_command}}
## Previous Command
Your last command was: {{last_command}}

The result was: {{last_result}}

---
{{/if}}

## Your Current Situation
You are {{name}} in 📍{{location}} at 📅{{current_time}}. {{profile}}
If you LOOK around {{location}} you see: 💡{{location_description}} {{location_exits}}
👥{{location_characters}}

🔧 Known commands:

GO TO [location] | [reason for going]
SAY [message] | [reason for saying]
SHOUT [message] | [reason for shouting]
NOTE [title]: [single line of observations implications plans follow-up questions related topics etc] | [reason for noting]
RECALL [example content] | [reason for recalling]
LOOK | [reason for looking/passing]

IMPORTANT: Your ENTIRE RESPONSE must be only a SINGLE command on ONE LINE. Your [reason] cannot contain linebreaks. You cannot repeat your previous command."""

DEFAULT_PROFILE_TEMPLATE = """Friendly, curious, helpful."""

DEFAULT_MEMORY_FORMAT = """# {{memory_type}} Memory

🧠{{memory_id}}:{👥{{who}},💡{{what}},📍{{where}},📅{{when}},❓{{why}},🔧{{how}}}
"""

DEFAULT_NOTE_FORMAT = """# {{title}}
📅 {{current_time}}
👥 Present: {{characters}}
📍 {{location}}
🔧 Note on {{title_lower}}
❓ {{reason}}
💡 {{content}}
"""

DEFAULT_APP_SETTINGS = """# Minimind Application Settings

## Memory Settings
- Default Memory Count: 64
- Default Notes Count: 16

## Turn Manager Settings
- Base TU Cost: 1
- Say TU Cost Multiplier: 3  # One additional TU per 3 words
- Shout TU Cost Multiplier: 2  # One additional TU per 2 words
- Note TU Cost Multiplier: 7  # One additional TU per 7 words
"""

DEFAULT_LLM_SETTINGS = """# LLM Settings

## Default Model
- Model: deepseek-r1:14b
- Temperature: 0.7
- Context Tokens: 32768
- Repeat Penalty: 1.2
- Embedding Model: all-minilm

## Stop Tokens
- Stop Token 1: "Explanation:"
- Stop Token 2: "Let me explain:"
- Stop Token 3: "To explain my reasoning:"
"""

DEFAULT_COMMANDS = """# Available Commands

## GO TO [location]
Move to another connected location.
- TU Cost: Basic cost (1)
- Example: `GO TO Kitchen | I want to get something to eat`

## SAY [message]
Say something to all characters in your current location.
- TU Cost: Basic cost + 1 TU per 3 words
- Example: `SAY Hello everyone, how are you today? | I want to be friendly`

## SHOUT [message]
Shout a message that all characters can hear regardless of location.
- TU Cost: Basic cost + 1 TU per 2 words
- Example: `SHOUT Help, there's an emergency! | I need immediate assistance`

## NOTE [title]: [content]
Create a personal note for future reference.
- TU Cost: Basic cost + 1 TU per 7 words
- Example: `NOTE Party Plans: Need to organize location, food, and invitations | Planning for future event`

## RECALL [query]
Search your notes for information related to the query.
- TU Cost: 2
- Example: `RECALL party planning | I need to remember what I noted about parties`

## LOOK
Observe your current surroundings.
- TU Cost: Basic cost (1)
- Example: `LOOK | I want to see what's around me`
"""

DEFAULT_TURN_RULES = """# Turn Manager Rules

## Turn Order Rules
- Players Take Turns: true
- Lowest TU Goes First: true
- Break Ties By Last Turn: true

## Cost Rules
- Base Cost: 1
- Scale With Content: true
"""

# Define default templates and settings
DEFAULT_COMMAND_ALIASES = """# Command Aliases

This file defines aliases for commands in the Minimind system. An alias maps to a canonical command.
The system will recognize any of these as equivalent to their canonical form.

## Formatting Options
- `ALIAS => COMMAND` 
- `ALIAS -> COMMAND`
- `ALIAS = COMMAND`
- `ALIAS : COMMAND`

## Defined Aliases

- NOTICE => NOTE
- TRAVEL TO => GO TO
- MOVE TO => GO TO
- WALK TO => GO TO
- TALK => SAY
- SPEAK => SAY
- TELL => SAY
- YELL => SHOUT
- WHISPER => SAY
- EXAMINE => LOOK AT
- OBSERVE => LOOK
- CHECK => LOOK
- VIEW => LOOK
- THINK => NOTE
- REMEMBER => RECALL
- SEARCH => RECALL
- QUERY => RECALL
- ASK => RECALL
"""---

## memory.py

---python
import customtkinter as ctk
from tkinter import simpledialog, messagebox
import os
from datetime import datetime
import re
import threading

class MemoryViewer:
    def __init__(self, parent, minimind):
        """Initialize a memory viewer for a minimind"""
        self.parent = parent
        self.minimind = minimind
        self.selected_memory = None
        
        # Create memory directory if it doesn't exist
        self.memories_path = os.path.join(minimind.path, "memories")
        os.makedirs(self.memories_path, exist_ok=True)
        
        # Create the window
        self.window = ctk.CTkToplevel(parent)
        self.window.title(f"{minimind.name}'s Memories")
        self.window.geometry("800x500")
        
        # Create the layout
        self.setup_layout()
        
        # Load memories
        self.load_memories()
    
    def setup_layout(self):
        """Set up the memory viewer layout"""
        # Configure grid for the main window
        self.window.grid_columnconfigure(0, weight=1)  # Left panel
        self.window.grid_columnconfigure(1, weight=3)  # Right panel
        self.window.grid_rowconfigure(0, weight=1)
        
        # Left frame - Memory list
        self.left_frame = ctk.CTkFrame(self.window)
        self.left_frame.grid(row=0, column=0, padx=10, pady=10, sticky="nsew")
        
        memory_label = ctk.CTkLabel(self.left_frame, text="Memories:", font=ctk.CTkFont(size=14, weight="bold"))
        memory_label.pack(anchor="w", padx=10, pady=10)
        
        # Using a scrollable frame with buttons instead of a listbox
        self.mem_scroll = ctk.CTkScrollableFrame(self.left_frame)
        self.mem_scroll.pack(fill="both", expand=True, padx=10, pady=(0, 10))
        
        # Right frame - Memory content
        self.right_frame = ctk.CTkFrame(self.window)
        self.right_frame.grid(row=0, column=1, padx=10, pady=10, sticky="nsew")
        
        self.mem_text = ctk.CTkTextbox(self.right_frame, wrap="word")
        self.mem_text.pack(fill="both", expand=True, padx=10, pady=10)
    
    def load_memories(self):
        """Load memories into the list"""
        # Clear existing widgets in the scrollable frame
        for widget in self.mem_scroll.winfo_children():
            widget.destroy()
        
        memory_files = []
        for item in os.listdir(self.memories_path):
            if item.endswith(".md"):
                memory_files.append(item)
                
        memory_files.sort(reverse=True)  # Most recent first
        
        for i, mem_file in enumerate(memory_files):
            # Extract timestamp for better display
            timestamp_match = re.search(r"(\d{8})-(\d{6})", mem_file)
            display_name = mem_file
            if timestamp_match:
                try:
                    timestamp = datetime.strptime(f"{timestamp_match.group(1)}-{timestamp_match.group(2)}", "%Y%m%d-%H%M%S")
                    display_name = f"{timestamp.strftime('%Y-%m-%d %H:%M:%S')} - {mem_file.split('-', 2)[-1]}"
                except:
                    pass
            
            # Create a more attractive button for each memory
            btn = ctk.CTkButton(
                self.mem_scroll, 
                text=display_name, 
                command=lambda file=mem_file: self.show_memory(file),
                anchor="w",
                height=30,
                fg_color="transparent",
                text_color=("gray10", "#DCE4EE"),
                hover_color=("gray70", "gray30"),
                corner_radius=0
            )
            btn.pack(fill="x", pady=2)
    
    def show_memory(self, mem_file):
        """Show the selected memory"""
        self.selected_memory = mem_file
        with open(os.path.join(self.memories_path, mem_file), "r") as f:
            self.mem_text.delete("1.0", "end")
            self.mem_text.insert("end", f.read())

class NoteEditor:
    def __init__(self, parent, minimind):
        """Initialize a note editor for a minimind"""
        self.parent = parent
        self.minimind = minimind
        self.selected_note = None
        
        # Create notes directory if it doesn't exist
        self.notes_path = os.path.join(minimind.path, "notes")
        os.makedirs(self.notes_path, exist_ok=True)
        
        # Create the window
        self.window = ctk.CTkToplevel(parent)
        self.window.title(f"{minimind.name}'s Notes")
        self.window.geometry("800x600")
        
        # Create the layout
        self.setup_layout()
        
        # Load notes
        self.load_notes()
    
    def setup_layout(self):
        """Set up the note editor layout"""
        # Configure grid for the main window
        self.window.grid_columnconfigure(0, weight=1)  # Left panel
        self.window.grid_columnconfigure(1, weight=3)  # Right panel
        self.window.grid_rowconfigure(0, weight=1)
        
        # Left frame - Note list
        self.left_frame = ctk.CTkFrame(self.window)
        self.left_frame.grid(row=0, column=0, padx=10, pady=10, sticky="nsew")
        
        note_label = ctk.CTkLabel(self.left_frame, text="Notes:", font=ctk.CTkFont(size=14, weight="bold"))
        note_label.pack(anchor="w", padx=10, pady=10)
        
        # Search box for semantic search
        self.search_frame = ctk.CTkFrame(self.left_frame)
        self.search_frame.pack(fill="x", padx=10, pady=(0, 10))
        
        self.search_entry = ctk.CTkEntry(self.search_frame, placeholder_text="Search notes...")
        self.search_entry.pack(side="left", fill="x", expand=True, padx=(0, 5))
        
        self.search_btn = ctk.CTkButton(self.search_frame, text="Search", width=80, command=self.semantic_search)
        self.search_btn.pack(side="right")
        
        # Using a scrollable frame with buttons instead of a listbox
        self.note_scroll = ctk.CTkScrollableFrame(self.left_frame)
        self.note_scroll.pack(fill="both", expand=True, padx=10, pady=(0, 10))
        
        # Controls for notes
        controls_frame = ctk.CTkFrame(self.left_frame)
        controls_frame.pack(fill="x", padx=10, pady=(0, 10))
        
        new_btn = ctk.CTkButton(controls_frame, text="New Note", command=self.create_new_note)
        new_btn.pack(side="left", padx=5, pady=5)
        
        del_btn = ctk.CTkButton(controls_frame, text="Delete Note", command=self.delete_note)
        del_btn.pack(side="left", padx=5, pady=5)
        
        # Right frame - Note content
        self.right_frame = ctk.CTkFrame(self.window)
        self.right_frame.grid(row=0, column=1, padx=10, pady=10, sticky="nsew")
        
        self.note_text = ctk.CTkTextbox(self.right_frame, wrap="word")
        self.note_text.pack(fill="both", expand=True, padx=10, pady=(10, 5))
        
        save_btn = ctk.CTkButton(self.right_frame, text="Save Note", command=self.save_note)
        save_btn.pack(side="right", padx=10, pady=(0, 10))
        
        # Status label
        self.status_var = ctk.StringVar(value="Ready")
        self.status_label = ctk.CTkLabel(self.right_frame, textvariable=self.status_var)
        self.status_label.pack(side="left", padx=10, pady=(0, 10))
    
    def load_notes(self):
        """Load notes into the list"""
        # Clear existing buttons
        for widget in self.note_scroll.winfo_children():
            widget.destroy()
        
        # Add buttons for each note file
        note_files = []
        for item in os.listdir(self.notes_path):
            if item.endswith(".md"):
                note_files.append(item)
                
        # Sort by timestamp (newest first)
        note_files.sort(reverse=True)
        
        for i, note_file in enumerate(note_files):
            # Try to parse title from file for better display
            title = note_file
            try:
                with open(os.path.join(self.notes_path, note_file), "r") as f:
                    first_line = f.readline().strip()
                    if first_line.startswith("# "):
                        title = first_line[2:]
            except:
                pass
                
            btn = ctk.CTkButton(
                self.note_scroll, 
                text=title, 
                command=lambda file=note_file: self.show_note(file),
                anchor="w",
                height=30,
                fg_color="transparent",
                text_color=("gray10", "#DCE4EE"),
                hover_color=("gray70", "gray30"),
                corner_radius=0
            )
            btn.pack(fill="x", pady=2)
    
    def create_new_note(self):
        """Create a new note"""
        title = simpledialog.askstring("New Note", "Enter title for the new note:")
        if not title:
            return
            
        # Create a safe filename
        filename = f"{re.sub(r'[^\w\s-]', '', title).strip().replace(' ', '-').lower()}.md"
        
        # Create the note file
        with open(os.path.join(self.notes_path, filename), "w") as f:
            f.write(f"# {title}\n\n")
            
        # Refresh the note list
        self.load_notes()
        
        # Show the new note
        self.show_note(filename)
    
    def delete_note(self):
        """Delete the selected note"""
        if not self.selected_note:
            messagebox.showinfo("No Selection", "Please select a note to delete.")
            return
            
        if messagebox.askyesno("Confirm Delete", f"Are you sure you want to delete this note?"):
            os.remove(os.path.join(self.notes_path, self.selected_note))
            
            # Also remove from vector store if available
            if hasattr(self.minimind, 'vector_store'):
                note_id = os.path.splitext(self.selected_note)[0]
                self.minimind.vector_store.remove_vector(note_id)
                
            self.selected_note = None
            self.note_text.delete("1.0", "end")
            self.load_notes()
    
    def save_note(self):
        """Save the selected note"""
        if not self.selected_note:
            messagebox.showinfo("No Selection", "Please select a note to save.")
            return
            
        content = self.note_text.get("1.0", "end")
        
        # Extract title from content
        title_match = re.search(r"# (.+?)\n", content)
        if not title_match:
            messagebox.showinfo("Invalid Format", "Note must start with a title line like '# Title'")
            return
            
        title = title_match.group(1)
        
        # Save the file
        with open(os.path.join(self.notes_path, self.selected_note), "w") as f:
            f.write(content)
            
        # Update vector embeddings if LLM interface is available
        if hasattr(self.minimind, 'llm_interface') and self.minimind.llm_interface:
            note_id = os.path.splitext(self.selected_note)[0]
            note_content = re.sub(r"# .+?\n", "", content, count=1).strip()
            
            # Show status
            self.status_var.set("Generating embeddings...")
            
            # Run in a separate thread to avoid UI freezing
            def update_embeddings():
                try:
                    # Generate embeddings
                    title_embedding, content_embedding, combined_embedding = \
                        self.minimind.llm_interface.get_combined_embedding(title, note_content)
                    
                    # Store in vector database
                    self.minimind.vector_store.update_vector(
                        note_id,
                        title_embedding,
                        content_embedding,
                        combined_embedding,
                        {"title": title, "updated_at": datetime.now().isoformat()}
                    )
                    
                    # Update UI on main thread
                    self.window.after(0, lambda: self.status_var.set("Note saved with embeddings"))
                except Exception as e:
                    # Update UI on main thread
                    self.window.after(0, lambda: self.status_var.set(f"Error: {str(e)}"))
            
            threading.Thread(target=update_embeddings, daemon=True).start()
        else:
            self.status_var.set("Note saved")
    
    def show_note(self, note_file):
        """Show the selected note"""
        self.selected_note = note_file
        with open(os.path.join(self.notes_path, note_file), "r") as f:
            self.note_text.delete("1.0", "end")
            self.note_text.insert("end", f.read())
    
    def semantic_search(self):
        """Search notes semantically using embeddings"""
        query = self.search_entry.get().strip()
        if not query:
            return
            
        # Show status
        self.status_var.set("Searching...")
        
        # Check if LLM interface is available
        if not hasattr(self.minimind, 'llm_interface') or not self.minimind.llm_interface:
            self.status_var.set("Error: Semantic search requires LLM interface")
            return
            
        def do_search():
            try:
                # Get the query result
                result = self.minimind.query_notes(query)
                
                # Clear existing buttons
                self.window.after(0, lambda: [widget.destroy() for widget in self.note_scroll.winfo_children()])
                
                # Parse the results
                lines = result.split("\n")
                found_notes = []
                
                for line in lines:
                    if line.startswith("- "):
                        # Extract title
                        match = re.search(r"- (.+?)(?: \(\d+% match\))?$", line)
                        if match:
                            title = match.group(1)
                            found_notes.append(title)
                
                # Find matching files and add buttons
                if found_notes:
                    note_files = []
                    for filename in os.listdir(self.notes_path):
                        if filename.endswith(".md"):
                            file_path = os.path.join(self.notes_path, filename)
                            with open(file_path, "r") as f:
                                first_line = f.readline().strip()
                                if first_line.startswith("# "):
                                    file_title = first_line[2:]
                                    if file_title in found_notes:
                                        note_files.append((filename, file_title, found_notes.index(file_title)))
                    
                    # Sort by the order they appeared in search results
                    note_files.sort(key=lambda x: x[2])
                    
                    # Add buttons
                    def add_button(filename, title):
                        btn = ctk.CTkButton(
                            self.note_scroll, 
                            text=title, 
                            command=lambda f=filename: self.show_note(f),
                            anchor="w",
                            height=30,
                            fg_color=("gray80", "gray40"),  # Highlight search results
                            text_color=("gray10", "#DCE4EE"),
                            hover_color=("gray70", "gray30"),
                            corner_radius=0
                        )
                        btn.pack(fill="x", pady=2)
                    
                    for filename, title, _ in note_files:
                        self.window.after(0, lambda f=filename, t=title: add_button(f, t))
                    
                    self.window.after(0, lambda: self.status_var.set(f"Found {len(note_files)} matching notes"))
                else:
                    self.window.after(0, lambda: self.status_var.set("No matching notes found"))
                    
            except Exception as e:
                self.window.after(0, lambda: self.status_var.set(f"Error: {str(e)}"))
                self.window.after(0, self.load_notes)  # Reload all notes on error
        
        threading.Thread(target=do_search, daemon=True).start()
---

## minimind.py

---python
import os
import re
from datetime import datetime
import uuid
import customtkinter as ctk
from tkinter import simpledialog
from vector_store import NoteVectorStore
from markdown_utils import MarkdownVault
from cot_perturb import perturb_chain_of_thought
import json
from core.agent import Agent  # Import the new Agent base class

class Minimind(Agent):
    """A minimind agent that inherits from the Agent base class"""
    def __init__(self, name, llm_interface=None):
        """Initialize a minimind with the given name"""
        super().__init__(name)  # Call Agent's __init__
        self.path = os.path.join("miniminds", name)
        self.llm_interface = llm_interface  # For generating embeddings
        
        # Initialize vector store
        self.vector_store = NoteVectorStore(name)
        
        # Ensure directories exist
        self._ensure_directories()
        
        # Load profile
        self.profile = self._load_profile()
        
        # Load templates from vault
        self.prompt_template = MarkdownVault.load_template("prompt_template")
        self.memory_format = MarkdownVault.load_template("memory_format")
        self.note_format = MarkdownVault.load_template("note_format")
        self.agent_system_prompt = MarkdownVault.load_template("agent_system_prompt")

    @classmethod
    def create_new(cls, name, llm_interface=None):
        """Create a new minimind with default profile"""
        minimind = cls(name, llm_interface)
        
        # Create default profile if it doesn't exist
        if not os.path.exists(os.path.join(minimind.path, "profile.md")):
            # Load default profile template from vault
            profile_template = MarkdownVault.load_template("default_profile")
            
            # Fill template with name
            profile_content = MarkdownVault.fill_template(profile_template, {"name": name})
            
            with open(os.path.join(minimind.path, "profile.md"), "w") as f:
                f.write(profile_content)
            
            minimind.profile = profile_content
        
        return minimind

    @classmethod
    def get_all_miniminds(cls):
        """Get a list of all minimind names"""
        miniminds = []
        if not os.path.exists("miniminds"):
            return miniminds
            
        for item in os.listdir("miniminds"):
            full_path = os.path.join("miniminds", item)
            if os.path.isdir(full_path) and os.path.exists(os.path.join(full_path, "profile.md")):
                miniminds.append(item)
        
        return miniminds

    def _ensure_directories(self):
        """Ensure required directories exist"""
        os.makedirs(self.path, exist_ok=True)
        os.makedirs(os.path.join(self.path, "memories"), exist_ok=True)
        os.makedirs(os.path.join(self.path, "notes"), exist_ok=True)

    def _load_profile(self):
        """Load the character's profile"""
        profile_path = os.path.join(self.path, "profile.md")
        if os.path.exists(profile_path):
            with open(profile_path, "r") as f:
                return f.read()
        return ""

    def set_location(self, location):
        """Set the minimind's location"""
        super().set_location(location)  # Call the parent method 
        # Any additional Minimind-specific logic can go here
    
    def get_profile(self):
        if self.profile:
            return self.profile
        return ""

    def get_memories(self, max_count=13):
        """Get the character's recent memories"""
        memories_path = os.path.join(self.path, "memories")
        memory_files = []
        
        if not os.path.exists(memories_path):
            return []
            
        for item in os.listdir(memories_path):
            if item.endswith(".md"):
                memory_files.append(item)
                
        # Sort by timestamp (newest first)
        memory_files.sort(reverse=True)
        
        # Take most recent memories
        memories = []
        for mem_file in memory_files[:max_count]:
            with open(os.path.join(memories_path, mem_file), "r") as f:
                memories.append(f.read())
        
        return memories

    def get_relevant_memories(self, query, max_count=10):
        """Get memories relevant to a specific query"""
        memories_path = os.path.join(self.path, "memories")
        memory_files = []
        
        if not os.path.exists(memories_path):
            return []
            
        for item in os.listdir(memories_path):
            if item.endswith(".md"):
                memory_files.append(item)
        
        # Calculate relevance scores
        scored_memories = []
        for mem_file in memory_files:
            with open(os.path.join(memories_path, mem_file), "r") as f:
                content = f.read()
                
                # Extract timestamp for recency calculation
                timestamp_match = re.search(r"(\d{8}-\d{6})", mem_file)
                if timestamp_match:
                    try:
                        timestamp = datetime.strptime(timestamp_match.group(1), "%Y%m%d-%H%M%S")
                        age = (datetime.now() - timestamp).total_seconds()
                        recency_score = 1.0 / (1.0 + age/3600)  # Higher for more recent memories
                    except:
                        recency_score = 0.1
                else:
                    recency_score = 0.1
                
                # Calculate relevance to query
                relevance_score = 0.0
                if query.lower() in content.lower():
                    relevance_score = 0.8
                elif any(term in content.lower() for term in query.lower().split()):
                    relevance_score = 0.4
                
                # Extract importance from emoji structure if available
                importance_score = 0.5  # Default medium importance
                importance_match = re.search(r"❓(.*?)(?=,|$)", content)
                if importance_match:
                    importance_text = importance_match.group(1).lower()
                    if "urgent" in importance_text or "critical" in importance_text:
                        importance_score = 0.9
                    elif "important" in importance_text:
                        importance_score = 0.7
                
                # Calculate combined score
                combined_score = 0.5 * recency_score + 0.3 * relevance_score + 0.2 * importance_score
                scored_memories.append((mem_file, content, combined_score))
        
        # Sort by score (highest first) and take top N
        scored_memories.sort(key=lambda x: x[2], reverse=True)
        return [content for _, content, _ in scored_memories[:max_count]]

    def get_notes(self, max_count=7):
        """Get the character's most recent notes"""
        notes_path = os.path.join(self.path, "notes")
        note_files = []
        
        if not os.path.exists(notes_path):
            return []
            
        # Get all note files with their modification times
        note_files_with_times = []
        for item in os.listdir(notes_path):
            if item.endswith(".md"):
                file_path = os.path.join(notes_path, item)
                # Get the modification time of the file
                mod_time = os.path.getmtime(file_path)
                note_files_with_times.append((item, mod_time))
        
        # Sort by modification time (newest first)
        note_files_with_times.sort(key=lambda x: x[1], reverse=True)
        
        # Take most recent notes
        notes = []
        for note_file, _ in note_files_with_times[:max_count]:
            with open(os.path.join(notes_path, note_file), "r") as f:
                notes.append(f.read())
        
        return notes

    def get_relevant_notes(self, query, max_count=5, always_include_most_recent=True):
        """Get notes semantically relevant to a query
        
        Always returns up to max_count notes, even if similarity is low.
        """
        if not self.llm_interface:
            # If we don't have an LLM interface, fall back to recent notes
            return self.get_notes(max_count)
        
        try:
            # CHANGED: Always prioritize the agent's most recent reason for semantic matching
            # This helps "shake up" the agent's thoughts by retrieving notes related to their
            # current goals and motivations rather than just context
            reason_query = getattr(self, 'last_command_reason', None)
            
            # If we have a recent reason, use that as the query instead of the provided query
            if reason_query:
                query_to_use = reason_query
            else:
                # If no reason is available, fall back to the provided query
                query_to_use = query
                
            # Get embedding for the query
            query_embeddings = self.llm_interface.get_embeddings(query_to_use)
            if not query_embeddings or len(query_embeddings) == 0:
                return self.get_notes(max_count)
                    
            query_embedding = query_embeddings[0]
            
            # Track how many notes to add from similarity search
            remaining_count = max_count
            notes = []
            
            # Keep track of note IDs we've already included
            added_note_ids = set()
            
            # If we want to always include the most recent note
            if always_include_most_recent:
                recent_notes = self.get_notes(1)
                if recent_notes:
                    notes.append(recent_notes[0])
                    remaining_count -= 1
                    
                    # Try to determine the ID of the most recent note
                    notes_dir = os.path.join(self.path, "notes")
                    if os.path.exists(notes_dir):
                        recent_files = []
                        for item in os.listdir(notes_dir):
                            if item.endswith(".md"):
                                file_path = os.path.join(notes_dir, item)
                                mod_time = os.path.getmtime(file_path)
                                recent_files.append((item, mod_time))
                        
                        # Add the ID to our tracking set
                        if recent_files:
                            recent_files.sort(key=lambda x: x[1], reverse=True)
                            most_recent_filename = recent_files[0][0]
                            most_recent_note_id = os.path.splitext(most_recent_filename)[0]
                            added_note_ids.add(most_recent_note_id)
            
            # Get similar notes from vector store - use minimum similarity of 0
            # to ensure we always get as many notes as possible
            similar_notes = self.vector_store.get_similar_notes(
                query_embedding, 
                vector_type="combined", 
                top_n=remaining_count * 2,  # Get extra to account for filtering
                min_similarity=0.0  # No minimum threshold
            )
            
            # Filter out any notes we've already added and load unique notes
            notes_path = os.path.join(self.path, "notes")
            for note_id, _ in similar_notes:
                # Skip if we've already added this note or reached our limit
                if note_id in added_note_ids or len(notes) >= max_count:
                    continue
                    
                # Load the note
                file_path = os.path.join(notes_path, f"{note_id}.md")
                if os.path.exists(file_path):
                    with open(file_path, "r") as f:
                        notes.append(f.read())
                    added_note_ids.add(note_id)
            
            # If we still don't have enough notes from embedding search,
            # supplement with recent notes
            if len(notes) < max_count:
                # Calculate how many more we need
                additional_needed = max_count - len(notes)
                
                # Get more recent notes
                recent_files = []
                
                notes_dir = os.path.join(self.path, "notes")
                if os.path.exists(notes_dir):
                    # Get all note files with modification times
                    for item in os.listdir(notes_dir):
                        if item.endswith(".md"):
                            file_path = os.path.join(notes_dir, item)
                            mod_time = os.path.getmtime(file_path)
                            note_id = os.path.splitext(item)[0]
                            if note_id not in added_note_ids:  # Skip duplicates
                                recent_files.append((item, mod_time))
                    
                    # Sort by time, newest first
                    recent_files.sort(key=lambda x: x[1], reverse=True)
                    
                    # Add up to the additional needed
                    for filename, _ in recent_files[:additional_needed]:
                        file_path = os.path.join(notes_dir, filename)
                        with open(file_path, 'r') as f:
                            notes.append(f.read())
            
            return notes
            
        except Exception as e:
            print(f"Error getting relevant notes: {str(e)}")
            # Fall back to recent notes
            return self.get_notes(max_count)

    def create_note(self, title, content, reason=None):
        """Create a new note or update an existing one with the same title"""
        # Create a safe filename without timestamp
        safe_title = re.sub(r'[^\w\s-]', '', title).strip().replace(' ', '-').lower()
        
        # Check if a note with this title already exists
        notes_dir = os.path.join(self.path, "notes")
        os.makedirs(notes_dir, exist_ok=True)
        
        existing_file = None
        for filename in os.listdir(notes_dir):
            if filename.endswith('.md'):
                file_path = os.path.join(notes_dir, filename)
                with open(file_path, 'r') as f:
                    first_line = f.readline().strip()
                    if first_line == f"# {title}":
                        existing_file = filename
                        break
        
        # Determine the note_id and filename to use
        if existing_file:
            note_id = os.path.splitext(existing_file)[0]  # Remove .md extension
            final_filename = existing_file
        else:
            # Create a note ID based on the title
            note_id = safe_title
            final_filename = f"{note_id}.md"
        
        # Get current time and location for metadata
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        location = self.location or "unknown location"
        
        # Get characters present at the location from the world
        present_characters = []
        try:
            from world import World
            world_instance = World.get_instance()
            location_data = world_instance.get_location_data(location)
            if location_data and "characters" in location_data:
                present_characters = location_data["characters"]
        except:
            # If we can't get characters, just use the minimind's name
            present_characters = [self.name]
        
        # Format characters as a comma-separated list
        characters_text = ", ".join(present_characters)
        
        # Prepare data for note template
        note_data = {
            "title": title,
            "title_lower": title.lower(),
            "characters": characters_text,
            "location": location,
            "current_time": current_time,
            "reason": reason or "To guide myself",
            "content": content
        }
        
        # Fill the note template
        note_content = MarkdownVault.fill_template(self.note_format, note_data)
        
        # Create or update the note file
        file_path = os.path.join(notes_dir, final_filename)
        with open(file_path, "w") as f:
            f.write(note_content)
        
        # Generate embeddings if we have an LLM interface
        if self.llm_interface:
            try:
                # Generate embeddings for title and enriched content
                title_embedding, content_embedding, combined_embedding = \
                    self.llm_interface.get_combined_embedding(title, note_content)
                
                # Store in vector database
                self.vector_store.update_vector(
                    note_id,
                    title_embedding,
                    content_embedding,
                    combined_embedding,
                    {"title": title, "updated_at": current_time}
                )
            except Exception as e:
                print(f"Error generating embeddings for note: {str(e)}")
        
        return final_filename

    def add_note_command(self, title, content, reason=None):
        """Add a note via a command with automatically added metadata"""
        # Create the note with metadata and reason
        if content == "":
            content = "(empty note)"
        self.create_note(title, content, reason)
        
        # Add memory of creating the note
        self.add_action_memory(f"made a mental note about '{title}':\n{content}")
        
        return f"You made a mental note about '{title}':\n---\n{content}\n---"
    
    def query_notes(self, query):
        """Find notes similar to a query - always returns full content for up to 16 notes"""
        notes_dir = os.path.join(self.path, "notes")
        min_notes_count = 16
        
        try:
            # Start with exact title matches
            exact_match_results = []
            for filename in os.listdir(notes_dir):
                if filename.endswith('.md'):
                    file_path = os.path.join(notes_dir, filename)
                    with open(file_path, 'r') as f:
                        content = f.read()
                        lines = content.split('\n')
                        first_line = lines[0].strip()
                        title = first_line[2:] if first_line.startswith("# ") else first_line
                        
                        if title.lower() == query.lower():
                            exact_match_results.append((os.path.splitext(filename)[0], 1.0, content))
            
            # Use vector similarity if available
            similar_notes = []
            if self.llm_interface:
                try:
                    query_embeddings = self.llm_interface.get_embeddings(query)
                    if query_embeddings and len(query_embeddings) > 0:
                        query_embedding = query_embeddings[0]
                        vector_results = self.vector_store.get_similar_notes(
                            query_embedding, 
                            vector_type="combined", 
                            top_n=min_notes_count,
                            min_similarity=0.0  # No minimum threshold
                        )
                        
                        # Add content to vector results
                        for note_id, similarity in vector_results:
                            file_path = os.path.join(notes_dir, f"{note_id}.md")
                            if os.path.exists(file_path):
                                with open(file_path, 'r') as f:
                                    content = f.read()
                                    similar_notes.append((note_id, similarity, content))
                except Exception as e:
                    print(f"Embedding error: {str(e)}")
            
            # Combine results (exact matches first)
            exact_match_ids = [m[0] for m in exact_match_results]
            all_results = exact_match_results + [n for n in similar_notes if n[0] not in exact_match_ids]
            
            # If we need more notes to reach minimum, add random ones
            if len(all_results) < min_notes_count:
                random_notes = []
                existing_ids = [r[0] for r in all_results]
                
                all_files = [f for f in os.listdir(notes_dir) if f.endswith('.md')]
                
                for filename in all_files:
                    note_id = os.path.splitext(filename)[0]
                    if note_id not in existing_ids:
                        file_path = os.path.join(notes_dir, f"{filename}")
                        with open(file_path, 'r') as f:
                            content = f.read()
                            random_notes.append((note_id, 0.0, content))
                
                import random
                random.shuffle(random_notes)
                all_results.extend(random_notes[:min_notes_count - len(all_results)])
            
            # Format the results with full note content
            formatted_results = []
            for note_id, similarity, content in all_results[:min_notes_count]:
                lines = content.split('\n')
                first_line = lines[0].strip()
                title = first_line[2:] if first_line.startswith("# ") else first_line
                
                similarity_percent = int(similarity * 100)
                formatted_results.append(f"## {title} ({similarity_percent}% match to example)\n{content}")
            
            if not formatted_results:
                return "No notes found."
                
            return "Notes related to your example:\n\n" + "\n\n".join(formatted_results)
            
        except Exception as e:
            return f"Error querying notes: {str(e)}"

    def add_memory(self, memory_type, content, reason=None):
        """
        Implement the add_memory method required by the Agent base class
        
        Args:
            memory_type: Type of memory (e.g., 'action', 'observed', 'response')
            content: The content of the memory
            reason: The reason for creating this memory
        """
        if memory_type == "action":
            self.add_action_memory(content)
        elif memory_type == "observed":
            # Split content into actor and action if possible
            parts = content.split(" ", 1)
            if len(parts) > 1:
                actor, action = parts
                self.add_observation_memory(actor, action, reason)
            else:
                # If we can't split properly, just use content as is
                self.add_observation_memory("unknown", content, reason)
        elif memory_type == "response":
            action = self.last_command or "unknown action"
            self.add_response_memory(action, content, reason)
        else:
            # For other memory types, use _add_memory directly
            self._add_memory(memory_type, content, reason)

    def _add_memory(self, memory_type, content, reason=None):
        """Add a memory to the character's memory store with concise formatting"""
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        memory_id = str(uuid.uuid4())[:8]  # Create a short unique ID
        filename = f"{timestamp}-{memory_type}.md"
        
        memories_dir = os.path.join(self.path, "memories")
        os.makedirs(memories_dir, exist_ok=True)
        memory_path = os.path.join(memories_dir, filename)
        
        # Get current time for the memory
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # CHANGE: Always prioritize using last_command_reason as the 'Why'
        # This makes it act like a "running thought" that applies to all memories
        why = getattr(self, 'last_command_reason', None) or reason or "Unknown motivation"
        
        # Prepare data for memory template
        memory_data = {
            "memory_type": memory_type.capitalize(),
            "memory_id": memory_id,
            "who": "",
            "what": "",
            "where": "",
            "when": "",
            "why": why,
            "how": ""
        }
        
        # Format the memory with the structured format
        if memory_type == "action":
            memory_data.update({
                "who": self.name,
                "what": content,
                "where": self.location or "unknown",
                "when": current_time,
                "how": "command"
            })
            
        elif memory_type == "observed":
            parts = content.split(" ", 1)
            if len(parts) > 1:
                observed = parts[0]
                action = parts[1]
                
                memory_data.update({
                    "who": observed,
                    "what": observed + " " + action,
                    "where": self.location or "unknown",
                    "when": current_time,
                    "how": "Observed by " + self.name,
                    "why": reason or "Unknown"
                })
            else:
                # Fallback if we can't parse properly
                memory_data.update({
                    "who": "Unknown",
                    "what": content,
                    "where": self.location or "unknown",
                    "when": current_time,
                    "how": "Observed",
                    "why": reason or "Unknown"
                })
        
        # Fill the memory template
        memory_content = MarkdownVault.fill_template(self.memory_format, memory_data)
        
        with open(memory_path, "w") as f:
            f.write(memory_content)

    def add_action_memory(self, action):
        """Add a memory of an action the character performed"""
        # No need to get the reason from the last command - _add_memory will use last_command_reason
        self._add_memory("action", action)

    def add_observation_memory(self, actor, action, reason=None):
        """Add a memory of something the character observed"""
        content = f"{actor} {action}"
        
        # Let _add_memory prioritize last_command_reason then use the provided fallback reason
        self._add_memory("observed", content, reason)

    def add_response_memory(self, action, response, reason=None):
        """Add a memory of a response to an action"""
        memory_id = str(uuid.uuid4())[:8]
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # CHANGE: Prioritize last_command_reason for the Why component
        why = getattr(self, 'last_command_reason', None) or reason or "Unclear"
        
        # Prepare memory data
        memory_data = {
            "memory_type": "Response",
            "memory_id": memory_id,
            "who": self.name,
            "what": response,
            "where": self.location or "unknown",
            "when": timestamp,
            "why": why,
            "how": action
        }
        
        # Fill the memory template
        memory_content = MarkdownVault.fill_template(self.memory_format, memory_data)
        
        # Save the memory
        memories_dir = os.path.join(self.path, "memories")
        os.makedirs(memories_dir, exist_ok=True)
        memory_path = os.path.join(memories_dir, f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-response.md")
        
        with open(memory_path, "w") as f:
            f.write(memory_content)

    def edit_profile(self, parent):
        """Open a window to edit the character's profile"""
        edit_window = ctk.CTkToplevel(parent)
        edit_window.title(f"Edit {self.name}'s Profile")
        edit_window.geometry("600x400")
        
        main_frame = ctk.CTkFrame(edit_window)
        main_frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Title
        title_label = ctk.CTkLabel(
            main_frame, 
            text=f"Editing {self.name}'s Profile", 
            font=ctk.CTkFont(size=16, weight="bold")
        )
        title_label.pack(pady=10)
        
        # Editor
        edit_text = ctk.CTkTextbox(main_frame, wrap="word")
        edit_text.pack(fill="both", expand=True, padx=10, pady=(0, 10))
        
        # Load content
        edit_text.insert("end", self.profile)
            
        # Button frame
        button_frame = ctk.CTkFrame(main_frame)
        button_frame.pack(fill="x", pady=5)
        
        def save_profile():
            # Update profile
            self.profile = edit_text.get("1.0", "end")
            
            # Save to file
            with open(os.path.join(self.path, "profile.md"), "w") as f:
                f.write(self.profile)
                
            edit_window.destroy()
        
        # Save button    
        save_btn = ctk.CTkButton(
            button_frame, 
            text="Save Profile", 
            command=save_profile,
            font=ctk.CTkFont(weight="bold")
        )
        save_btn.pack(side="right", padx=10, pady=5)
        
        # Cancel button
        cancel_btn = ctk.CTkButton(
            button_frame, 
            text="Cancel", 
            command=edit_window.destroy,
            fg_color="transparent",
            text_color=("gray10", "#DCE4EE"),
            hover_color=("gray70", "gray30")
        )
        cancel_btn.pack(side="right", padx=10, pady=5)

    def store_thought_chain(self, thought_chain):
        """Store the agent's chain of thought from the last response
        
        Also extract key reasoning to set as last_command_reason if none exists
        And create an auto-note with the perturbed thought chain to avoid feedback loops
        """
        self.last_thought_chain = thought_chain
        
        # If there's no current last_command_reason, try to extract one from the thought chain
        if not hasattr(self, 'last_command_reason') or not self.last_command_reason:
            # Extract reasoning from thought chain - look for specific patterns
            reasoning_patterns = [
                r"I should ([^\.]+)",
                r"I want to ([^\.]+)",
                r"I need to ([^\.]+)",
                r"I'm trying to ([^\.]+)",
                r"I am ([^\.]+)",
                r"My goal is to ([^\.]+)",
                r"My intention is to ([^\.]+)"
            ]
            
            for pattern in reasoning_patterns:
                matches = re.findall(pattern, thought_chain, re.IGNORECASE)
                if matches and len(matches[0]) > 3:  # Ensure it's substantive
                    self.last_command_reason = matches[0][:100].strip()  # Limit length
                    break
        
        # Create auto-note with the perturbed thought chain
        # try:
            # # Get location and characters present
            # location = self.location or "unknown"
            
            # # Get characters present at the location from the world
            # present_characters = []
            # try:
                # from world import World
                # world_instance = World.get_instance()
                # location_data = world_instance.get_location_data(location)
                # if location_data and "characters" in location_data:
                    # present_characters = location_data["characters"]
                    # present_characters.sort()  # Sort for consistency in title
            # except Exception as inner_e:
                # # If we can't get characters, just use the minimind's name
                # present_characters = [self.name]
            
            # # Format characters as a comma-separated list
            # characters_text = " ".join(present_characters)
            
            # # Create title based on location and characters present - 
            # # Note: No timestamp in title to encourage overwriting old notes in similar situations
            # title = f"Thoughts at {location} with {characters_text}"
            
            
            # # Perturb the thought chain to avoid feedback loops
            # perturbed_content = perturb_chain_of_thought(thought_chain)
            
            # # Add a note at the beginning to indicate this is perturbed
            # note_content = perturbed_content
            
            # # Create note with perturbed thought chain
            # reason = "Thinking about my situation"
            # self.create_note(title, note_content, reason)
        # except Exception as e:
            # print(f"Error creating auto-note: {str(e)}")
            
    def store_last_command(self, command, result):
        """Store the last command and its result"""
        self.last_command = command
        self.last_command_result = result

    def get_last_thought_chain(self):
        """Get the agent's last chain of thought"""
        return getattr(self, 'last_thought_chain', None)

    def get_last_command_info(self):
        """Get the agent's last command and result"""
        command = getattr(self, 'last_command', None)
        result = getattr(self, 'last_command_result', None)
        return command, result
        
    def index_all_notes(self):
        """Index all notes to generate embeddings for existing notes"""
        if not self.llm_interface:
            return "No LLM interface available for indexing"
            
        notes_dir = os.path.join(self.path, "notes")
        if not os.path.exists(notes_dir):
            return "No notes directory found"
            
        notes_indexed = 0
        for filename in os.listdir(notes_dir):
            if filename.endswith('.md'):
                note_id = os.path.splitext(filename)[0]
                file_path = os.path.join(notes_dir, filename)
                
                # Read the note
                with open(file_path, 'r') as f:
                    content = f.read()
                    
                # Extract title
                title_match = re.search(r"# (.+?)\n", content)
                if title_match:
                    title = title_match.group(1)
                    note_content = re.sub(r"# .+?\n", "", content, count=1).strip()
                    
                    # Generate embeddings
                    try:
                        title_embedding, content_embedding, combined_embedding = \
                            self.llm_interface.get_combined_embedding(title, note_content)
                        
                        # Store in vector database
                        self.vector_store.update_vector(
                            note_id,
                            title_embedding,
                            content_embedding,
                            combined_embedding,
                            {"title": title, "indexed_at": datetime.now().isoformat()}
                        )
                        notes_indexed += 1
                    except Exception as e:
                        print(f"Error indexing note {filename}: {str(e)}")
        
        return f"Indexed {notes_indexed} notes successfully"

    def get_context_rich_query(self, location_data):
        """Create a context-rich query combining situation, recent memories, and recent notes"""
        # Get current situation 
        location_description = location_data.get("description", "")
        situation = f"In the {self.location}: {location_description}"
        
        other_characters = [c for c in location_data.get("characters", []) if c != self.name]
        if other_characters:
            situation += f" With characters: {', '.join(other_characters)}"
        
        # Get 3 most recent memories (this value could also be configurable if needed)
        recent_memories = self.get_memories(3)
        memory_texts = []
        for memory in recent_memories:
            # Extract content from memory structure
            content_match = re.search(r"\n\n(.+?)$", memory, re.DOTALL)
            if content_match:
                memory_texts.append(content_match.group(1).strip())
        
        # Get 2 most recent notes (this value could also be configurable if needed)
        recent_notes = self.get_notes(2)
        note_texts = []
        for note in recent_notes:
            # Extract title and first paragraph
            title_match = re.search(r"# (.+?)\n", note)
            content_match = re.search(r"# .+?\n\n(.+?)(?=\n\n|$)", note, re.DOTALL)
            if title_match and content_match:
                note_texts.append(f"{title_match.group(1)}: {content_match.group(1)}")
        
        # Combine everything into a rich context query
        query_parts = []
        query_parts.append(f"Current situation: {situation}")
        
        if memory_texts:
            query_parts.append(f"Recent memories: {' | '.join(memory_texts[:3])}")
        
        if note_texts:
            query_parts.append(f"Recent notes: {' | '.join(note_texts[:2])}")
        
        return " ".join(query_parts)

    def save_turn_details(self, prompt, system_prompt, llm_response, parsed_command, command_result):
        """Save details of a turn to a file for analysis
        
        Args:
            prompt: The full prompt sent to the LLM
            system_prompt: The system prompt used (if any)
            llm_response: The full response from the LLM
            parsed_command: The parsed command extracted from the response
            command_result: The result of executing the command
        """
        # Create a turns directory if it doesn't exist
        turns_dir = os.path.join(self.path, "turns")
        os.makedirs(turns_dir, exist_ok=True)
        
        # Create a timestamped filename
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        filename = f"{timestamp}-turn.md"
        filepath = os.path.join(turns_dir, filename)
        
        # Format the content
        content = f"""# Turn Details for {self.name} at {timestamp}

## Prompt
{prompt or "None provided"}


## Response
{llm_response or "None provided"}


## Parsed Command
{parsed_command or "None provided"}


## Result
{command_result or "None provided"}"""
        
        # Write to file
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        
        return filepath

    def construct_prompt(self, location_data, max_memories=10, max_notes=5):
        """Construct a prompt for the LLM based on character state
        
        Returns:
            tuple: (prompt_text, system_prompt)
        """
        # Get current time for the prompt
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Get room exits
        connections = location_data.get("connections", [])
        
        # Get characters in the same location
        characters_here = location_data.get("characters", [])
        other_characters = [c for c in characters_here if c != self.name]
        
        # Format exits
        if connections:
            if len(connections) == 1:
                exits_text = f"You can GO TO {connections[0]} from here."
            else:
                conn_list = ", ".join(connections[:-1]) + " and " + connections[-1]
                exits_text = f"You can GO TO {conn_list} from here."
        else:
            exits_text = f"You see nowhere you can GO TO from here."
        
        # Format characters present
        if other_characters:
            if len(other_characters) == 1:
                chars_text = f"{other_characters[0]} is here."
            else:
                char_list = ", ".join(other_characters[:-1]) + " and " + other_characters[-1]
                chars_text = f"{char_list} are here."
        else:
            chars_text = "You are alone here."
        
        # Get recent memories using the max_memories parameter
        memories = self.get_memories(max_memories)
        # The order of the memories by default is newest first, which is probably fine here to weight them more heavily in the prompt? Stuff near the beginning seems to "color" stuff read later on, so "looking backward" probably helps here
        memories.reverse() # Comment if you want to try newest first
        
        # Format memories
        memories_text = ""
        for memory in memories:
            # Extract components from the structured format
            memory_match = re.search(r"🧠([\w\d]+):{(.*?)}", memory, re.DOTALL)
            if memory_match and False: # Skip parsing, just show the raw memories
                structure = memory_match.group(2)
                
                # Extract individual components with more robust patterns
                components = {
                    "who": re.search(r"👥(.*?)(?=👥|💡|📍|📅|❓|🔧|$)", structure, re.DOTALL),
                    "what": re.search(r"💡(.*?)(?=👥|💡|📍|📅|❓|🔧|$)", structure, re.DOTALL),
                    "where": re.search(r"📍(.*?)(?=👥|💡|📍|📅|❓|🔧|$)", structure, re.DOTALL),
                    "when": re.search(r"📅(.*?)(?=👥|💡|📍|📅|❓|🔧|$)", structure, re.DOTALL),
                    "why": re.search(r"❓(.*?)(?=👥|💡|📍|📅|❓|🔧|$)", structure, re.DOTALL),
                    "how": re.search(r"🔧(.*?)(?=👥|💡|📍|📅|❓|🔧|$)", structure, re.DOTALL)
                }
                
                # Extract the actual values from the match objects
                who = components["who"].group(1) if components["who"] else "Unknown"
                what = components["what"].group(1) if components["what"] else "Unknown"
                where = components["where"].group(1) if components["where"] else "Unknown"
                when = components["when"].group(1) if components["when"] else "Unknown"
                why = components["why"].group(1) if components["why"] else "Unknown"
                how = components["how"].group(1) if components["how"] else "Unknown" # Probably not needed here, since we're just interested in the storytelling details and how is usually just the command
                
                # Format as a readable log entry
                memories_text += f"📅{when} in 📍{where} (🔧{how} ❓{why}): 👥{who} 💡{what}\n"
            else:
                # Alternative parsing approach for memories that don't match the pattern
                # This is a fallback to handle potential format variations
                title_match = re.search(r"# (.*?) Memory", memory)
                content_match = re.search(r"\n\n(.+)$", memory, re.DOTALL)
                
                if title_match and content_match:
                    memory_type = title_match.group(1)
                    content = content_match.group(1).strip()
                    # Add as plain text if structured parsing fails
                    memories_text += f"{content}\n\n"
                else:
                    # Extreme fallback, just chuck whatever we have in there
                    memories_text += f"{memory}\n\n"
        
        # Get semantically relevant notes based on current situation using max_notes parameter
        location_description = location_data.get("description", "")
        situation_query = f"In the {self.location}: {location_description}"
        if other_characters:
            situation_query += f" With characters: {', '.join(other_characters)}"
            
        # Try to get semantically relevant notes if LLM interface is available
        if self.llm_interface:
            context_query = self.get_context_rich_query(location_data)
            notes = self.get_relevant_notes(context_query, max_count=max_notes)
        else:
            notes = self.get_notes(max_notes)
            
        # Format notes
        notes_text = ""
        for note in notes:
            # Extract just the title and content for cleaner presentation
            title_match = re.search(r"# (.+?)\n", note)
            if title_match:
                title = title_match.group(1)
                content = re.sub(r"# .+?\n", "", note, count=1).strip()
                notes_text += f"## {title}\n{content}\n\n"
            else:
                notes_text += f"{note}\n\n"
        
        # Prior command and result
        last_command_text = None
        last_result_text = None
        
        last_command, last_result = self.get_last_command_info()
        if last_command and last_result:
            last_command_text = last_command
            
            success = "Succeeded" if last_result.get("success", False) else "Failed"
            message = last_result.get("message", "No message")
            last_result_text = f"{success}: {message}"
        
        # Perturb previous thought chain if it exists
        last_thought_text = None
        if hasattr(self, 'last_thought_chain') and self.last_thought_chain:
            
            # Apply perturbation to break repetition patterns
            last_thought_text = perturb_chain_of_thought(self.last_thought_chain)
        
        # Prepare data for the prompt template
        prompt_data = {
            "name": self.name,
            "profile": self.profile,
            "memories": memories_text,
            "notes": notes_text,
            "last_command": last_command_text,
            "last_result": last_result_text,
            "current_time": current_time,
            "location": self.location,
            "location_description": location_data.get("description", "Nothing to see here."),
            "location_exits": exits_text,
            "location_characters": chars_text,
            "last_thought": last_thought_text
        }
        
        # Add the agent profile to the system profile for some extra "weight" in the LLM's behavior
        profile_and_system_prompt = self.profile + self.agent_system_prompt
        
        # Fill the prompt template and return both the prompt and system prompt
        filled_prompt = MarkdownVault.fill_template(self.prompt_template, prompt_data)
        return (filled_prompt, self.agent_system_prompt)
---

## turn_manager.py

---python
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
---

## ui_panels.py

---python
import customtkinter as ctk

def setup_interaction_panel(gui, parent):
    """Set up the interaction panel"""
    # World Events log area (GM View - omniscient perspective)
    world_frame = ctk.CTkFrame(parent)
    world_frame.pack(fill="both", expand=True, padx=10, pady=10)
    
    world_label = ctk.CTkLabel(world_frame, text="World Events (GM View)", font=ctk.CTkFont(size=16, weight="bold"))
    world_label.pack(anchor="w", padx=10, pady=10)
    
    gui.prose_text = ctk.CTkTextbox(world_frame, wrap="word")
    gui.prose_text.pack(fill="both", expand=True, padx=10, pady=(0, 10))
    
    # Turn order display
    turn_frame = ctk.CTkFrame(parent)
    turn_frame.pack(fill="x", padx=10, pady=(0, 10))
    
    turn_label = ctk.CTkLabel(turn_frame, text="Turn Order:", font=ctk.CTkFont(size=14, weight="bold"))
    turn_label.pack(anchor="w", padx=10, pady=5)
    
    gui.turn_order_var = ctk.StringVar(value="Loading...")
    turn_order_label = ctk.CTkLabel(turn_frame, textvariable=gui.turn_order_var)
    turn_order_label.pack(anchor="w", padx=10, pady=5)
    
    # Turn Mode toggle
    turn_mode_frame = ctk.CTkFrame(turn_frame)
    turn_mode_frame.pack(fill="x", padx=10, pady=5)
    
    turn_mode_label = ctk.CTkLabel(turn_mode_frame, text="Turn Mode:")
    turn_mode_label.pack(side="left", padx=5, pady=5)
    
    # Initialize with current turn manager mode
    initial_mode = "Memory-Based" if gui.turn_manager.turn_mode == "memories" else "Time Units"
    gui.turn_mode_var = ctk.StringVar(value=initial_mode)
    
    # Create dropdown for turn mode selection
    turn_mode_menu = ctk.CTkOptionMenu(
        turn_mode_frame,
        values=["Time Units", "Memory-Based"],
        variable=gui.turn_mode_var,
        command=lambda value: gui.toggle_turn_mode()
    )
    turn_mode_menu.pack(side="left", padx=5, pady=5)
    
    # Auto-execute, Auto-pass, and God mode toggles
    toggle_frame = ctk.CTkFrame(turn_frame)
    toggle_frame.pack(fill="x", padx=10, pady=5)
    
    # Auto-execute toggle for miniminds
    gui.auto_execute_var = ctk.BooleanVar(value=False)
    auto_execute_check = ctk.CTkCheckBox(toggle_frame, text="Auto-Execute Minimind Turns", 
                                         variable=gui.auto_execute_var,
                                         onvalue=True, offvalue=False)
    auto_execute_check.pack(side="left", padx=10, pady=5)
    
    # Auto-pass toggle for player
    gui.auto_pass_var = ctk.BooleanVar(value=False)
    auto_pass_check = ctk.CTkCheckBox(toggle_frame, text="Auto-Pass Player Turn", 
                                     variable=gui.auto_pass_var,
                                     onvalue=True, offvalue=False)
    auto_pass_check.pack(side="left", padx=10, pady=5)
    
    # God mode toggle
    gui.god_mode_var = ctk.BooleanVar(value=False)
    god_mode_check = ctk.CTkCheckBox(toggle_frame, text="God Mode (0 TU cost)", 
                                    variable=gui.god_mode_var,
                                    onvalue=True, offvalue=False,
                                    command=lambda: gui.toggle_god_mode())
    god_mode_check.pack(side="left", padx=10, pady=5)
    
    # Player View area (like a MUD/MOO interface)
    player_frame = ctk.CTkFrame(parent)
    player_frame.pack(fill="both", expand=True, padx=10, pady=(0, 10))
    
    player_label = ctk.CTkLabel(player_frame, text="Player View", font=ctk.CTkFont(size=16, weight="bold"))
    player_label.pack(anchor="w", padx=10, pady=10)
    
    gui.log_text = ctk.CTkTextbox(player_frame, wrap="word", height=120)
    gui.log_text.pack(fill="both", expand=True, padx=10, pady=(0, 10))
    
    # Turn information and controls
    control_frame = ctk.CTkFrame(parent)
    control_frame.pack(fill="x", padx=10, pady=(0, 10))
    
    gui.status_var = ctk.StringVar(value="Ready")
    status_label = ctk.CTkLabel(control_frame, textvariable=gui.status_var)
    status_label.pack(side="left", padx=10, pady=10)
    
    gui.pass_btn = ctk.CTkButton(control_frame, text="Pass Turn", command=gui.pass_turn)
    gui.pass_btn.pack(side="right", padx=10, pady=10)
    
    gui.turn_btn = ctk.CTkButton(control_frame, text="Execute Next Turn", command=gui.execute_minimind_turn)
    gui.turn_btn.pack(side="right", padx=10, pady=10)
    
    # User command entry
    cmd_frame = ctk.CTkFrame(parent)
    cmd_frame.pack(fill="x", padx=10, pady=(0, 10))
    
    cmd_label = ctk.CTkLabel(cmd_frame, text="Your Action", font=ctk.CTkFont(size=16, weight="bold"))
    cmd_label.pack(anchor="w", padx=10, pady=10)
    
    gui.cmd_text = ctk.CTkTextbox(cmd_frame, wrap="word", height=60)
    gui.cmd_text.pack(fill="both", expand=True, padx=10, pady=(0, 10))
    
    gui.submit_btn = ctk.CTkButton(cmd_frame, text="Submit", command=gui.process_player_command)
    gui.submit_btn.pack(side="right", padx=10, pady=(0, 10))
    
    # Bind Enter key to submit
    gui.cmd_text.bind("<Control-Return>", lambda e: gui.process_player_command())

def setup_debug_panel(gui, parent):
    """Set up the debug panel using grid layout"""
    parent.grid_rowconfigure(0, weight=1)  # LLM Settings
    parent.grid_rowconfigure(1, weight=3)  # Prompt
    parent.grid_rowconfigure(2, weight=3)  # Response
    parent.grid_columnconfigure(0, weight=1)
    
    # LLM settings at the top
    llm_frame = ctk.CTkFrame(parent)
    llm_frame.grid(row=0, column=0, padx=10, pady=10, sticky="nsew")
    
    llm_label = ctk.CTkLabel(llm_frame, text="LLM Settings", font=ctk.CTkFont(size=16, weight="bold"))
    llm_label.pack(anchor="w", padx=10, pady=10)
    
    settings_frame = ctk.CTkFrame(llm_frame)
    settings_frame.pack(fill="x", padx=10, pady=(0, 10))
    
    # Model setting
    model_label = ctk.CTkLabel(settings_frame, text="Model:")
    model_label.grid(row=0, column=0, padx=5, pady=5, sticky="w")
    
    gui.model_var = ctk.StringVar(value=gui.llm.model)
    model_entry = ctk.CTkEntry(settings_frame, textvariable=gui.model_var, width=200)
    model_entry.grid(row=0, column=1, padx=5, pady=5, sticky="w")
    
    # Temperature setting
    temp_label = ctk.CTkLabel(settings_frame, text="Temperature:")
    temp_label.grid(row=1, column=0, padx=5, pady=5, sticky="w")
    
    gui.temp_var = ctk.DoubleVar(value=gui.llm.temperature)
    temp_entry = ctk.CTkEntry(settings_frame, textvariable=gui.temp_var, width=80)
    temp_entry.grid(row=1, column=1, padx=5, pady=5, sticky="w")
    
    # Context tokens setting
    context_label = ctk.CTkLabel(settings_frame, text="Context Tokens:")
    context_label.grid(row=2, column=0, padx=5, pady=5, sticky="w")
    
    gui.context_var = ctk.IntVar(value=gui.llm.context_tokens)
    context_entry = ctk.CTkEntry(settings_frame, textvariable=gui.context_var, width=80)
    context_entry.grid(row=2, column=1, padx=5, pady=5, sticky="w")
    
    # Add memory count setting
    memories_label = ctk.CTkLabel(settings_frame, text="Memories Count:")
    memories_label.grid(row=3, column=0, padx=5, pady=5, sticky="w")
    
    gui.memories_var = ctk.IntVar(value=gui.memories_count)
    memories_entry = ctk.CTkEntry(settings_frame, textvariable=gui.memories_var, width=80)
    memories_entry.grid(row=3, column=1, padx=5, pady=5, sticky="w")
    
    # Add notes count setting
    notes_label = ctk.CTkLabel(settings_frame, text="Notes Count:")
    notes_label.grid(row=4, column=0, padx=5, pady=5, sticky="w")
    
    gui.notes_var = ctk.IntVar(value=gui.notes_count)
    notes_entry = ctk.CTkEntry(settings_frame, textvariable=gui.notes_var, width=80)
    notes_entry.grid(row=4, column=1, padx=5, pady=5, sticky="w")
    
    # LLM prompt debug
    prompt_frame = ctk.CTkFrame(parent)
    prompt_frame.grid(row=1, column=0, padx=10, pady=10, sticky="nsew")
    
    prompt_label = ctk.CTkLabel(prompt_frame, text="LLM Prompt", font=ctk.CTkFont(size=16, weight="bold"))
    prompt_label.pack(anchor="w", padx=10, pady=10)
    
    gui.prompt_text = ctk.CTkTextbox(prompt_frame, wrap="word")
    gui.prompt_text.pack(fill="both", expand=True, padx=10, pady=(0, 10))
    
    # LLM response debug
    response_frame = ctk.CTkFrame(parent)
    response_frame.grid(row=2, column=0, padx=10, pady=10, sticky="nsew")
    
    response_label = ctk.CTkLabel(response_frame, text="LLM Response (Streaming)", font=ctk.CTkFont(size=16, weight="bold"))
    response_label.pack(anchor="w", padx=10, pady=10)
    
    gui.response_text = ctk.CTkTextbox(response_frame, wrap="word")
    gui.response_text.pack(fill="both", expand=True, padx=10, pady=(0, 10))

def setup_minimind_panel(gui, parent):
    """Set up the minimind management panel"""
    # Minimind frame with title
    minds_frame = ctk.CTkFrame(parent)
    minds_frame.pack(fill="both", expand=True, padx=10, pady=10)
    
    minds_label = ctk.CTkLabel(minds_frame, text="Miniminds", font=ctk.CTkFont(size=16, weight="bold"))
    minds_label.pack(anchor="w", padx=10, pady=10)
    
    # Minimind controls
    controls_frame = ctk.CTkFrame(minds_frame)
    controls_frame.pack(fill="x", padx=10, pady=(0, 10))
    
    btn_create = ctk.CTkButton(controls_frame, text="Create New", command=gui.create_minimind)
    btn_create.grid(row=0, column=0, padx=5, pady=5)
    
    btn_edit = ctk.CTkButton(controls_frame, text="Edit Selected", command=gui.edit_minimind)
    btn_edit.grid(row=0, column=1, padx=5, pady=5)
    
    btn_memories = ctk.CTkButton(controls_frame, text="View Memories", command=gui.view_memories)
    btn_memories.grid(row=1, column=0, padx=5, pady=5)
    
    btn_notes = ctk.CTkButton(controls_frame, text="View Notes", command=gui.view_notes)
    btn_notes.grid(row=1, column=1, padx=5, pady=5)
    
    # Add reload button - new button for reloading all miniminds
    btn_reload = ctk.CTkButton(
        controls_frame, 
        text="Reload All", 
        command=gui.reload_all_miniminds,
        fg_color=("green", "dark green"),  # Make it stand out with a different color
        hover_color=("dark green", "green")
    )
    btn_reload.grid(row=2, column=0, columnspan=2, padx=5, pady=5, sticky="ew")  # Span both columns
    
    # Minimind list - using scrollable frame with list of button items
    list_container = ctk.CTkFrame(minds_frame)
    list_container.pack(fill="both", expand=True, padx=10, pady=10)
    
    # Create a custom listbox using a scrollable frame with buttons
    gui.mind_list_frame = ctk.CTkScrollableFrame(list_container)
    gui.mind_list_frame.pack(fill="both", expand=True)
    
    # Create the list class to simulate a listbox
    class CustomListbox:
        def __init__(self, frame, command=None):
            self.frame = frame
            self.items = []
            self.buttons = []
            self.selected_index = None
            self.command = command
        
        def insert(self, position, item):
            if position == "end":
                self.items.append(item)
                position = len(self.items) - 1
            else:
                self.items.insert(position, item)
            
            # Create button for this item
            btn = ctk.CTkButton(
                self.frame, 
                text=item,
                command=lambda i=position: self._select_item(i),
                fg_color="transparent", 
                anchor="w",
                height=30,
                hover_color=("gray75", "gray28")
            )
            self.buttons.append(btn)
            btn.pack(fill="x", pady=2)
        
        def _select_item(self, index):
            # Deselect previous
            if self.selected_index is not None and self.selected_index < len(self.buttons):
                self.buttons[self.selected_index].configure(fg_color="transparent")
            
            # Select new
            self.selected_index = index
            self.buttons[index].configure(fg_color=("gray70", "gray35"))
            
            # Call command if provided
            if self.command:
                self.command(self.items[index])
        
        def get(self, index=None):
            if index is None:
                # Return selected item
                if self.selected_index is not None:
                    return self.items[self.selected_index]
                return None
            else:
                # Return item at index
                return self.items[index]
        
        def select(self, indices):
            if indices and len(indices) > 0:
                self._select_item(indices[0])
        
        def selection_clear(self, start, end):
            # Deselect current selection
            if self.selected_index is not None and self.selected_index < len(self.buttons):
                self.buttons[self.selected_index].configure(fg_color="transparent")
                self.selected_index = None
        
        def curselection(self):
            if self.selected_index is not None:
                return [self.selected_index]
            return []
    
    # Create the custom listbox
    gui.mind_list = CustomListbox(gui.mind_list_frame, command=gui.on_select_minimind)---

## utils.py

---python
import os
import re
from datetime import datetime

def ensure_directory(path):
    """Ensure a directory exists"""
    os.makedirs(path, exist_ok=True)

def create_safe_filename(title):
    """Create a safe filename from a title"""
    # Remove non-alphanumeric characters except spaces and hyphens
    safe_title = re.sub(r'[^\w\s-]', '', title).strip()
    # Replace spaces with hyphens
    safe_title = safe_title.replace(' ', '-').lower()
    # Add timestamp
    timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    return f"{timestamp}-{safe_title}.md"

def parse_structured_memory(memory_text):
    """Parse a structured memory to extract components"""
    # Extract the memory ID and structured parts
    memory_pattern = r"🧠([\w\d]+):{(.*?)}"
    match = re.search(memory_pattern, memory_text)
    
    if not match:
        return None
        
    memory_id = match.group(1)
    structure = match.group(2)
    
    # Parse the structure
    result = {"id": memory_id}
    
    # Extract individual components
    components = {
        "who": r"👥(.*?)(?=,|$)",
        "what": r"💡(.*?)(?=,|$)",
        "where": r"📍(.*?)(?=,|$)",
        "when": r"📅(.*?)(?=,|$)",
        "why": r"❓(.*?)(?=,|$)",
        "how": r"🔧(.*?)(?=,|$)",
        "summary": r"📰(.*?)(?=,|$)"
    }
    
    for key, pattern in components.items():
        match = re.search(pattern, structure)
        if match:
            result[key] = match.group(1)
        else:
            result[key] = ""
    
    return result

def format_timestamp(timestamp_str):
    """Format a timestamp string into a human-readable format"""
    try:
        # Parse YYYYMMDD-HHMMSS format
        dt = datetime.strptime(timestamp_str, '%Y%m%d-%H%M%S')
        return dt.strftime('%B %d, %Y at %I:%M %p')
    except:
        return timestamp_str---

## vector_store.py

---python
import os
import json
import numpy as np
from datetime import datetime

class NoteVectorStore:
    """A simple vector store for Minimind notes"""
    
    def __init__(self, minimind_name):
        """Initialize the vector store for a specific minimind"""
        self.minimind_name = minimind_name
        self.minimind_path = os.path.join("miniminds", minimind_name)
        self.vector_db_path = os.path.join(self.minimind_path, "note_vectors.json")
        self.vectors = self._load_vectors()
        
    def _load_vectors(self):
        """Load vectors from the store file"""
        if os.path.exists(self.vector_db_path):
            try:
                with open(self.vector_db_path, 'r') as f:
                    return json.load(f)
            except:
                return {}
        return {}
    
    def _save_vectors(self):
        """Save vectors to the store file"""
        os.makedirs(os.path.dirname(self.vector_db_path), exist_ok=True)
        with open(self.vector_db_path, 'w') as f:
            json.dump(self.vectors, f, indent=2)
            
    def add_vector(self, note_id, title_vector, content_vector, combined_vector, metadata=None):
        """Add a vector to the store"""
        if metadata is None:
            metadata = {}
            
        # Add timestamp
        metadata["timestamp"] = datetime.now().isoformat()
        
        self.vectors[note_id] = {
            "title_vector": title_vector,
            "content_vector": content_vector,
            "combined_vector": combined_vector,
            "metadata": metadata
        }
        self._save_vectors()
        
    def update_vector(self, note_id, title_vector, content_vector, combined_vector, metadata=None):
        """Update a vector in the store"""
        if note_id not in self.vectors:
            self.add_vector(note_id, title_vector, content_vector, combined_vector, metadata)
            return
            
        if metadata:
            # Update metadata, preserving existing metadata
            self.vectors[note_id]["metadata"].update(metadata)
        
        # Update vectors
        self.vectors[note_id]["title_vector"] = title_vector
        self.vectors[note_id]["content_vector"] = content_vector
        self.vectors[note_id]["combined_vector"] = combined_vector
        
        # Update timestamp
        self.vectors[note_id]["metadata"]["updated_at"] = datetime.now().isoformat()
        
        self._save_vectors()
        
    def remove_vector(self, note_id):
        """Remove a vector from the store"""
        if note_id in self.vectors:
            del self.vectors[note_id]
            self._save_vectors()
            

    def get_similar_notes(self, query_vector, vector_type="combined", top_n=5, min_similarity=0.0):
        """Get the top N similar notes by cosine similarity
        
        Args:
            query_vector: The query vector to compare against
            vector_type: Which vector to use (title_vector, content_vector, or combined_vector)
            top_n: Number of notes to return
            min_similarity: Minimum similarity threshold (default 0.0 - no threshold)
        
        Returns:
            List of tuples [(note_id, similarity_score), ...]
        """
        if not self.vectors:
            return []
            
        # Calculate similarities
        results = []
        for note_id, data in self.vectors.items():
            if vector_type in data:
                note_vector = data[vector_type]
                similarity = self._cosine_similarity(query_vector, note_vector)
                
                # Only include results above minimum similarity if specified
                if similarity >= min_similarity:
                    results.append((note_id, similarity))
        
        # Sort by similarity (highest first)
        results.sort(key=lambda x: x[1], reverse=True)
        
        # Return top N results
        return results[:top_n]
    
    def _cosine_similarity(self, vec_a, vec_b):
        """Calculate cosine similarity between two vectors"""
        vec_a = np.array(vec_a)
        vec_b = np.array(vec_b)
        
        dot_product = np.dot(vec_a, vec_b)
        norm_a = np.linalg.norm(vec_a)
        norm_b = np.linalg.norm(vec_b)
        
        if norm_a == 0 or norm_b == 0:
            return 0
            
        return dot_product / (norm_a * norm_b)
---

## world.py

---python
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
            
            with open(file_path, "r") as f:
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
        
        # Write the file
        with open(state_file, "w") as f:
            f.write(content)

    def load_world_state(self):
        """Load world state from the markdown file if it exists"""
        world_dir = "world"
        state_file = os.path.join(world_dir, "world_state.md")
        
        if not os.path.exists(state_file):
            return False
        
        try:
            with open(state_file, "r") as f:
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
        if location not in self.locations:
            return
        
        if data is None:
            data = {}
        
        # Always include location in data
        if "location" not in data:
            data["location"] = location
        
        # Use the event bus to publish the event
        from core.event_bus import EventBus
        event_bus = EventBus.get_instance()
        event_bus.publish(event_type, description, data)
        
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
        
        # Stage 3: Check for just quoted text as a shorthand for SAY
        # Example: "Hello!" -> interpreted as "say Hello!"
        if (command.startswith('"') and command.endswith('"') and 
            len(command.strip()) > 2 and  # Ensure it's not just empty quotes
            ' ' not in command.strip('"\' ')):  # No spaces outside quotes
            command = f"say {command.strip('\"')}"
        
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
            return self.handle_look_command(actor, original_reason)
        elif command_lower.startswith("go to "):
            destination = command[6:].strip()
            return self.handle_go_command(actor, destination, original_reason)
        elif command_lower.startswith("fly to "):
            destination = command[7:].strip()
            return self.handle_fly_command(actor, destination, original_reason)
        elif command_lower.startswith("say "):
            message = command[4:].strip()
            return self.handle_say_command(actor, message, original_reason)
        elif command_lower.startswith("emote "):
            action = command[6:].strip()
            return self.handle_emote_command(actor, action, original_reason)
        elif command_lower.startswith("shout "):
            message = command[6:].strip()
            return self.handle_shout_command(actor, message, original_reason)
        elif command_lower.startswith("examine "):
            target = command[8:].strip()
            return self.handle_examine_command(actor, target, original_reason)
        elif command_lower.startswith("dig "):
            location_name = command[4:].strip()
            return self.handle_dig_command(actor, location_name, original_reason)
        elif command_lower.startswith("describe "):
            description = command[9:].strip()
            return self.handle_describe_command(actor, description, original_reason)
        elif command_lower.startswith("note "):
            # This is a special command for miniminds to create notes
            # The world doesn't handle this directly
            return {"success": True, "message": f"{actor} makes a mental note."}
        elif command_lower.startswith("dream"):
            return self.handle_dream_command(actor, original_reason)
        else:
            # Invalid command format
            return {"success": False, "message": f"⚠ Could not parse: {command}\n- Did you use the command correctly?"}
    
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
                prose += f"\n👥{other_chars[0]} is here."
            else:
                char_list = ", ".join(other_chars[:-1]) + " and " + other_chars[-1]
                prose += f"\n👥{char_list} are here."
        else:
            prose += "\n👥You are alone here."
        
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
                "original_reason": original_reason or "Unkown"  # Include original reason
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
            return {"success": False, "message": f"You can't go to '{destination}' from here."}
        
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
        movement_msg = f"{actor} goes to {destination_key} from {current_location}."
        
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
        # Implementation remains the same as in original world.py
        location = self.get_character_location(actor)
        if not location:
            return {"success": False, "message": "You are nowhere."}
        
        # Create the say message format for others
        say_msg = f"{actor} says: \"{message}\""
        
        # Create the say message format for self
        self_msg = f"You say: \"{message}\""
        
        # Notify all characters in the location
        self.notify_location(location, "speech", say_msg, {
            "actor": actor,
            "message": message,
            "location": location,  # Explicitly include location in data
            "original_reason": original_reason  # Include the original reason
        })
        
        return {
            "success": True,
            "message": self_msg,  # Return special format for the speaker
            "data": {
                "location": location,
                "message": message,
                "original_reason": original_reason  # Pass the reason in the result data
            }
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
---

