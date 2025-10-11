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

def clean_event_text(text, actor=None, observer=None):
    """Clean event text by removing prefixes and fixing perspective issues"""
    clean_text = text
    
    # Remove event type prefixes if present
    clean_text = re.sub(r'^\[[^\]]+\](\s+in\s+[^:]+):\s+', '', clean_text)
    
    # Fix duplicate actor prefixes
    if actor and clean_text.startswith(f"{actor} {actor}"):
        clean_text = clean_text.replace(f"{actor} {actor}", actor)
    
    # Fix perspective for observations
    if observer and observer == actor:
        if "Someone LOOK" in clean_text:
            clean_text = clean_text.replace("Someone LOOK", "You LOOK")
        if "Someone see" in clean_text:
            clean_text = clean_text.replace("Someone see", "You see")
    
    # Fix "Someone says" with the proper actor
    if actor and "Someone says:" in clean_text:
        clean_text = clean_text.replace("Someone says:", f"{actor} says:")
    
    return clean_text

def add_world_event(gui, text, structured_data=None):
    """Add text to the World Events log (GM view - shows everything happening in the world)"""
    # Always add to the GM view regardless of filtering
    timestamp = datetime.now().strftime("%H:%M:%S")
    
    # Format error messages differently
    if "Failed:" in text or "⚠" in text or (structured_data and structured_data.get('is_error')):
        gui.prose_text.insert("end", f"[{timestamp}] [ERROR] {text}\n", "error")
    else:
        # Normal event formatting
        event_type = structured_data.get('type', 'event') if structured_data else 'info'
        location = structured_data.get('location', 'unknown') if structured_data else 'unknown'
        gui.prose_text.insert("end", f"[{timestamp}] [{event_type}] in {location}: {text}\n")
    
    gui.prose_text.see("end")

def should_show_to_player(gui, event_data):
    """Determine if an event should be shown to the player"""
    # Get player's location
    player_location = gui.world.get_character_location(gui.player_name)
    event_location = event_data.get('location')
    actor = event_data.get('actor')
    event_type = event_data.get('type')
    
    # Check for duplicates using content
    message = event_data.get('message', '')
    description = event_data.get('description', '')
    
    # Skip events where the player is seeing a duplicate perspective
    if actor != gui.player_name and "You " in description:
        return False
        
    # Skip if this is another agent's internal view
    if "Someone " in description and actor and actor != gui.player_name:
        return False
    
    # Rule 1: Shouts are always heard
    if event_type == 'shout':
        return True
        
    # Rule 2: Movements are seen if player is at origin or destination
    if event_type == 'movement':
        origin = event_data.get('origin')
        destination = event_data.get('destination')
        return player_location in [origin, destination]
    
    # Rule 3: Other events require player to be in same location
    return player_location == event_location

def add_player_view(gui, text, structured_data=None):
    """Add text to the Player View (MUD/MOO style interface - only what the player sees)"""
    # Skip empty or None messages
    if not text:
        return
        
    # Simply add the formatted text to the player view
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

def format_perspective(text, actor, observer):
    """Format text based on perspective (first-person vs third-person)"""
    if actor == observer:
        # First-person formatting
        text = text.replace(f"{actor} ", "You ")
        
        # Basic verb conjugation
        replacements = {
            " says": " say",
            " goes": " go",
            " moves": " move",
            " looks": " look",
            " examines": " examine",
            " shouts": " shout",
            " enters": " enter",
            " leaves": " leave"
        }
        for old, new in replacements.items():
            text = text.replace(old, new)
    
    return text

def create_event_fingerprint(event_data):
    """Create a unique fingerprint for event deduplication"""
    # Extract key components for fingerprinting
    actor = event_data.get('actor', 'unknown')
    action = event_data.get('action', 'unknown')
    location = event_data.get('location', 'unknown')
    event_type = event_data.get('type', 'unknown')
    
    # Use only minutes and seconds for time-based deduplication
    timestamp = datetime.now().strftime("%M:%S")
    
    # Create fingerprint string
    fingerprint = f"{event_type}:{actor}:{action}:{location}:{timestamp}"
    
    return fingerprint