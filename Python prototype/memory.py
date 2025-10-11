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
        with open(os.path.join(self.memories_path, mem_file), "r", encoding="utf-8") as f:
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
                with open(os.path.join(self.notes_path, note_file), "r", encoding="utf-8") as f:
                    first_line = f.readline().strip()
                    if first_line.startswith("# "):
                        title = first_line[2:]
            except Exception as e:
                print(f"Error reading note title: {str(e)}")
                continue
                    
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
        with open(os.path.join(self.notes_path, self.selected_note), "w", encoding="utf-8") as f:
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
        with open(os.path.join(self.notes_path, note_file), "r", encoding="utf-8") as f:
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
