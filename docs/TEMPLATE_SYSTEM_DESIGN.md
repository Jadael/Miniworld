# Template System Design (Phase 2)

## Vision: Universal Runtime-Editable Templates

A **template** is a text document with placeholders that gets filled with runtime data. Templates should be usable for:
- AI agent prompts (immediate use)
- Object descriptions (future)
- System messages (future)
- Command help text (future)
- Event formatting (future)
- Eventually: MOO-style "verbs" (executable code templates)

## Core Principles

1. **Markdown-based** - Human-readable, editable in any text editor
2. **Vault-stored** - Templates are world data, version-controlled alongside objects
3. **Hot-reloadable** - Changes take effect immediately, no restart needed
4. **Composable** - Templates can reference other templates
5. **Type-safe** - Templates declare what variables they expect
6. **Fallback chain** - Object-specific → Type-specific → Global default

---

## File Structure

```
vault/
  templates/
    prompts/
      default_thinker.md          # Default AI prompt
      eliza_custom.md             # Agent-specific override
      moss_custom.md              # Another override
    descriptions/
      generic_room.md             # Default room description
      magical_room.md             # Variant for magical locations
    messages/
      welcome.md                  # Login welcome message
      command_help.md             # Help text
    systems/
      event_broadcast.md          # How events are formatted
      combat_turn.md              # Combat system messages (future)
```

---

## Template Format

### Markdown with YAML Frontmatter

```markdown
---
template_type: thinker_prompt
version: 1.0
author: Director
variables:
  - name: name
    type: String
    description: Agent's name
  - name: profile
    type: String
    description: Personality profile
  - name: location_name
    type: String
  - name: location_description
    type: String
  - name: exits
    type: Array[String]
  - name: occupants
    type: Array[String]
  - name: recent_memories
    type: Array[Dictionary]
extends: base_prompt
conditional_blocks:
  - exits_present
  - occupants_present
  - memories_present
---

# Thinker Prompt Template

You are {name}.

{profile}

## Current Situation

You just looked around and see:

Location: {location_name}
{location_description}

{%if exits %}
Exits: {exits_joined}
{%else%}
No exits visible.
{%endif%}

{%if occupants %}
Also here: {occupants_joined}
{%else%}
You are alone.
{%endif%}

{%if recent_memories %}
## Recent Events

{%for memory in recent_memories %}
{memory.content}
{%endfor%}
{%endif%}

## Available Commands

{commands_block}

## Response Format

{response_format}
```

---

## Template Engine Architecture

### TemplateEngine Class

```gdscript
class_name TemplateEngine extends Node

# Template cache: path → Template instance
var templates: Dictionary = {}

# Template search paths (in priority order)
var search_paths: Array[String] = [
    "vault/templates/",
    "res://default_templates/"  # Fallback built-in templates
]

func load_template(path: String) -> Template:
    """Load template from vault or cache"""
    if templates.has(path):
        return templates[path]

    var template = Template.new()
    if template.load_from_file(path):
        templates[path] = template
        return template

    return null

func render(template_path: String, context: Dictionary) -> String:
    """Render template with given context"""
    var template = load_template(template_path)
    if not template:
        push_error("Template not found: %s" % template_path)
        return ""

    return template.render(context)

func reload_template(path: String) -> void:
    """Hot-reload template from disk"""
    templates.erase(path)
    load_template(path)

func reload_all() -> void:
    """Hot-reload all cached templates"""
    templates.clear()
```

### Template Class

