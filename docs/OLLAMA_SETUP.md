# Ollama Setup for AI Agents

This guide will help you enable the AI agents (Eliza and Moss) to think and act autonomously using a local LLM.

## Overview

Miniworld uses **Shoggoth** (the LLM daemon) to communicate with **Ollama** running locally. AI agents will:
- Think every 12 seconds (minimum)
- Process one at a time (GPU constraint)
- React to observations in real-time
- Not be synchronized (async, naturally flowing turns)

---

## Installation

### 1. Install Ollama

**Windows/Mac/Linux:**
Visit https://ollama.ai and download the installer for your platform.

**Or via command line:**
```bash
# macOS/Linux
curl -fsSL https://ollama.ai/install.sh | sh

# Windows: Download from ollama.ai
```

### 2. Pull a Model

The default model is `mistral-small:24b` - a good balance of quality and speed.

```bash
ollama pull mistral-small:24b
```

**Alternative models:**
- `mistral:7b` - Faster, lighter (good for testing)
- `llama3:8b` - Fast, good quality
- `dolphin-mixtral:8x7b` - Creative, conversational
- `qwen2.5:14b` - Good reasoning

### 3. Verify Ollama is Running

```bash
# Test that Ollama is responding
curl http://localhost:11434/api/tags

# Should return JSON with list of models
```

---

## Configuration

### Default Settings

Shoggoth is configured in `user://shoggoth_config.cfg`:

```ini
[ollama]
host = "http://localhost:11434"
model = "mistral-small:24b"
temperature = 0.7
max_tokens = 2048
stop_tokens = []
```

### Changing the Model

**Option 1: Edit the config file**
Location: `%APPDATA%\Godot\app_userdata\Miniworld\shoggoth_config.cfg` (Windows)

```ini
model = "mistral:7b"  # Use a different model
```

**Option 2: Via code**
```gdscript
# In shoggoth.gd _create_default_config()
config.set_value("ollama", "model", "mistral:7b")
```

### Adjusting Think Speed

AI agents think every 12 seconds by default. To change:

```gdscript
# In Core/ai_agent.gd
return create("Eliza", profile, starting_location, 8.0)  # 8 seconds
```

Or after creation:
```gdscript
var thinker = agent.get_component("thinker")
thinker.set_think_interval(15.0)  # 15 seconds
```

---

## Testing

### 1. Start Ollama

Make sure Ollama is running in the background:

```bash
# It should auto-start on install, but if not:
ollama serve
```

### 2. Run Miniworld

```bash
# Open in Godot 4.4 and press F5
```

### 3. Check Console Output

You should see:
```
Shoggoth: Ollama client initialized
AI Agent created: Eliza (#4) at The Garden
AI Agent created: Moss (#5) at The Library
```

### 4. Meet the AI Agents

```
> @teleport The Garden
> look

# Wait ~12 seconds, Eliza should say/do something!
```

---

## How It Works

### Request Flow

```
ThinkerComponent (every 12s)
    ↓
Builds context (location, memories, occupants)
    ↓
Constructs prompt with personality
    ↓
Shoggoth.generate_async()
    ↓
Task queue (ensures one at a time)
    ↓
ollama_client.gd → HTTP POST to localhost:11434/api/chat
    ↓
Ollama processes on GPU (~2-10 seconds)
    ↓
Response: "COMMAND: say Hello!\nREASON: greeting newcomer"
    ↓
ThinkerComponent parses and executes
    ↓
ActorComponent.execute_command("say", ["Hello!"])
    ↓
EventWeaver broadcasts to room
    ↓
You see: "Eliza says, 'Hello!'"
```

### GPU Management

Shoggoth handles queueing automatically:
- AI agents request thinking whenever their timer expires
- Requests queue up if GPU is busy
- One inference at a time (GPU constraint)
- Responses come back asynchronously
- No strict turn synchronization

