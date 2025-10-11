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
    def __init__(self, name="T", llm_interface=None):
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
    
    def get_memories(self, max_count=10):
        """Get the player's recent memories"""
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
                print(f"Error reading player memory file {mem_file}: {str(e)}")
        
        return memories
    
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
                    print(f"Error checking player note file {filename}: {str(e)}")
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
        
        # Prepare data for note template
        note_data = {
            "title": title,
            "title_lower": title.lower(),
            "characters": self.name,  # Just the player for now
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
            print(f"Error writing player note file {final_filename}: {str(e)}")
            return None
        
        return final_filename
    
    def add_memory(self, memory_type, content, reason=None):
        """Add a memory to the player's memory store"""
        self._add_memory(memory_type, content, reason)
    
    def _add_memory(self, memory_type, content, reason=None):
        """Add a memory to the player's memory store"""
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        memory_id = str(uuid.uuid4())[:8]  # Create a short unique ID
        filename = f"{timestamp}-{memory_type}.md"
        
        memories_dir = os.path.join(self.path, "memories")
        os.makedirs(memories_dir, exist_ok=True)
        memory_path = os.path.join(memories_dir, filename)
        
        # Get current time for the memory
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Set the why component to reason or default
        why = reason or "Unknown motivation"
        
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
        elif memory_type == "response":
            memory_data.update({
                "who": self.name,
                "what": content,
                "where": self.location or "unknown",
                "when": current_time,
                "how": "Received response",
                "why": reason or "Unknown"
            })
        
        # Fill the memory template
        memory_content = MarkdownVault.fill_template(self.memory_format, memory_data)
        
        try:
            with open(memory_path, "w", encoding="utf-8") as f:
                f.write(memory_content)
        except Exception as e:
            print(f"Error writing player memory file {filename}: {str(e)}")
    
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
        
        return filepath