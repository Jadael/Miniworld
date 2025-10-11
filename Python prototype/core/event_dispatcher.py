# core/event_dispatcher.py
from datetime import datetime
import re

class EventDispatcher:
    """A simpler, more direct approach to event handling"""
    _instance = None
    
    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
        
    def __init__(self):
        # Track observers by name
        self.observers = {}
        # Track recent events by fingerprint
        self.recent_events = {}
        
    def register(self, character_name, callback):
        """Register a callback for a character"""
        self.observers[character_name] = callback
        
    def unregister(self, character_name):
        """Unregister a character"""
        if character_name in self.observers:
            del self.observers[character_name]
            
    def dispatch_event(self, event_type, event_data):
        """Dispatch an event to relevant observers"""
        # Basic required event data
        actor = event_data.get('actor', 'unknown')
        location = event_data.get('location', 'unknown')
        message = event_data.get('message', '')
        description = event_data.get('description', '')
        origin = event_data.get('origin')
        destination = event_data.get('destination')
        
        # Special handling for error messages (only show to actor)
        is_error = "⚠" in description or "Failed:" in description
        
        # Create a base observer list - which characters should be notified
        observers_to_notify = []
        
        # Error messages only notify the actor
        if is_error:
            if actor in self.observers:
                observers_to_notify = [actor]
        # Handle other event types
        elif event_type == "shout":
            # Everyone hears shouts
            observers_to_notify = list(self.observers.keys())
        elif event_type == "movement":
            # Movement is observed at both origin and destination
            for character in self.observers:
                char_location = event_data.get('observer_locations', {}).get(character)
                if char_location in (origin, destination):
                    observers_to_notify.append(character)
        else:
            # Standard events only notify characters at the same location 
            for character in self.observers:
                char_location = event_data.get('observer_locations', {}).get(character)
                if char_location == location:
                    observers_to_notify.append(character)
        
        # Process relevant observers
        for observer in observers_to_notify:
            # Skip the actor seeing their own event in most cases
            if observer == actor and event_type in ('speech', 'shout', 'emote'):
                continue
                
            # Format the event for this specific observer
            observer_message = self._format_for_observer(event_type, event_data, observer)
            
            # Skip empty messages
            if not observer_message:
                continue
                
            # Add observer to data
            observer_data = event_data.copy()
            observer_data['observer'] = observer
            
            # Call the observer's callback
            if observer in self.observers:
                self.observers[observer](event_type, observer_message, observer_data)
    
    def _format_for_observer(self, event_type, event_data, observer):
        """Format an event message for a specific observer"""
        actor = event_data.get('actor', 'unknown')
        message = event_data.get('message', '')
        
        # Skip error messages for other agents
        if "⚠" in message and observer != actor:
            return ""
        
        # Skip "You say" messages not meant for this observer
        if "You say:" in message and observer != actor:
            return ""
        
        # Format based on event type
        if event_type == "speech":
            # Speech events
            if observer == actor:
                # Actor doesn't need to see their own speech
                return ""
            else:
                return f"{actor} says: \"{message}\""
                
        elif event_type == "shout":
            # Shout events
            if observer == actor:
                # Actor doesn't need to see their own shout
                return ""
            else:
                location = event_data.get('location', 'somewhere')
                return f"{actor} shouts from {location}: \"{message}\""
                
        elif event_type == "emote":
            # Emote events
            if observer == actor:
                # Actor doesn't need to see their own emote
                return ""
            else:
                action = event_data.get('action', '')
                return f"{actor} {action}"
                
        elif event_type == "movement":
            # Movement events - format based on observer's location
            origin = event_data.get('origin', 'somewhere')
            destination = event_data.get('destination', 'somewhere')
            via = event_data.get('via', 'moved')
            
            # Get observer's location
            observer_location = event_data.get('observer_locations', {}).get(observer)
            
            if observer == actor:
                # Actor doesn't need to see their own movement
                return ""
            elif observer_location == origin:
                return f"{actor} {via} to {destination}."
            elif observer_location == destination:
                return f"{actor} {via} from {origin}."
                
        elif event_type == "observation":
            # Observation events
            if observer == actor:
                # Actor doesn't need to see their own observations
                return ""
            else:
                action = event_data.get('action', '')
                return f"{actor} {action}"
                
        elif event_type == "command":
            # Only show command confirmations to the actor
            if observer != actor:
                return ""
            return event_data.get('description', '')
        
        # For other event types, use the event's description
        description = event_data.get('description', '')
        
        # Filter out any "You say:" that doesn't belong to this observer
        if "You say:" in description and observer != actor:
            return ""
        
        return description