**Result:** Natural, flowing conversation where agents respond when ready, not in lockstep.

### Think Timer Behavior

Each agent has independent timer:
- Starts at 12 seconds
- Counts down each frame
- When ≤ 0: triggers thinking
- Resets to 12 seconds
- **Pauses while thinking** (prevents spam)

If LLM response takes 8 seconds:
- Total cycle: 12s wait + 8s processing = 20s between actions
- Next agent can start while first is processing

---

## Troubleshooting

### "Shoggoth: ollama_client.gd not found"

The client was created successfully - try reloading the project (Ctrl+R in Godot).

### "Connection refused" or "HTTP error"

Ollama isn't running:
```bash
ollama serve
```

### AI agents aren't doing anything

Check console for errors:
- Shoggoth initialization failures
- LLM request errors
- Parsing errors

Add debug output:
```gdscript
# In ThinkerComponent._think()
print("Agent %s is thinking..." % owner.name)
```

### Responses are gibberish

Model might not understand the format. Try:
- Using a different model (`llama3:8b` is reliable)
- Simplifying the prompt in `ThinkerComponent._construct_prompt()`
- Lowering temperature in config

### AI is too slow/fast

Adjust think interval:
```gdscript
# In Core/ai_agent.gd
create("Eliza", profile, location, 6.0)  # Faster
create("Moss", profile, location, 30.0)  # Slower
```

### GPU memory errors

Model too large:
```bash
# Use a smaller model
ollama pull mistral:7b
```

Update config to use it.

---

## Performance Tips

### Model Selection

| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| mistral:7b | 4.1GB | Fast | Good |
| llama3:8b | 4.7GB | Fast | Great |
| mistral-small:24b | 14GB | Medium | Excellent |
| mixtral:8x7b | 26GB | Slow | Excellent |

Choose based on your GPU memory.

### Response Length

Shorter = faster:
```gdscript
# In shoggoth config
max_tokens = 512  # Shorter responses
```

### Temperature

Higher = more creative but slower:
```ini
temperature = 0.5  # Faster, more predictable
temperature = 0.9  # Slower, more creative
```

---

## Advanced Configuration

### Custom System Prompt

Edit agent profiles in `Core/ai_agent.gd`:

```gdscript
var profile = """You are Eliza.

Keep responses under 20 words.
Always end with a question.
Use emotes frequently."""
```

### Multiple Models

Different agents can use different models (requires Shoggoth enhancement):

```gdscript
# Future: per-agent model selection
thinker.set_model("llama3:8b")
```

### Response Format

AI agents expect this format:
```
COMMAND: <command>
REASON: <explanation>
```

Modify parsing in `ThinkerComponent._on_thought_complete()` for different formats.

---

## What to Expect

### First Interaction

```
> @teleport The Garden

The Garden
A peaceful garden filled with flowers...

Also here:
• Eliza

[~12 seconds pass]

Eliza says, "Welcome to the garden! What brings you here today?"

> say I wanted to meet you!

You say, "I wanted to meet you!"

[~12 seconds]

Eliza says, "That's lovely! I'm always happy to meet new friends.
What would you like to talk about?"
```

### Natural Timing

- Agents think independently (not synchronized)
- Responses feel organic (12s minimum + processing time)
- Multiple agents can be processing at once (queued, but overlapping timers)
- No strict "turn order" - whoever finishes first acts first

### Observation & Memory

AI agents see everything:
- Your actions (say, emote, go)
- Other agents' actions
- Arrivals/departures

And remember:
- Recent events (last 5 by default)
- Their own actions
- Context of location

This creates continuity in conversations!

---

## Next Steps

Once AI agents are working:
1. Create more agents with diverse personalities
2. Experiment with think intervals for pacing
3. Build interesting locations for them to inhabit
4. Watch emergent interactions between multiple AI agents
5. Consider adding goals/tasks for agents to pursue

Have fun! 🤖✨
