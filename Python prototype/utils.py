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
        return timestamp_str