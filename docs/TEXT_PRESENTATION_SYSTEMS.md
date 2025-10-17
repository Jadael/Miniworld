# Text Presentation Systems: Insights from MOO/MUD Games

## Executive Summary

This document analyzes text presentation and character description systems from three influential text-based multiplayer games to inform Miniworld's development:

1. **Sindome** (cyberpunk MOO, still active) - Advanced layered description system
2. **GalaxyWeb: Stellar Epoch** (sci-fi MOO by Squidsoft, offline) - Custom body language for alien species
3. **Fortharlin** (fantasy MOO by Squidsoft, offline) - Fantasy-themed sister game to GalaxyWeb

## Key Findings Summary

### Universal Patterns
- **Pronoun Substitution**: All MOO-based games use `%` codes for dynamic text generation
- **Layered Descriptions**: Separate systems for permanent traits vs. temporary states
- **Fact-Based Writing**: Descriptive text should present observable facts, not impose emotions
- **Player Control**: Fine-grained customization of how characters are perceived

### Most Relevant to Miniworld
1. Sindome's layered appearance system (`@describe` + `@nakeds` + clothing + state)
2. Pronoun substitution for gender-neutral, flexible text
3. Custom body language/adverbs for species-specific or character-specific expressions
4. Room descriptions that weave occupants and objects into prose paragraphs

---

## 1. Sindome: Layered Character Presentation

**Status**: Active cyberpunk MOO at sindome.org
**Key Innovation**: Multi-layer appearance composition system

### 1.1 The Appearance Stack

Sindome builds character appearance from multiple overlapping layers:

```
FINAL APPEARANCE =
  @describe (general build/posture/permanent traits)
  + @nakeds (22 body locations, visible when uncovered)
  + clothing (covers specific body locations)
  + cyberware (implants visible when uncovered)
  + environmental effects (blood, dirt, water damage)
  + medical status (exhaustion, wounds, sickness)
```

### 1.2 @describe Command

**Purpose**: Absolute basics of physical appearance

**Required Content**:
- Height and build (approximate, not precise measurements)
- Skin tone and ethnic features
- Posture and movement style
- Permanent visible characteristics (scars, limps, etc.)

**Length**: ~2 sentences

**Key Principle**: "Provide information, don't tell people how to feel"
- ✅ GOOD: "Scars crisscross their knuckles and forearms"
- ❌ BAD: "Intimidating scars make you feel uneasy"

**Mandatory**: All players must have a `@describe`

### 1.3 @nakeds System

**Purpose**: Describe how uncovered body parts appear

**Structure**: 22 body locations organized into 3 paragraphs:
1. **Head**: scalp, face, ears, neck, throat
2. **Torso**: shoulders, chest, back, arms, hands
3. **Legs/Groin**: hips, groin, legs, feet

**Dynamic Display**:
- When a body location is **covered by clothing**: `@naked` text is hidden
- When **uncovered**: `@naked` text appears in that paragraph
- Works exactly like real-life clothing coverage

**Example** (simplified):
```
Naked text for chest: "Lean muscle definition, tribal tattoo on left pec"
Naked text for arms: "Toned arms with faded track marks on inner elbows"

When wearing t-shirt: Only arms visible, chest hidden
When shirtless: Both visible
When wearing jacket: Both hidden
```

**Social Consequences**:
- Exposed body parts affect short description's "nudity level"
- Public nudity triggers negative NPC reactions
- Creates incentive for proper clothing choices

### 1.4 Pronoun Substitution

**Format**: `%[code]` in any description text

**Common Codes**:
- `%p` - possessive pronoun (his/her/their)
- `%s` - subject pronoun (he/she/they)
- `%o` - object pronoun (him/her/them)
- `%r` - reflexive pronoun (himself/herself/themself)

**Purpose**:
- Items can be worn by any gender
- Disguises work correctly
- Descriptions remain accurate after character changes