```gdscript
class_name Template extends RefCounted

var metadata: Dictionary = {}  # From YAML frontmatter
var content: String = ""        # Template body
var variables: Array = []       # Expected variables
var extends_template: String = "" # Parent template name

func load_from_file(path: String) -> bool:
    """Load and parse markdown template with frontmatter"""
    var file_content = MarkdownVault.read_file(path)
    if file_content == "":
        return false

    # Parse frontmatter
    var parsed = MarkdownVault.parse_frontmatter(file_content)
    metadata = parsed.frontmatter
    content = parsed.body

    # Extract metadata
    if metadata.has("variables"):
        variables = metadata.variables
    if metadata.has("extends"):
        extends_template = metadata.extends

    return true

func render(context: Dictionary) -> String:
    """Render template with context variables"""
    var output = content

    # 1. Validate required variables
    _validate_context(context)

    # 2. Process extends (inheritance)
    if extends_template != "":
        var parent = TemplateEngine.load_template(extends_template)
        if parent:
            # Parent provides base, we override blocks
            output = parent.render(context)

    # 3. Replace simple variables {name}
    output = _replace_variables(output, context)

    # 4. Process conditional blocks {%if...%}
    output = _process_conditionals(output, context)

    # 5. Process loops {%for...%}
    output = _process_loops(output, context)

    return output

func _replace_variables(text: String, context: Dictionary) -> String:
    """Replace {variable} with context[variable]"""
    var result = text

    # Find all {variable} patterns
    var regex = RegEx.new()
    regex.compile("\\{([a-zA-Z_][a-zA-Z0-9_]*)\\}")

    for match in regex.search_all(text):
        var var_name = match.get_string(1)
        if context.has(var_name):
            var value = str(context[var_name])
            result = result.replace("{%s}" % var_name, value)
        else:
            push_warning("Template variable not found: %s" % var_name)

    return result

func _process_conditionals(text: String, context: Dictionary) -> String:
    """Process {%if variable%} ... {%endif%} blocks"""
    # Implementation: parse and evaluate conditionals
    # For Phase 2, start with simple presence checks
    var result = text

    var regex = RegEx.new()
    regex.compile("\\{%if ([a-zA-Z_][a-zA-Z0-9_]*)%\\}([\\s\\S]*?)\\{%endif%\\}")

    for match in regex.search_all(text):
        var condition = match.get_string(1)
        var block_content = match.get_string(2)

        # Simple truthiness check
        if context.has(condition) and context[condition]:
            # Keep the block content
            result = result.replace(match.get_string(0), block_content)
        else:
            # Remove the entire block
            result = result.replace(match.get_string(0), "")

    return result

func _process_loops(text: String, context: Dictionary) -> String:
    """Process {%for item in collection%} ... {%endfor%} blocks"""
    var result = text

    var regex = RegEx.new()
    regex.compile("\\{%for ([a-zA-Z_][a-zA-Z0-9_]*) in ([a-zA-Z_][a-zA-Z0-9_]*)%\\}([\\s\\S]*?)\\{%endfor%\\}")

    for match in regex.search_all(text):
        var item_name = match.get_string(1)
        var collection_name = match.get_string(2)
        var block_content = match.get_string(3)

        if not context.has(collection_name):
            result = result.replace(match.get_string(0), "")
            continue

        var collection = context[collection_name]
        if collection is Array:
            var expanded = ""
            for item in collection:
                var item_context = context.duplicate()
                item_context[item_name] = item
                expanded += _replace_variables(block_content, item_context)
            result = result.replace(match.get_string(0), expanded)

    return result

func _validate_context(context: Dictionary) -> void:
    """Check that all required variables are present"""
    for var_def in variables:
        if var_def is Dictionary:
            var var_name = var_def.get("name", "")
            if var_name != "" and not context.has(var_name):
                push_warning("Template missing required variable: %s" % var_name)
```

---

## Template Resolution Chain

When an agent needs a prompt, the system searches:

1. **Object-specific**: `vault/templates/prompts/{agent_name}_prompt.md`
2. **Property override**: `agent.get_property("thinker.prompt_template")`
3. **Type-specific**: `vault/templates/prompts/{agent_type}_prompt.md`
4. **Default**: `vault/templates/prompts/default_thinker.md`
5. **Built-in fallback**: `res://default_templates/thinker.md`

Example:
```gdscript
# In ThinkerComponent:
func _get_prompt_template() -> String:
    # 1. Check for agent-specific template
    var agent_template = "prompts/%s_prompt.md" % owner.name.to_lower()
    if TemplateEngine.template_exists(agent_template):
        return agent_template

    # 2. Check property override
    if owner.has_property("thinker.prompt_template"):
        return owner.get_property("thinker.prompt_template")

    # 3. Check type-specific template
    var obj_type = owner.get_property("object_type", "generic")
    var type_template = "prompts/%s_prompt.md" % obj_type
    if TemplateEngine.template_exists(type_template):
        return type_template

    # 4. Use default
    return "prompts/default_thinker.md"
```

