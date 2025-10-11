import os
import re
import json
from datetime import datetime

class MarkdownVault:
    """Utility class for managing Markdown content in a vault-like structure"""
    
    @staticmethod
    def ensure_vault_directories():
        """Create the necessary directory structure for the Markdown vault"""
        directories = [
            "vault",
            "vault/templates",
            "vault/settings",
            "vault/world",
            "vault/world/locations",
            "miniminds"
        ]
        
        for directory in directories:
            os.makedirs(directory, exist_ok=True)
            
        # Create default templates and settings if they don't exist
        MarkdownVault.create_default_files()
    
    @staticmethod
    def create_default_files():
        """Create default template and settings files if they don't exist"""
        default_files = {
            #Templates
            "vault/templates/prompt_template.md": DEFAULT_PROMPT_TEMPLATE,
            "vault/templates/default_profile.md": DEFAULT_PROFILE_TEMPLATE,
            "vault/templates/memory_format.md": DEFAULT_MEMORY_FORMAT,
            "vault/templates/note_format.md": DEFAULT_NOTE_FORMAT,
            "vault/templates/agent_system_prompt.md": DEFAULT_AGENT_SYSTEM_PROMPT,
            
            # Settings
            "vault/settings/app_settings.md": DEFAULT_APP_SETTINGS,
            "vault/settings/llm_settings.md": DEFAULT_LLM_SETTINGS,
            "vault/settings/commands.md": DEFAULT_COMMANDS,
            "vault/settings/turn_rules.md": DEFAULT_TURN_RULES,
            "vault/settings/command_aliases.md": DEFAULT_COMMAND_ALIASES,  # Add this line
        }
        
        for filepath, content in default_files.items():
            if not os.path.exists(filepath):
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(content)
    
    @staticmethod
    def load_template(template_name):
        """Load a template from the vault"""
        template_path = f"vault/templates/{template_name}.md"
        
        if not os.path.exists(template_path):
            print(f"Warning: Template {template_name} not found, using default")
            return MarkdownVault.get_default_template(template_name)
        
        with open(template_path, "r", encoding="utf-8") as f:
            return f.read()
    
    @staticmethod
    def load_settings(settings_name):
        """Load settings from the vault"""
        settings_path = f"vault/settings/{settings_name}.md"
        
        if not os.path.exists(settings_path):
            print(f"Warning: Settings file {settings_name} not found, using default")
            return MarkdownVault.get_default_settings(settings_name)
        
        with open(settings_path, "r", encoding="utf-8") as f:
            return f.read()
    
    @staticmethod
    def get_default_template(template_name):
        """Get default template content"""
        templates = {
            "prompt_template": DEFAULT_PROMPT_TEMPLATE,
            "default_profile": DEFAULT_PROFILE_TEMPLATE,
            "memory_format": DEFAULT_MEMORY_FORMAT,
            "note_format": DEFAULT_NOTE_FORMAT
        }
        return templates.get(template_name, "# Empty Template")
    
    @staticmethod
    def get_default_settings(settings_name):
        """Get default settings content"""
        settings = {
            "app_settings": DEFAULT_APP_SETTINGS,
            "llm_settings": DEFAULT_LLM_SETTINGS,
            "commands": DEFAULT_COMMANDS,
            "turn_rules": DEFAULT_TURN_RULES,
            "command_aliases": DEFAULT_COMMAND_ALIASES  # Add this line
        }
        return settings.get(settings_name, "# Empty Settings")
    
    @staticmethod
    def parse_settings(settings_content):
        """Parse settings from Markdown content"""
        settings = {}
        
        # Extract YAML frontmatter if present
        frontmatter_match = re.search(r"^---\n(.*?)\n---", settings_content, re.DOTALL)
        if frontmatter_match:
            try:
                yaml_content = frontmatter_match.group(1)
                # Simple YAML-like parsing (without requiring PyYAML)
                for line in yaml_content.split("\n"):
                    if ":" in line:
                        key, value = line.split(":", 1)
                        key = key.strip()
                        value = value.strip()
                        
                        # Convert to appropriate type
                        if value.lower() == "true":
                            value = True
                        elif value.lower() == "false":
                            value = False
                        elif value.isdigit():
                            value = int(value)
                        elif value.replace(".", "", 1).isdigit() and value.count(".") == 1:
                            value = float(value)
                            
                        settings[key] = value
            except Exception as e:
                print(f"Error parsing YAML frontmatter: {e}")
        
        # Parse key-value pairs from list items (- Key: Value)
        for line in settings_content.split("\n"):
            if line.strip().startswith("- ") and ":" in line:
                try:
                    key_value = line.strip()[2:]  # Remove the "- " prefix
                    key, value = key_value.split(":", 1)
                    key = key.strip()
                    value = value.strip()
                    
                    # Handle comments at the end of the line
                    if "#" in value:
                        value = value.split("#", 1)[0].strip()
                    
                    # Convert to appropriate type
                    if value.lower() == "true":
                        value = True
                    elif value.lower() == "false":
                        value = False
                    elif value.isdigit():
                        value = int(value)
                    elif value.replace(".", "", 1).isdigit() and value.count(".") == 1:
                        value = float(value)
                        
                    settings[key] = value
                except Exception as e:
                    print(f"Error parsing list item: {e}")
        
        return settings
    
    @staticmethod
    def parse_aliases(aliases_content):
        """Parse command aliases from Markdown content"""
        aliases = {}
        
        # Process line by line
        for line in aliases_content.split('\n'):
            line = line.strip()
            
            # Skip empty lines, headers, and comments
            if not line or line.startswith('#') or line.startswith('>'):
                continue
                
            # Check for bullet points
            if line.startswith('- '):
                line = line[2:].strip()
                
                # Look for different separator formats
                for separator in ['=>', '->', '=', ':', ' as ']:
                    if separator in line:
                        alias, command = line.split(separator, 1)
                        aliases[alias.strip().upper()] = command.strip().upper()
                        break
        
        return aliases
    
    @staticmethod
    def fill_template(template, data):
        """Fill a template with data"""
        result = template
        
        # Handle conditional blocks first
        def replace_conditionals(match):
            condition_var = match.group(1).strip()
            content = match.group(2)
            
            # Check if the condition variable exists and is truthy
            if condition_var in data and data[condition_var]:
                return content
            return ""
        
        # Replace {{#if var}}...{{/if}} blocks
        result = re.sub(r'\{\{#if\s+([^}]+)\}\}(.*?)\{\{/if\}\}', replace_conditionals, result, flags=re.DOTALL)
        
        # Replace simple variables {{var}}
        for key, value in data.items():
            if isinstance(value, (str, int, float, bool)):
                placeholder = f"{{{{{key}}}}}"
                result = result.replace(placeholder, str(value))
        
        return result