**Example**:
```
Clothing description: "This leather jacket makes %p shoulders look broader"

Worn by male character: "This leather jacket makes his shoulders look broader"
Worn by female character: "This leather jacket makes her shoulders look broader"
Worn by non-binary character: "This leather jacket makes their shoulders look broader"
```

**Best Practice**:
- Always use pronouns in `@nakeds` when describing body parts
- Always use pronouns in clothing/item descriptions
- Avoids gendered language becoming "jarring" when disguised

### 1.5 BabbleOn Scripting System

**Purpose**: Create interactive objects with scripted behaviors

**Architecture**:
- Abstraction layer on top of LambdaMOO verb system
- Line-by-line script execution
- Designed for non-programmers to create content

**Key Features**:
- `%variables` for dynamic text substitution
- `$types` for object references ($player, $npc, $room)
- Built-in commands: tell, pause, find, create, move, force

**Use Cases**:
- Interactive furniture with custom messages
- Triggered environmental events
- Dream/hallucination sequences
- Medical procedure automation

**Example** (simplified):
```
# A meditation cushion that guides the user
tell %player "You settle onto the cushion and close %p eyes."
pause 2
tell %player "Your breathing slows as you focus inward."
pause 3
tell %player "A sense of calm washes over you."
```

### 1.6 Layered State Display

**Final Output Composition**:
```
[Short Description]
A tall, lean human with cybernetic eyes. They are completely naked and look exhausted.

[Long Description]
[Paragraph 1: Head - @naked + cyberware + clothing]
This human stands roughly six feet tall with a wiry, athletic build. Their skin is a deep brown, contrasting sharply with the chrome-ringed cybernetic eyes that gleam in the dim light. A network of thin scars traces across their shaved scalp.

[Paragraph 2: Torso - @naked + clothing + environmental]
[If shirtless] Lean muscle definition shows across their chest and shoulders, with a tribal tattoo visible on the left pectoral. Their arms are toned, with faded track marks visible on the inner elbows. Dried blood spatters across their torso and arms.

[Paragraph 3: Legs/Groin - @naked + clothing]
[If naked] Their legs are long and muscular, scarred from street fights. Feet are bare and calloused.

[Status Effects]
They are exhausted and moving sluggishly. They smell of sweat and cheap whiskey.
```

**Key Insight**: Each layer contributes specific information types, composing into a coherent whole without redundancy.

---

## 2. LambdaMOO Pronoun Substitution Standard

**Source**: LambdaMOO Programmer's Manual (already in `reference_docs/`)

### 2.1 Core MOO Text Substitution

The LambdaMOO server provides `$string_utils:pronoun_sub()` utility for dynamic text generation.

**Basic Codes** (from MOO documentation and common practice):
- `%n` or `%N` - Name (capitalized variant)
- `%#` - Object number
- `%l` - Location name
- `%p` - Possessive pronoun (his/her/their)
- `%s` - Subject pronoun (he/she/they)
- `%o` - Object pronoun (him/her/them)
- `%r` - Reflexive pronoun (himself/herself/themselves)
- `%%` - Literal `%` sign

**Advanced Codes**:
- `%[property_name]` - Substitute object property value
- `%[#objnum]` - Reference specific object's property

**Example from Manual**:
```
"%N (%#) is in %l (%[#l])"

Expands to:
"Blip (#35) is in The Toilet (#96)"
```

### 2.2 Gender Properties

Standard LambdaMOO objects have gender-related properties:

```
.gender    - "male", "female", "neuter", "plural", or custom
.pronoun_sub - table of substitutions for this object
```

**How It Works**:
1. Object sets `.gender` property
2. MOO core generates appropriate pronouns automatically
3. Any text with `%p`, `%s`, `%o`, `%r` gets substituted when displayed

**Modern Extensions**:
- Custom gender support beyond binary
- Configurable pronoun sets (ze/zir, xe/xem, etc.)
- Per-object pronoun customization

### 2.3 Use Cases