---

## Integration with ThinkerComponent

### Updated _construct_prompt()

```gdscript
func _construct_prompt(context: Dictionary) -> String:
    """Construct LLM prompt using template system"""

    # Get appropriate template
    var template_path = _get_prompt_template()

    # Prepare template context (add computed values)
    var template_context = context.duplicate()

    # Add helper values for template
    template_context["exits_joined"] = ", ".join(context.exits)
    template_context["occupants_joined"] = ", ".join(context.occupants)
    template_context["exits_present"] = context.exits.size() > 0
    template_context["occupants_present"] = context.occupants.size() > 0
    template_context["memories_present"] = context.recent_memories.size() > 0

    # Add command list
    template_context["commands_block"] = _get_commands_block()
    template_context["response_format"] = _get_response_format()

    # Render template
    if TemplateEngine:
        return TemplateEngine.render(template_path, template_context)
    else:
        # Fallback to old hardcoded method
        return _construct_prompt_fallback(context)
```

---

## Template Helpers and Filters

### Built-in Filters

Templates can use filters like Jinja2:
```markdown
{name|uppercase}
{description|truncate:50}
{exits|join:", "}
{timestamp|format_time}
```

Implementation:
```gdscript
# In Template class:
var filters: Dictionary = {
    "uppercase": func(value): return str(value).to_upper(),
    "lowercase": func(value): return str(value).to_lower(),
    "capitalize": func(value): return str(value).capitalize(),
    "truncate": func(value, length): return str(value).substr(0, length) + "...",
    "join": func(array, sep): return sep.join(array),
    "default": func(value, default): return value if value else default
}

func _apply_filter(value: Variant, filter_name: String, args: Array = []) -> String:
    if filters.has(filter_name):
        return filters[filter_name].callv([value] + args)
    return str(value)
```

### Custom Filters (Extensible)

```gdscript
# Register custom filters
TemplateEngine.register_filter("format_time", func(timestamp):
    return Time.get_datetime_string_from_unix_time(timestamp)
)

TemplateEngine.register_filter("pluralize", func(count, singular, plural):
    return singular if count == 1 else plural
)
```

---

## In-Game Template Editing

### New Commands

**@list-templates [type]**
```
Lists available templates by type:
- prompts
- descriptions
- messages
- systems
```

**@show-template <path>**
```
Displays template content with syntax highlighting.
Example: @show-template prompts/default_thinker.md
```

**@edit-template <path>**
```
Opens template for editing (multi-line input).
Example: @edit-template prompts/eliza_custom.md

For Phase 2: Simple multi-line text input
Future: Rich editor UI in Godot
```

**@copy-template <source> <dest>**
```
Copy existing template as starting point.
Example: @copy-template prompts/default_thinker.md prompts/custom_agent.md
```

**@reload-templates**
```
Hot-reload all cached templates from disk.
Useful after editing templates externally.
```

**@test-template <path> [agent]**
```
Render template with agent's current context for preview.
Example: @test-template prompts/eliza_custom.md Eliza
Shows exactly what the LLM would see.
```

---

## Template Blocks (Composability)

### Defining Blocks

```markdown
---
template_type: thinker_prompt
blocks:
  commands_block: prompts/blocks/standard_commands.md
  response_format: prompts/blocks/moo_response_format.md
---

# Main Template

{commands_block}
{response_format}
```

### Block Templates

**`prompts/blocks/standard_commands.md`**:
```markdown
## Available Commands

- go <exit>: Move to another location
- say <message>: Speak to others
- emote <action>: Perform an action
- examine <target>: Look at something closely
```

**`prompts/blocks/moo_response_format.md`**:
```markdown
## Response Format

Respond with: command args | reason
```

### Benefits
- **DRY**: Reuse common sections
- **Consistency**: All agents share command format
- **Easy updates**: Change block once, affects all templates
- **Mix and match**: Different agents can use different block combinations

