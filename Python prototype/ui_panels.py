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
    gui.mind_list = CustomListbox(gui.mind_list_frame, command=gui.on_select_minimind)