**Action Messages**:
```
verb: emote
message: "%N %<action> %[posture]"

"Blip stretches languidly"
"Alice collapses exhausted"
```

**Object Interactions**:
```
verb: sit_on (chair)
message: "%N settles into %this, %p weight causing it to creak."

"Bob settles into the armchair, his weight causing it to creak."
```

**Room Descriptions**:
```
"A cluttered workshop. %N is here, focused on %p work."

"A cluttered workshop. Alice is here, focused on her work."
```

---

## 3. GalaxyWeb: Stellar Epoch & Fortharlin (Squidsoft Games)

**Developer**: Squidsoft (indie/hobbyist MOO development team)
**Status**: Both games offline (GalaxyWeb inactive since ~2014, Fortharlin similar timeframe)

### 3.1 Known Features

**GalaxyWeb: Stellar Epoch** (sci-fi):
- Space-based RPG MOO
- Organic spaceships
- Hacking systems
- Remote control mechanics
- Active community through early 2010s

**Fortharlin** (fantasy):
- Fantasy-themed sister game to GalaxyWeb
- Set in the world of Fortharlin (game named after its world)
- Created by same Squidsoft team
- Likely shared text engine technology with GalaxyWeb

### 3.2 Custom Body Language System (User Report)

**Key Innovation**: Species-specific adverbs and gestures for RP

**Purpose**:
- Give alien species in GalaxyWeb distinct "body language"
- Create cultural differences through non-verbal communication
- Enhance immersive roleplay without complex new commands

**Likely Implementation** (based on similar MOO systems):

```
# Standard emote
emote waves
"Alice waves."

# With adverb
emote waves :cheerfully
"Alice waves cheerfully."

# Species-specific adverb
emote waves :with-antenna-flutter [Vrexian custom gesture]
"Alice waves, antenna fluttering with enthusiasm."
```

**Custom Gesture System** (probable):
- Players define personal or species-specific gestures
- Gestures stored as properties on character objects
- Referenced in emotes and social commands
- Creates consistent, recognizable non-verbal language per character/species

**Example Use Case**:
```
# Human character
greet :warmly → "Bob greets you warmly, extending a hand."

# Vrexian character (insectoid alien)
greet :formally → "Zix greets you formally, antennae lowered in respect."

# Crystalline entity
greet :resonantly → "Hum greets you, crystalline structure resonating in harmony."
```

### 3.3 Room Description Philosophy (User Report)

**Key Innovation**: Prosaic paragraph format integrating all room elements

**Traditional MUD Format**:
```
The Town Square
A bustling marketplace in the center of town. The cobblestone
ground is worn smooth from countless footsteps.

Obvious exits: north, south, east, west

You see:
  a merchant's cart
  a stone fountain
  a wooden sign

People here:
  Alice the Merchant
  Bob the Guard
```

**GalaxyWeb/Fortharlin Format** (reported):
```
The Town Square [Technical: Mid-day, Clear, Temperate]

The bustling marketplace spreads across worn cobblestone, its
center dominated by a gurgling stone fountain where Alice the
Merchant leans against a wooden cart laden with wares. Bob the
Guard stands at attention near the north entrance, hand resting
on his sword hilt. A weathered wooden sign creaks in the breeze,
pointing toward the four exits.
```

**Design Principles**:
1. **Single Prose Paragraph**: Room, objects, and characters woven together
2. **Technical Header**: Game mechanics info (time, weather, etc.) separate from prose
3. **Object Integration**: Each object gets one sentence within the paragraph
4. **Character Integration**: NPCs and PCs described in context, not listed
5. **Empty Rooms**: Minimal "skeleton" description, fleshed out by actual objects
6. **Dynamic Composition**: Description rebuilds as objects/people enter/leave

**Benefits**:
- More literary, immersive reading experience
- Encourages rich object descriptions
- Characters feel integrated into environment, not "added on"
- Easier to parse visually (one paragraph vs. multiple lists)

