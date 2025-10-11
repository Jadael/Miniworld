# core/event_bus.py
import hashlib
from datetime import datetime
from collections import defaultdict
import threading
import re

class EventBus:
    _instance = None
    _lock = threading.Lock()

    @classmethod
    def get_instance(cls):
        """Get the singleton instance of the EventBus"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = cls()
        return cls._instance

    def __init__(self):
        # Observer registry: {character_name: [callback_functions]}
        self.observers = defaultdict(list)
        
        # Recent events for deduplication: {fingerprint: timestamp}
        self.recent_events = {}
        
        # Observer-specific recent events: {observer: [(fingerprint, timestamp)]}
        self.observer_recent_events = defaultdict(list)
        
        # Event expiry time in seconds
        self.event_expiry = 3

    def register(self, character_name, callback):
        """Register a callback for a character to receive events"""
        if callback not in self.observers[character_name]:
            self.observers[character_name].append(callback)

    def unregister(self, character_name, callback=None):
        """Unregister a callback for a character"""
        if callback is None:
            # Remove all callbacks for this character
            if character_name in self.observers:
                del self.observers[character_name]
        else:
            # Remove specific callback
            if character_name in self.observers and callback in self.observers[character_name]:
                self.observers[character_name].remove(callback)

    def create_fingerprint(self, event_type, description, data):
        """Create a unique fingerprint for an event to help with deduplication"""
        # Strip any nested event type prefixes
        clean_description = re.sub(r'^\[[^\]]+\](\s+in\s+[^:]+):\s+', '', description)
        
        # Extract key components for fingerprinting
        actor = data.get('actor', 'unknown')
        location = data.get('location', 'unknown')
        
        # Use coarse time (to the second) for fingerprinting
        timestamp = datetime.now().strftime("%H:%M:%S")
        
        # Create fingerprint string
        fingerprint_str = f"{event_type}:{actor}:{clean_description}:{location}:{timestamp}"
        
        # Hash to create a compact fingerprint
        return hashlib.md5(fingerprint_str.encode()).hexdigest()

    def is_recent_duplicate(self, fingerprint):
        """Check if this event has been seen recently"""
        if fingerprint in self.recent_events:
            # Check if the event is still within expiry window
            time_diff = (datetime.now() - self.recent_events[fingerprint]).total_seconds()
            return time_diff < self.event_expiry
        return False

    def observer_has_seen_event(self, observer, fingerprint):
        """Check if a specific observer has seen this event recently"""
        now = datetime.now()
        # Clean up expired events for this observer
        self.observer_recent_events[observer] = [
            (fp, ts) for fp, ts in self.observer_recent_events[observer]
            if (now - ts).total_seconds() < self.event_expiry
        ]
        
        # Check if observer has seen this event
        for fp, _ in self.observer_recent_events[observer]:
            if fp == fingerprint:
                return True
        return False

    def record_observer_event(self, observer, fingerprint):
        """Record that an observer has seen an event"""
        self.observer_recent_events[observer].append((fingerprint, datetime.now()))

    def cleanup_old_events(self):
        """Clean up expired events"""
        now = datetime.now()
        # Remove expired events
        expired_keys = [
            key for key, timestamp in self.recent_events.items()
            if (now - timestamp).total_seconds() >= self.event_expiry
        ]
        for key in expired_keys:
            del self.recent_events[key]

    def publish(self, event_type, description, data=None):
        """Publish an event to relevant observers"""
        if data is None:
            data = {}
        
        # Clean up description - remove nested event formatting
        if description.startswith(f"[{event_type}]") or "[" in description and "in" in description and ":" in description:
            # Extract the actual description without prefixes
            description = re.sub(r'^\[[^\]]+\](\s+in\s+[^:]+):\s+', '', description)
        
        # For movement events, make sure both locations get properly formatted descriptions
        if event_type == "movement":
            actor = data.get('actor', 'Someone')
            origin = data.get('origin')
            destination = data.get('destination')
            via = data.get('via', 'moved')
            
            # Create specific descriptions for origin and destination viewers
            origin_desc = f"{actor} {via} to {destination}."
            dest_desc = f"{actor} {via} from {origin}."
            
            # Store these in the data for location-specific formatting
            data['origin_description'] = origin_desc
            data['destination_description'] = dest_desc
        
        # Create event fingerprint
        fingerprint = self.create_fingerprint(event_type, description, data)
        
        # Check for global duplication (stop if this event was already processed)
        if self.is_recent_duplicate(fingerprint):
            return  # Skip duplicate events
            
        # Record this event globally
        self.recent_events[fingerprint] = datetime.now()
        
        # Clean up old events periodically
        self.cleanup_old_events()
        
        # Determine which observers should receive this event
        event_location = data.get('location')
        observer_locations = data.get('observer_locations', {})
        observers_to_notify = []

        # Determine notification strategy based on event type
        if event_type == "shout":
            # Shouts are heard by everyone
            observers_to_notify = list(self.observers.keys())
        elif event_type == "movement":
            # Movements are observed in both origin and destination locations
            origin = data.get('origin')
            destination = data.get('destination')
            if origin and destination:
                for observer in self.observers:
                    observer_location = observer_locations.get(observer)
                    if observer_location in (origin, destination):
                        observers_to_notify.append(observer)
        else:
            # Standard events are observed only in the same location
            for observer in self.observers:
                observer_location = observer_locations.get(observer)
                if observer_location == event_location:
                    observers_to_notify.append(observer)
        
        # Notify relevant observers
        for observer in observers_to_notify:
            # Skip if this observer has already seen this event
            if self.observer_has_seen_event(observer, fingerprint):
                continue
                
            # Record that this observer is seeing this event
            self.record_observer_event(observer, fingerprint)
            
            # Format the event based on observer's perspective and location
            if event_type == "movement":
                # Choose the right perspective based on observer's location
                observer_location = observer_locations.get(observer)
                origin = data.get('origin')
                
                if observer_location == origin:
                    # Observer is at origin - use origin description
                    formatted_description = data.get('origin_description', description)
                else:
                    # Observer is at destination - use destination description
                    formatted_description = data.get('destination_description', description) 
            else:
                # For non-movement events, just format based on perspective
                formatted_description = self.format_for_observer(observer, description, data)
                
            # Prepare data for this observer
            formatted_data = self.prepare_data_for_observer(observer, data)
            
            # Notify the observer via all registered callbacks
            for callback in self.observers[observer]:
                callback(event_type, formatted_description, formatted_data)

    def format_for_observer(self, observer, description, data):
        """Format a description based on observer's perspective"""
        actor = data.get('actor', 'unknown')
        
        # Replace "You" and conjugate verbs based on perspective
        if observer == actor:
            # First-person perspective
            description = description.replace(f"{actor} ", "You ")
            
            # Basic conjugation for common verbs
            description = description.replace(" says:", " say:")
            description = description.replace(" says", " say")
            description = description.replace(" goes ", " go ")
            description = description.replace(" looks ", " look ")
            description = description.replace(" examines ", " examine ")
        
        return description

    def prepare_data_for_observer(self, observer, data):
        """Prepare event data specific to an observer"""
        # Create a copy to avoid modifying the original
        observer_data = data.copy()
        
        # Add observer-specific metadata
        observer_data['is_actor'] = (observer == data.get('actor', 'unknown'))
        observer_data['observer'] = observer  # Add observer name for filtering
        
        return observer_data