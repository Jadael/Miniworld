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
        
        # Load templates from personal folder first, then from vault
        self.prompt_template = self._load_template("prompt_template")
        self.memory_format = self._load_template("memory_format")
        self.note_format = self._load_template("note_format")
        self.agent_system_prompt = self._load_template("agent_system_prompt")

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
        os.makedirs(os.path.join(self.path, "templates"), exist_ok=True)  # Add templates directory

    def _load_profile(self):
        """Load the character's profile"""
        profile_path = os.path.join(self.path, "profile.md")
        if os.path.exists(profile_path):
            with open(profile_path, "r", encoding="utf-8") as f:
                return f.read()
        return ""

    def _load_template(self, template_name):
        """Load a template, checking personal folder first, then fall back to vault"""
        # Look for template in personal folder
        personal_template_path = os.path.join(self.path, "templates", f"{template_name}.md")
        
        # Create templates directory if it doesn't exist
        os.makedirs(os.path.join(self.path, "templates"), exist_ok=True)
        
        # Check if personal template exists
        if os.path.exists(personal_template_path):
            try:
                with open(personal_template_path, "r", encoding="utf-8") as f:
                    print(f"Using personal template for {self.name}: {template_name}")
                    return f.read()
            except Exception as e:
                print(f"Error loading personal template for {self.name}: {str(e)}")
        
        # Fall back to global template from MarkdownVault
        return MarkdownVault.load_template(template_name)

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
            try:
                with open(os.path.join(memories_path, mem_file), "r", encoding="utf-8") as f:
                    memories.append(f.read())
            except Exception as e:
                print(f"Error reading memory file {mem_file}: {str(e)}")
        
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
            try:
                with open(os.path.join(notes_path, note_file), "r", encoding="utf-8") as f:
                    notes.append(f.read())
            except Exception as e:
                print(f"Error reading note file {note_file}: {str(e)}")
        
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
                try:
                    with open(file_path, 'r', encoding="utf-8") as f:
                        first_line = f.readline().strip()
                        if first_line == f"# {title}":
                            existing_file = filename
                            break
                except Exception as e:
                    print(f"Error checking note file {filename}: {str(e)}")
                    continue
        
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
        try:
            file_path = os.path.join(notes_dir, final_filename)
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(note_content)
        except Exception as e:
            print(f"Error writing note file {final_filename}: {str(e)}")
            return None
        
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
                    try:
                        with open(file_path, 'r', encoding="utf-8") as f:
                            content = f.read()
                            lines = content.split('\n')
                            first_line = lines[0].strip()
                            title = first_line[2:] if first_line.startswith("# ") else first_line
                            
                            if title.lower() == query.lower():
                                exact_match_results.append((os.path.splitext(filename)[0], 1.0, content))
                    except Exception as e:
                        print(f"Error reading note for exact match: {str(e)}")
                        continue
            
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
                                try:
                                    with open(file_path, 'r', encoding="utf-8") as f:
                                        content = f.read()
                                        similar_notes.append((note_id, similarity, content))
                                except Exception as e:
                                    print(f"Error reading note for vector match: {str(e)}")
                                    continue
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
                        try:
                            with open(file_path, 'r', encoding="utf-8") as f:
                                content = f.read()
                                random_notes.append((note_id, 0.0, content))
                        except Exception as e:
                            print(f"Error reading random note: {str(e)}")
                            continue
                
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
        
        try:
            with open(memory_path, "w", encoding="utf-8") as f:
                f.write(memory_content)
        except Exception as e:
            print(f"Error writing memory file {filename}: {str(e)}")

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
        
        try:
            with open(memory_path, "w", encoding="utf-8") as f:
                f.write(memory_content)
        except Exception as e:
            print(f"Error writing response memory: {str(e)}")

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
                    
                # Read the note - FIX: Add explicit UTF-8 encoding
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
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
                except UnicodeDecodeError as e:
                    print(f"Unicode error reading {filename}: {str(e)}")
                    
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
        """Save details of a turn to a file for analysis"""
        # Create a turns directory if it doesn't exist
        turns_dir = os.path.join(self.path, "turns")
        os.makedirs(turns_dir, exist_ok=True)
        
        # Create a timestamped filename
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        filename = f"{timestamp}-turn.md"
        filepath = os.path.join(turns_dir, filename)
        
        # Format the content
        content = f"""# Turn Details for {self.name} at {timestamp}\n\n## Prompt\n{prompt or "None provided"}\n\n## Response\n{llm_response or "None provided"}\n\n## Parsed Command\n{parsed_command or "None provided"}\n\n## Result\n{command_result or "None provided"}"""
        
        # Write to file
        try:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(content)
        except Exception as e:
            print(f"Error saving turn details: {str(e)}")
            return None
        
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
                chars_text = f"{other_characters[0]} is here, and they will hear what you SAY or SHOUT and see what you EMOTE."
            else:
                char_list = ", ".join(other_characters[:-1]) + " and " + other_characters[-1]
                chars_text = f"{char_list} are here, and they will hear what you SAY or SHOUT and see what you EMOTE."
        else:
            chars_text = "You are alone here, no one will hear what you SAY or see what you EMOTE, but someone may hear you SHOUT."
        
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