**Challenges**:
- Requires well-written one-sentence descriptions for all objects
- Dynamic composition logic more complex
- May be harder to scan for specific objects/exits

---

## 4. Comparative Analysis

### 4.1 Pronoun Systems Comparison

| Feature | LambdaMOO Standard | Sindome | GalaxyWeb/Fortharlin |
|---------|-------------------|---------|---------------------|
| **Gender Options** | male/female/neuter/plural | Customizable | Likely customizable |
| **Substitution Codes** | %p, %s, %o, %r, %n | Same + %[property] | Likely similar |
| **Use in Items** | Yes | Mandatory for clothing | Likely yes |
| **Use in Rooms** | Yes | Yes | Yes |
| **Custom Pronouns** | DB-dependent | Supported | Unknown |

**Takeaway**: Pronoun substitution is a **foundational MOO feature**, essential for flexible text generation. Miniworld should implement early.

### 4.2 Description Layers Comparison

| Layer | Sindome | GalaxyWeb/Fortharlin | Traditional MOO |
|-------|---------|---------------------|----------------|
| **Base Description** | @describe | @describe | @describe |
| **Body Parts** | @nakeds (22 locations) | Likely similar | Usually not present |
| **Clothing** | Layered, affects visibility | Unknown | Simple wear/remove |
| **State Effects** | Medical, environmental | Unknown | Simple flags |
| **Integration** | Fully composed output | Prose paragraph | Listed separately |

**Takeaway**: Sindome has the most **sophisticated layered system**. GalaxyWeb/Fortharlin focused on **prose integration**. Both offer valuable patterns.

### 4.3 Room Description Philosophy

| Approach | Description | Example Games | Pros | Cons |
|----------|-------------|---------------|------|------|
| **Listed** | Separate lists for objects/people | Most MUDs/MOOs | Easy to scan, simple code | Less immersive |
| **Prose** | Woven paragraph | GalaxyWeb, Fortharlin | Literary, immersive | Harder to scan |
| **Hybrid** | Description + lists | Many modern games | Balance | Can feel redundant |
| **Layered** | Composed from parts | Sindome | Flexible, consistent | Complex composition logic |

**Takeaway**: Choice depends on **target audience** and **design goals**. Miniworld could experiment with multiple modes.

---

## 5. Recommendations for Miniworld

### 5.1 Priority 1: Pronoun Substitution (Immediate)

**Implement**: Core `%` substitution system for all text

**Minimum Viable**:
- `%n` - Actor name
- `%p` - Possessive pronoun (his/her/their)
- `%s` - Subject pronoun (he/she/they)
- `%o` - Object pronoun (him/her/them)
- `%r` - Reflexive pronoun (himself/herself/themself)

**Implementation**:
1. Add `.gender` property to WorldObject (string: "male", "female", "neutral", "plural", or custom)
2. Add `.pronouns` property for custom pronoun sets (Dictionary)
3. Create `TextManager.substitute_pronouns(text: String, subject: WorldObject) -> String`
4. Call on ALL player-visible text before display

**Example**:
```gdscript
# In TextManager
static func substitute_pronouns(text: String, subject: WorldObject) -> String:
    var gender = subject.get_property("gender", "neutral")
    var pronouns = _get_pronoun_set(gender, subject)

    text = text.replace("%n", subject.name)
    text = text.replace("%p", pronouns["possessive"])
    text = text.replace("%s", pronouns["subject"])
    text = text.replace("%o", pronouns["object"])
    text = text.replace("%r", pronouns["reflexive"])

    return text

# Usage in commands
var msg = "%n examines %p hands carefully."
var output = TextManager.substitute_pronouns(msg, player)
# "Alice examines her hands carefully."
```

### 5.2 Priority 2: Layered Descriptions (Medium-term)

**Implement**: Sindome-inspired multi-layer appearance system

**Core Layers**:
1. **Base Description** (`@describe` or `description` property)
   - Permanent physical traits
   - Build, height, coloring, posture
   - ~2-3 sentences