# Define default templates and settings
DEFAULT_AGENT_SYSTEM_PROMPT = """Think and act as your assigned character would think and act, always working in their best interest given the available information.

Formatted as a command, what do you do next and why? Remember the current situation. As you read these memories, identify: (1) which of your goals has received the least attention, (2) what information you're missing that would help you most, and (3) what new approach could yield better results than your recent actions. Before deciding your next action, reflect: Have your recent actions made meaningful progress toward your goals? If you've been repeating similar approaches without new results, prioritize a different type of action now. When making notes, identify if you're stuck in a pattern (e.g., only asking questions or only observing). Your notes are most valuable when they suggest specific new approaches to try rather than just documenting what happened. The most effective agents regularly cycle between different action types (SAY, GO TO, NOTE, etc.) rather than repeating the same command type in different locations. If you've used one command type multiple times recently, consider using a different one now.

Basic commands:

  GO TO <location name> | <reason for going>
  SAY <one line message> | <reason for saying>
  SHOUT <message> | <reason for shouting>
  EMOTE <physical action> | <reason for acting>
  NOTE <title>: <observations implications plans follow-up questions related topics etc> | <reason for noting>
  RECALL <example note content> | <reason for recalling>
  LOOK | <reason for looking/passing>

Your reason after `|` should explain the context and desired outcome of WHY you're taking this action along with the relevant clues which led to this action. The SAY command sends a message to everyone in the same location, while the SHOUT command sends a message to everyone in all locations everywhere. The EMOTE command lets you express physical actions or emotions (e.g., "EMOTE smiles warmly" will appear to others as `{{name}} smiles warmly`). EMOTE makes no changes on the world so it is only for self-expression. The NOTE feature is for private mental guidance for your future self. Recent and relevant notes to the current situation are automatically shown on your future turns using semantic matching to your WHY. Notes automatically document time and date, location, and who is present, so you don't need to include those details. If you suspect there might be other notes available, the RECALL command semantically searches your notes for matches to a given hypothetical example which you should craft. Note titles are used as unique filenames so avoid overwiting existing notes without good reason such as removing incorrect information. Notes are extremely powerful especially if there is important information in your oldest memories which needs to be preserved before they fade or if you notice questions you haven't seen tested yet in your memories. Read your notes and memories critically and don't trust them! Your past self could have been wrong or misled and passed on incorrect information, so everything needs to be tested. Consider counterfactuals. Don't re-explain existing memories and notes so much, instead think about potential and desired futures they lead towards- those types of thoughts are much more useful to your future self as notes, because you're making about their world instead of yours. If you don't see up-to-date notes about your goals then making one with theories on what try next and why should be your first priority and then acting to test and correct those theories.

IMPORTANT: Your ENTIRE RESPONSE must be only a SINGLE command on ONE LINE by itself with no other text or labels or formatting or prose etc before or after the one-line command. Your reason cannot contain linebreaks or commas or pipes. You cannot repeat your previous command."""


