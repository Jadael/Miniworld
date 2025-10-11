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