2. **State Modifiers** (component-driven)
   - Health/exhaustion (from future health component)
   - Emotional state (from Memory component context)
   - Environmental effects (wet, dirty, etc.)

3. **Equipment** (future inventory system)
   - Clothing coverage
   - Held items
   - Worn accessories

**Composition Function**:
```gdscript
func get_full_description(observer: WorldObject) -> String:
    var parts: Array[String] = []

    # Base description
    if has_property("description"):
        parts.append(get_property("description"))

    # State modifiers
    if has_component("actor"):
        var state = get_component("actor").get_visible_state()
        if state:
            parts.append(state)

    # Equipment (future)
    # if has_component("inventory"):
    #     parts.append(get_component("inventory").get_worn_summary())

    return "\n\n".join(parts)
```

**Phased Rollout**:
- Phase 1: Base description + basic state (current)
- Phase 2: Add pronoun substitution to all descriptions
- Phase 3: Add equipment/clothing layer (when inventory exists)
- Phase 4: Add environmental modifiers (wet, bloody, etc.)

### 5.3 Priority 3: Custom Body Language (Future)

**Implement**: Player-definable adverbs and gestures

**Use Cases**:
- AI agents develop signature mannerisms
- Different "species" or character archetypes
- Personality expression through consistent non-verbal cues

**Design**:
```gdscript
# Property on WorldObject
"body_language.wave" = "waves enthusiastically, bouncing slightly"
"body_language.nod" = "nods thoughtfully, eyes distant"
"body_language.greet" = "greets with a formal bow"

# Emote command usage
emote wave
# Uses body_language.wave if defined, otherwise default

# AI agent usage (in Thinker prompts)
"""
Your character has these signature gestures:
- wave: waves enthusiastically, bouncing slightly
- nod: nods thoughtfully, eyes distant

Use these in your emotes to express personality.
"""
```

**Benefits**:
- AI agents develop consistent "personality" through body language
- Players can customize their character's non-verbal expression
- Creates richer, more distinctive character portrayals
- Emergent behavior: agents may invent new gestures over time

### 5.4 Priority 4: Prose Room Descriptions (Experimental)

**Implement**: GalaxyWeb-style integrated room descriptions

**Concept**:
```gdscript
func compose_room_description(location: WorldObject, observer: WorldObject) -> String:
    var base = location.get_property("description", "")
    var contents = location.get_contents()

    # Option 1: Simple append (current)
    var objects_here = []
    var people_here = []
    for obj in contents:
        if obj.has_component("actor"):
            people_here.append(obj.name)
        else:
            objects_here.append(obj.name)

    var result = base
    if objects_here.size() > 0:
        result += "\n\nYou see: " + ", ".join(objects_here)
    if people_here.size() > 0:
        result += "\n\nPresent: " + ", ".join(people_here)

    return result
```

**Future Enhancement** (prose mode):
```gdscript
# Each object has .room_sentence property
garden_bench.set_property("room_sentence",
    "A weathered wooden bench sits beneath the willow tree.")
alice.set_property("room_sentence",
    "%n leans against the bench, reading a book.")

# Room composition
func compose_prose_description(location: WorldObject) -> String:
    var sentences = [location.get_property("description")]

    for obj in location.get_contents():
        if obj.has_property("room_sentence"):
            var sentence = obj.get_property("room_sentence")
            sentence = TextManager.substitute_pronouns(sentence, obj)
            sentences.append(sentence)

    return " ".join(sentences)

# Output:
# "A peaceful garden surrounds a gently swaying willow tree. A weathered wooden
#  bench sits beneath the willow tree. Alice leans against the bench, reading a book."
```

**Trade-offs**:
- (+) More literary, immersive prose
- (+) Encourages rich object descriptions
- (-) Harder to quickly scan for objects/people
- (-) Requires ALL objects to have good room_sentence descriptions
- (-) More complex composition logic