DEFAULT_PROMPT_TEMPLATE = """You are {{name}}. Thinking as {{name}}, staying true and faithful to how {{name}} would think, use your memories, notes, and situation to decide your next action. {{profile}}

---

{{#if memories}}
### Recent Memories
{{memories}}

---
{{/if}}

{{#if notes}}
### Recent and/or Relevant Mental Notes
{{notes}}

---
{{/if}}

{{#if last_thought}}
## Previous Thinking (fragments to consider or discard)
{{last_thought}}

---
{{/if}}

{{#if last_command}}
## Previous Command
Your last command was: {{last_command}}

The result was: {{last_result}}

---
{{/if}}

## Your Current Situation
You are {{name}} in 📍{{location}} at 📅{{current_time}}. {{profile}}
If you LOOK around {{location}} you see: 💡{{location_description}} {{location_exits}}
👥{{location_characters}}

🔧 Known commands:

GO TO [location] | [reason for going]
SAY [message] | [reason for saying]
SHOUT [message] | [reason for shouting]
NOTE [title]: [single line of observations implications plans follow-up questions related topics etc] | [reason for noting]
RECALL [example content] | [reason for recalling]
LOOK | [reason for looking/passing]

IMPORTANT: Your ENTIRE RESPONSE must be only a SINGLE command on ONE LINE. Your [reason] cannot contain linebreaks. You cannot repeat your previous command."""

DEFAULT_PROFILE_TEMPLATE = """Friendly, curious, helpful."""

DEFAULT_MEMORY_FORMAT = """# {{memory_type}} Memory

🧠{{memory_id}}:{👥{{who}},💡{{what}},📍{{where}},📅{{when}},❓{{why}},🔧{{how}}}
"""

DEFAULT_NOTE_FORMAT = """# {{title}}
📅 {{current_time}}
👥 Present: {{characters}}
📍 {{location}}
🔧 Note on {{title_lower}}
❓ {{reason}}
💡 {{content}}
"""

DEFAULT_APP_SETTINGS = """# Minimind Application Settings

## Memory Settings
- Default Memory Count: 64
- Default Notes Count: 16

## Turn Manager Settings
- Base TU Cost: 1
- Say TU Cost Multiplier: 3  # One additional TU per 3 words
- Shout TU Cost Multiplier: 2  # One additional TU per 2 words
- Note TU Cost Multiplier: 7  # One additional TU per 7 words
"""

DEFAULT_LLM_SETTINGS = """# LLM Settings

## Default Model
- Model: deepseek-r1:14b
- Temperature: 0.7
- Context Tokens: 32768
- Repeat Penalty: 1.2
- Embedding Model: all-minilm

## Stop Tokens
- Stop Token 1: "Explanation:"
- Stop Token 2: "Let me explain:"
- Stop Token 3: "To explain my reasoning:"
"""

DEFAULT_COMMANDS = """# Available Commands

## GO TO [location]
Move to another connected location.
- TU Cost: Basic cost (1)
- Example: `GO TO Kitchen | I want to get something to eat`

## SAY [message]
Say something to all characters in your current location.
- TU Cost: Basic cost + 1 TU per 3 words
- Example: `SAY Hello everyone, how are you today? | I want to be friendly`

## SHOUT [message]
Shout a message that all characters can hear regardless of location.
- TU Cost: Basic cost + 1 TU per 2 words
- Example: `SHOUT Help, there's an emergency! | I need immediate assistance`

## NOTE [title]: [content]
Create a personal note for future reference.
- TU Cost: Basic cost + 1 TU per 7 words
- Example: `NOTE Party Plans: Need to organize location, food, and invitations | Planning for future event`

## RECALL [query]
Search your notes for information related to the query.
- TU Cost: 2
- Example: `RECALL party planning | I need to remember what I noted about parties`

## LOOK
Observe your current surroundings.
- TU Cost: Basic cost (1)
- Example: `LOOK | I want to see what's around me`
"""

DEFAULT_TURN_RULES = """# Turn Manager Rules

## Turn Order Rules
- Players Take Turns: true
- Lowest TU Goes First: true
- Break Ties By Last Turn: true

## Cost Rules
- Base Cost: 1
- Scale With Content: true
"""

# Define default templates and settings
DEFAULT_COMMAND_ALIASES = """# Command Aliases

This file defines aliases for commands in the Minimind system. An alias maps to a canonical command.
The system will recognize any of these as equivalent to their canonical form.

## Formatting Options
- `ALIAS => COMMAND` 
- `ALIAS -> COMMAND`
- `ALIAS = COMMAND`
- `ALIAS : COMMAND`

## Defined Aliases

- NOTICE => NOTE
- TRAVEL TO => GO TO
- MOVE TO => GO TO
- WALK TO => GO TO
- TALK => SAY
- SPEAK => SAY
- TELL => SAY
- YELL => SHOUT
- WHISPER => SAY
- EXAMINE => LOOK AT
- OBSERVE => LOOK
- CHECK => LOOK
- VIEW => LOOK
- THINK => NOTE
- REMEMBER => RECALL
- SEARCH => RECALL
- QUERY => RECALL
- ASK => RECALL
"""