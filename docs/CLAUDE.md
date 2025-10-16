# docs

## Purpose
The docs directory contains all architecture documentation, design notes, implementation guides, and historical context for the Miniworld project. These files are intended for human readers (developers and AI assistants) to understand the project's evolution and design decisions.

## Contents

### Core Architecture
- **MINIWORLD_ARCHITECTURE.md** - High-level system architecture overview
- **SKRODE_ARCHITECTURE.md** - Detailed architecture documentation (skrode = AI agent)
- **Library of Aletheia Technical Documentation.md** - Original technical design document

### Implementation Guides
- **AGENTS.md** - AI agent system and behavior documentation
- **BUILDING.md** - World-building commands and patterns
- **PERSISTENCE_IMPLEMENTATION.md** - Markdown vault persistence system
- **VAULT_STRUCTURE.md** - Vault file format and organization
- **TEMPLATE_SYSTEM_DESIGN.md** - (Future) Template-based prompt system
- **IMPLEMENTATION_NOTES.md** - General implementation notes and patterns

### Feature Designs
- **HELP_SYSTEM_DESIGN.md** - Command help and metadata system design
- **MVP_SELF_AWARENESS.md** - Self-aware agent commands design (@my-profile, @set-profile)
- **Memory System** - Comprehensive memory/notes system (see Core/command_metadata.gd for usage guide)

### Setup and Configuration
- **OLLAMA_SETUP.md** - How to install and configure Ollama for LLM inference
- **QUICK_FIX_OLLAMA.md** - Common Ollama connection issues and fixes

### Project History
- **MIGRATION_SUMMARY.md** - Notes from Python prototype to Godot migration
- **PYTHON_PROTOTYPE_REVIEW.md** - Analysis of the original Python implementation

## Document Organization

### Design Documents
Write design docs BEFORE implementing features:
- Explain the problem being solved
- Consider multiple approaches
- Document the chosen solution and why
- Include examples and edge cases

### Implementation Guides
Write implementation guides DURING feature development:
- Step-by-step instructions
- Code examples
- Testing procedures
- Integration points

### Architecture Documents
Update architecture docs AFTER significant changes:
- System overviews
- Interaction diagrams (in text/markdown)
- Core patterns and conventions
- Technology decisions

## Relationship to Project

Documentation serves multiple audiences:
- **Human Developers** - Understand design decisions and system architecture
- **Claude Code Sessions** - Context for implementing features and fixing bugs
- **Future Contributors** - Onboarding and project context
- **Project Director** - Reference for design decisions and technical details

Documentation should be:
- **Accurate** - Updated when code changes
- **Concise** - Focus on WHY, not WHAT (code shows what)
- **Discoverable** - Clear filenames and organization
- **Maintainable** - Keep related docs together

## Documentation Standards

### Markdown Format
All docs use GitHub-flavored Markdown:
- Headers (#, ##, ###)
- Code blocks with language tags (\`\`\`gdscript)
- Lists (ordered and unordered)
- Emphasis (*italic*, **bold**)
- Links (relative paths when referencing other docs)

### Code Examples
Always include:
- Language tag on code blocks
- Comments explaining non-obvious parts
- File paths in comments (e.g., `# In actor.gd:123`)
- Expected output when relevant

### Sections to Include
Most design docs should have:
1. **Problem Statement** - What are we solving?
2. **Approach** - How are we solving it?
3. **Implementation** - Technical details
4. **Examples** - Concrete usage
5. **Benefits** - Why this approach?
6. **Future Work** - What's next?

## When to Update Documentation

### Always Update When:
- Implementing a feature mentioned in design docs
- Changing core patterns or conventions
- Adding new commands or components
- Modifying public APIs
- Discovering bugs in documented behavior

### Consider New Docs When:
- Designing a significant new feature
- Establishing a new pattern
- Making architectural decisions
- Documenting lessons learned

### Archive When:
- Implementation differs significantly from design
- Feature was abandoned or replaced
- Historical context is valuable but not current

## Maintenance Instructions

When working with documentation:
1. **Read relevant docs first** - Understand existing design
2. **Update after changes** - Keep docs synchronized with code
3. **Create new docs for new patterns** - Document as you design
4. **Reference the root CLAUDE.md** - Keep conventions consistent
5. **Use relative links** - Link related documentation together

Follow the recursive documentation pattern described in the root CLAUDE.md. This docs/CLAUDE.md explains the documentation directory specifically.