**Recommendation**:
- Implement **both modes** as a setting
- Default to **list mode** (current) for clarity
- Allow prose mode as experimental opt-in
- Let AI agents and players choose preference

### 5.5 Integration with Existing Systems

**TextManager** (already exists):
```gdscript
# Add pronoun substitution
static func substitute_pronouns(text: String, subject: WorldObject) -> String:
    # Implementation from Priority 1

# Add appearance composition
static func compose_appearance(obj: WorldObject, observer: WorldObject = null) -> String:
    return obj.get_full_description(observer)

# Add room composition
static func compose_room(location: WorldObject, observer: WorldObject, prose_mode: bool = false) -> String:
    if prose_mode:
        return compose_prose_description(location)
    else:
        return compose_list_description(location)
```

**WorldObject Extensions**:
```gdscript
# Add to WorldObject.gd
func get_full_description(observer: WorldObject = null) -> String:
    """Compose layered appearance from all sources."""
    # Implementation from Priority 2

func get_room_sentence() -> String:
    """Get one-sentence room description for prose composition."""
    if has_property("room_sentence"):
        return TextManager.substitute_pronouns(
            get_property("room_sentence"),
            self
        )
    return "%n is here." % {"n": name}
```

**Actor Component Integration**:
```gdscript
# Add to actor.gd
func get_visible_state() -> String:
    """Return visible state modifiers for appearance."""
    var states: Array[String] = []

    # Example state checks (placeholder for future systems)
    if owner.has_property("state.exhausted") and owner.get_property("state.exhausted"):
        states.append(TextManager.substitute_pronouns(
            "%s looks exhausted.",
            owner
        ))

    if states.size() > 0:
        return " ".join(states)
    return ""
```

---

## 6. Technical Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
- [ ] Implement `TextManager.substitute_pronouns()`
- [ ] Add `.gender` property to WorldObject
- [ ] Add custom `.pronouns` property support
- [ ] Update ALL player-facing text to use substitution
- [ ] Add `@set-gender` and `@set-pronouns` commands
- [ ] Update TextManager vault docs with pronoun codes

### Phase 2: Descriptions (Week 3-4)
- [ ] Implement `WorldObject.get_full_description()`
- [ ] Add layered composition (base + state)
- [ ] Update `examine` command to use new system
- [ ] Update `look` command to show composed descriptions
- [ ] Add `@set-description` enhancement for validation

### Phase 3: Room Integration (Week 5-6)
- [ ] Implement list-mode room composition (current style, but cleaner)
- [ ] Implement prose-mode room composition (experimental)
- [ ] Add `@room-mode` command to toggle between modes
- [ ] Update Location component to support both modes
- [ ] Test with AI agents to see which mode they prefer/understand better

### Phase 4: Body Language (Week 7-8)
- [ ] Add `body_language.*` property namespace
- [ ] Create `@set-gesture <name> -> <description>` command
- [ ] Update `emote` command to check for custom gestures
- [ ] Add gesture library to AI agent prompts
- [ ] Create default gesture sets for common actions

### Phase 5: Polish & Documentation (Week 9-10)
- [ ] Write player-facing help for all new features
- [ ] Create builder's guide for writing good descriptions
- [ ] Update ARCHITECTURE.md with new text systems
- [ ] Add examples to vault text files
- [ ] Performance testing and optimization

---

## 7. Example Text: Before & After

### Before (Current Miniworld):
```
> examine Alice

Alice
A thinker who contemplates the world.

> look

The Garden
A peaceful garden with a fountain.

You see: a stone bench
Also here: Alice, Bob
```

### After (Priority 1 + 2):
```
> examine Alice

Alice
A tall woman with thoughtful brown eyes and weathered hands. She moves
with deliberate care, as if weighing each step. Her dark hair is pulled
back in a practical bun, streaked with premature grey.

She looks tired but alert.

> look

The Garden
A peaceful garden surrounds a gently bubbling fountain, its stone basin
worn smooth by years of flowing water.

You see: a stone bench
Also here: Alice, Bob
```

