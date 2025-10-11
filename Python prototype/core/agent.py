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