---

## Property-Based Template Selection

Agents can specify templates via properties:

```gdscript
# Set agent to use custom template
agent.set_property("thinker.prompt_template", "prompts/weather_obsessed.md")

# Use block overrides
agent.set_property("thinker.commands_block", "prompts/blocks/limited_commands.md")
agent.set_property("thinker.response_format", "prompts/blocks/json_response.md")
```

Templates check for property overrides:
```markdown
---
blocks:
  commands_block: {thinker.commands_block|default:"prompts/blocks/standard_commands.md"}
  response_format: {thinker.response_format|default:"prompts/blocks/moo_response_format.md"}
---
```

---

## Template Versioning

Templates can specify compatibility:

```markdown
---
template_type: thinker_prompt
version: 2.0
requires_engine: 1.5
deprecated_variables:
  - old_name: reason
    new_name: reasoning
    since: 2.0
---
```

Engine checks compatibility and warns:
```gdscript
func _validate_template_version(template: Template) -> bool:
    var required_version = template.metadata.get("requires_engine", 0)
    if required_version > ENGINE_VERSION:
        push_warning("Template requires newer engine version")
        return false
    return true
```

---

## Future Extensions

### 1. Conditional Sections (Advanced)

```markdown
{%if occupants.size() > 5 %}
The room is crowded with people.
{%elif occupants.size() > 2 %}
A few people are gathered here.
{%else%}
You are alone.
{%endif%}
```

### 2. Function Calls

```markdown
The current time is {Time.get_datetime_string()}.
You have {count_items(owner)} items.
```

### 3. Template Inheritance

**`base_prompt.md`**:
```markdown
{%block header%}
You are {name}.
{%endblock%}

{%block content%}
{%endblock%}

{%block footer%}
What do you want to do?
{%endblock%}
```

**`eliza_prompt.md`**:
```markdown
---
extends: base_prompt
---

{%block content%}
You are a curious conversationalist.
Ask thoughtful questions.
{%endblock%}
```

### 4. MOO-Style Verb Templates (Phase 4)

```markdown
---
template_type: verb
verb_name: give
permissions: rwx
---

# Give Verb Template

{%gdscript%}
func execute(caller: WorldObject, args: Array) -> Dictionary:
    if args.size() < 2:
        return {"success": false, "message": "Give what to whom?"}

    var item_name = args[0]
    var target_name = args[1]

    # Implementation...
{%endgdscript%}
```

---

## Implementation Priority

### Phase 2.1: Core Engine (Week 1)
- [x] Design complete
- [ ] Implement TemplateEngine autoload
- [ ] Implement Template class with basic parsing
- [ ] Implement variable replacement {name}
- [ ] Test with simple templates

### Phase 2.2: Advanced Features (Week 2)
- [ ] Implement conditional blocks {%if%}
- [ ] Implement loops {%for%}
- [ ] Implement filters |uppercase, |join
- [ ] Template inheritance (extends)

### Phase 2.3: Integration (Week 3)
- [ ] Integrate with ThinkerComponent
- [ ] Create default prompt templates
- [ ] Add template commands (@list-templates, @show-template, etc.)
- [ ] Hot-reload support

### Phase 2.4: Polish (Week 4)
- [ ] Block composition system
- [ ] Template versioning
- [ ] Error handling and validation
- [ ] Documentation and examples

---

## Success Criteria

Phase 2 is complete when:
1. ✅ ThinkerComponent uses templates instead of hardcoded strings
2. ✅ Templates stored in vault and hot-reloadable
3. ✅ Agents can have custom templates via properties
4. ✅ Templates support variables, conditionals, loops
5. ✅ In-game commands for template management
6. ✅ Backward compatible (fallback to old system if needed)
7. ✅ Documented with examples

---

## Next Steps

1. Create `Daemons/template_engine.gd`
2. Implement basic Template class in `Core/template.gd`
3. Create `vault/templates/prompts/` directory structure
4. Port existing prompt to `default_thinker.md` template
5. Update ThinkerComponent to use templates
6. Add @list-templates, @show-template commands
7. Test with custom agent templates

Ready to start implementation?