### After (Priority 1 + 2 + 3 + 4 - Prose Mode):
```
> examine Alice

Alice
A tall woman with thoughtful brown eyes and weathered hands. She moves
with deliberate care, as if weighing each step. Her dark hair is pulled
back in a practical bun, streaked with premature grey.

She looks tired but alert.

Signature gestures:
- nod: nods slowly, eyes distant in thought
- wave: waves with a slight, economical motion
- smile: smiles faintly, corners of her eyes crinkling

> look

The Garden
A peaceful garden surrounds a gently bubbling fountain, its stone basin
worn smooth by years of flowing water. A weathered stone bench sits
beside the fountain, offering a place to rest. Alice leans against the
fountain's edge, trailing her fingers through the water thoughtfully.
Bob sits on the bench, reading a worn leather journal.

> emote nod
You nod slowly, eyes distant in thought.
Alice sees: Observer nods slowly, eyes distant in thought.
```

---

## 8. Open Questions & Future Research

### 8.1 Questions for Testing
- Do AI agents better understand **list** or **prose** room descriptions?
- Can AI agents effectively use custom gesture vocabulary?
- How much customization is "too much" before it becomes overwhelming?
- Does pronoun substitution actually improve AI agent text quality?

### 8.2 Areas for Further Research
- **Firan MUX**: May have had similar body language systems (needs more research)
- **Other Squidsoft features**: GalaxyWeb may have had other text innovations
- **Modern MOO descendants**: Check if any active MOOs have advanced these patterns
- **Sindome clothing system**: Deep dive into how coverage rules work technically

### 8.3 Potential Future Features
- **Mood/emotion layer**: Characters display current emotional state
- **Reputation layer**: Descriptions change based on observer's familiarity
- **Lighting/visibility**: Descriptions adapt to environmental conditions
- **Sensory modes**: Smell, sound, touch descriptions separate from visual
- **Memory-based descriptions**: AI agents remember and reference past appearances

---

## 9. References & Resources

### Active Games (Research Further)
- **Sindome**: https://www.sindome.org
  - Help system: https://www.sindome.org/help/
  - BabbleOn Manual: https://www.sindome.org/bgbb/development-discussion/script-development/babble-on-scripting-manual--part-1-7/
  - Appearance Guide: https://www.sindome.org/about/appearance/

### Archived Games (May Need Internet Archive)
- **GalaxyWeb: Stellar Epoch**: moo.squidsoft.net (offline)
  - Developer: https://web.squidsoft.net
- **Fortharlin**: (offline, minimal web presence)
  - Sister game to GalaxyWeb by Squidsoft

### Reference Documentation (Already in Miniworld)
- **LambdaMOO Programmer's Manual**: `reference_docs/LambdaMOO Programmer's Manual.md`
  - See sections on: string substitution, objects, properties

### Related MOO Resources
- **MOO Programming**: https://lisdude.com/moo/
- **MOO Games List**: https://moolist.com

---

## 10. Conclusion

The MOO/MUD text-based gaming tradition has developed sophisticated systems for dynamic, player-controlled text presentation. Key patterns worth adopting:

1. **Pronoun substitution** - Essential for flexible, inclusive text
2. **Layered descriptions** - Compose appearance from multiple sources
3. **Custom body language** - Character personality through gestures
4. **Prose integration** - Literary room descriptions (experimental)

These systems align well with Miniworld's goals:
- Support AI agents with rich, consistent text
- Enable player customization and self-expression
- Create immersive, literary virtual spaces
- Build on proven MOO/MUD design patterns

**Recommended Starting Point**: Implement Priority 1 (pronoun substitution) immediately, as it's foundational and relatively simple. Other priorities can be added incrementally based on testing and feedback.

---

*Document compiled from web research and LambdaMOO Programmer's Manual (January 2025)*
*For Miniworld project: MOO-inspired virtual world with AI agents in Godot 4.4*
