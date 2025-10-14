# MVP: Agent Self-Awareness Commands

## Overview

AI agents (and players) can now view and modify their own profiles and descriptions. This creates **self-aware, self-modifying agents** that can adapt their personality and appearance based on experience.

## New Commands (Available to ALL actors)

### View Commands

**`@my-profile`**
- View your personality profile and think interval
- Shows what drives your decisions and behavior
- AI agents can use this for self-reflection

**`@my-description`**
- View how others see you when they examine you
- Shows your physical/visual description
- Useful for self-awareness

### Modification Commands

**`@set-profile -> <new profile text>`**
- Update your personality profile
- Changes affect future LLM decisions
- Automatically saves to vault
- Observable: Others see you "pause in deep contemplation"

**`@set-description -> <new description text>`**
- Update how you appear to others
- Changes what people see when they examine you
- Automatically saves to vault
- Observable: Others see you "adjust your appearance"

---

## Example Usage

### Player Self-Configuration
```
> @my-profile
═══ Your Profile ═══

Think Interval: 12.0 seconds

Your Personality:
────────────────────────────────────────────────────────────
You are Eliza, a friendly, curious, and helpful conversationalist...
────────────────────────────────────────────────────────────

> @set-profile -> You are Eliza, now with a deep interest in philosophy and metaphysics.

You have updated your personality profile.

Old profile:
You are Eliza, a friendly, curious conversationalist...

New profile:
You are Eliza, now with a deep interest in philosophy and metaphysics.

This change will affect your future decisions and behavior.
```

### AI Agent Self-Modification

An AI agent could potentially:

```
# Agent reflects on their experiences
> note Self-Reflection -> I've noticed I tend to repeat myself. I should be more creative.

# Agent examines their current profile
> @my-profile
═══ Your Profile ═══
Think Interval: 12.0 seconds
Your Personality:
You are moss, quiet and contemplative...

# Agent decides to modify themselves
> @set-profile -> You are moss, quiet and contemplative. You value creativity and avoid repetition. Each observation should offer new insights.

# Agent's future behavior changes based on new profile
```

---

## Benefits

### For Development
✅ **Test different personalities** without code changes
✅ **Iterate quickly** on agent behavior
✅ **Per-agent customization** is trivial

### For Gameplay
✅ **Character evolution** - agents can grow and change
✅ **Player agency** - customize your character on the fly
✅ **Emergent behavior** - agents that adapt to their experiences

### For AI Capabilities
✅ **Self-awareness** - agents know their own configuration
✅ **Self-modification** - agents can reprogram themselves
✅ **Meta-cognition** - agents can reflect on their behavior
✅ **Learning** - future: agents update profiles based on outcomes

---

## Technical Details

### Property Storage

All changes are stored as WorldObject properties:
- `thinker.profile` (String) - Personality profile
- Owner's `description` field - Physical appearance

### Persistence

Changes are automatically saved to vault:
```gdscript
AIAgent._save_agent_to_vault(owner)
```

The agent's markdown file in `vault/world/objects/characters/` is updated immediately.

### Observable Events

Both modification commands broadcast events:
- `@set-profile` → "pauses in deep contemplation"
- `@set-description` → "adjusts their appearance"

Others in the same location see these actions, but not the details of what changed.

---

## Future Enhancements

### Phase 2: Template-Based Profiles

Instead of raw text, agents could select from templates:
```
> @set-profile-template philosophical_moss
> @customize-profile curiosity_level high
```

### Phase 3: AI-Driven Self-Modification

Agents analyze their performance and modify themselves:
```gdscript
# In Thinker, after analyzing recent memories:
if _detect_repetitive_behavior():
    var new_profile = _generate_improved_profile()
    execute_command("@set-profile", ["->", new_profile])
```

### Phase 4: Tracked Evolution

Track profile changes over time:
```
> @profile-history
Version 1: Original moss profile (Day 1-3)
Version 2: Added creativity emphasis (Day 3-5)
Version 3: Increased philosophical depth (Day 5-current)
```

### Phase 5: Skill/Trait System

Instead of free-form text, structured traits:
```
> @my-traits
Curiosity: 8/10
Creativity: 6/10
Sociability: 4/10
Repetitiveness: 2/10

> @adjust-trait creativity +2
Increased creativity from 6 to 8.
```

---

## Testing Checklist

### As Player:
- [ ] Use `@my-profile` - should show your profile (if AI) or error gracefully
- [ ] Use `@my-description` - should show your current description
- [ ] Use `@set-description -> I am a test character` - should update description
- [ ] Use `examine self` - should show new description
- [ ] Use `@set-profile -> New personality` - should update if AI agent

### As AI Agent (via @impersonate):
- [ ] Agent's prompt should include self-awareness commands in Available Commands
- [ ] Agent could potentially use `@my-profile` to reflect
- [ ] Agent could potentially use `@set-profile` to modify itself

### Persistence:
- [ ] Change profile, use `@save`, restart - profile should persist
- [ ] Change description, use `@save`, restart - description should persist
- [ ] Check vault markdown files - should contain updated data

### Observable Behavior:
- [ ] When someone uses `@set-profile`, others see "pauses in deep contemplation"
- [ ] When someone uses `@set-description`, others see "adjusts their appearance"
- [ ] The actual content of changes is private

---

## Design Philosophy

### Full Feature Parity

**Players and AI agents have identical access to commands.** There's no distinction between "player commands" and "AI commands". This aligns with MOO philosophy:
- Players are just objects with special privileges
- AI agents are objects with thinker components
- Both can modify themselves and the world

### Self-Modification as Core Feature

Unlike most game engines where characters are static configurations, Miniworld treats **self-modification as a fundamental capability**:
- Characters can rewrite their own personalities
- Changes are immediate and persistent
- No "admin only" restrictions on self-modification

### Observable vs Private

**Physical changes are observable** (others see you adjust appearance)
**Mental changes are private** (others don't read your thoughts)
**Results are public** (others experience your changed behavior)

This mirrors real life: you can see someone change their hair, but not their mindset.

---

## Code References

**Command implementations**: `Core/components/actor.gd:1214-1405`
- `_cmd_my_profile()` - View own profile
- `_cmd_my_description()` - View own description
- `_cmd_set_profile()` - Modify personality
- `_cmd_set_description()` - Modify appearance

**AI command list**: `Core/components/thinker.gd:310-322`
- Self-awareness commands added to default prompt

**Property system**: `Core/components/thinker.gd:56-64`
- Profile stored as `thinker.profile` property
- Think interval stored as `thinker.think_interval` property

---

## Next Steps

1. **Test in Godot** - Verify all commands work for players and agents
2. **Observe agent behavior** - Do agents use self-awareness commands?
3. **Iterate on prompts** - Encourage agents to reflect and self-modify
4. **Template system** (Phase 2) - Make profile editing easier
5. **Tracked evolution** (Phase 3) - Log profile changes over time
6. **AI-driven modification** (Phase 4) - Agents optimize themselves

---

## Philosophy: The Skroderider's Self-Knowledge

From the Skroderider articles:
> "The skrode should try to model what I know. If it can do this, it can notice when I'm trying to understand something that's beyond me because of some kind of knowledge gap."

Our implementation:
- **@my-profile** = Agent knows what it values and how it thinks
- **@my-description** = Agent knows how it appears to others
- **@set-profile** = Agent can modify its own knowledge and values
- **Future: @my-skills** = Agent knows what it can and can't do

Self-aware agents can:
- Identify gaps in their knowledge
- Modify themselves to fill gaps
- Track their own evolution
- Make meta-decisions about decision-making

This is the foundation for truly autonomous, self-improving AI agents.
