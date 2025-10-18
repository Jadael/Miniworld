#!/usr/bin/env python3
"""Deduplicate memory files in vault by content.

Scans all agent memory directories and removes duplicate memories based on
their actual content (after frontmatter). Keeps the earliest timestamped
version of each unique memory.
"""

import os
import re
from pathlib import Path
from collections import defaultdict

# Vault path
VAULT_BASE = Path(os.path.expanduser("~")) / "AppData/Roaming/Godot/app_userdata/Miniworld/vault/agents"


def parse_memory_file(filepath):
    """Parse a memory markdown file, separating frontmatter from content.

    Returns:
        tuple: (frontmatter_dict, content_string)
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        text = f.read()

    # Split frontmatter and body
    if text.startswith('---\n'):
        parts = text.split('---\n', 2)
        if len(parts) >= 3:
            frontmatter_text = parts[1]
            body = parts[2]

            # Parse frontmatter into dict (simple key: value parsing)
            frontmatter = {}
            for line in frontmatter_text.strip().split('\n'):
                if ':' in line:
                    key, value = line.split(':', 1)
                    frontmatter[key.strip()] = value.strip()

            # Extract content (remove "# Memory\n\n" header)
            content = body.strip()
            if content.startswith('# Memory\n\n'):
                content = content[len('# Memory\n\n'):]

            return frontmatter, content.strip()

    return {}, text.strip()


def deduplicate_agent_memories(agent_dir):
    """Deduplicate memories for a single agent.

    Args:
        agent_dir: Path to agent directory (e.g., vault/agents/Blueshell)

    Returns:
        tuple: (kept_count, removed_count)
    """
    memories_dir = agent_dir / "memories"

    if not memories_dir.exists():
        return 0, 0

    # Collect all memory files
    memory_files = sorted(memories_dir.glob("*-memory.md"))

    if len(memory_files) == 0:
        return 0, 0

    # Track unique content -> earliest file
    content_to_file = {}
    duplicates = []

    for filepath in memory_files:
        frontmatter, content = parse_memory_file(filepath)

        if content in content_to_file:
            # Duplicate found - mark for removal
            duplicates.append(filepath)
        else:
            # First occurrence of this content
            content_to_file[content] = filepath

    # Remove duplicates
    for dup_file in duplicates:
        print(f"  Removing duplicate: {dup_file.name}")
        dup_file.unlink()

    kept_count = len(content_to_file)
    removed_count = len(duplicates)

    return kept_count, removed_count


def main():
    """Deduplicate memories for all agents."""
    print(f"Scanning vault at: {VAULT_BASE}\n")

    if not VAULT_BASE.exists():
        print(f"ERROR: Vault directory not found at {VAULT_BASE}")
        return

    total_kept = 0
    total_removed = 0

    # Process each agent directory
    for agent_dir in sorted(VAULT_BASE.iterdir()):
        if not agent_dir.is_dir():
            continue

        agent_name = agent_dir.name
        print(f"Processing {agent_name}...")

        kept, removed = deduplicate_agent_memories(agent_dir)

        if removed > 0:
            print(f"  [OK] Kept {kept} unique memories, removed {removed} duplicates\n")
        else:
            print(f"  [OK] No duplicates found ({kept} memories)\n")

        total_kept += kept
        total_removed += removed

    print(f"\n{'='*60}")
    print(f"SUMMARY:")
    print(f"  Total unique memories: {total_kept}")
    print(f"  Total duplicates removed: {total_removed}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
