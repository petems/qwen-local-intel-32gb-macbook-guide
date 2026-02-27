# qwen-local-intel-32gb-macbook-guide

A practical guide to running a local coding assistant on a 32GB Intel MacBook Pro.

## Your hardware and what it can do

A 32GB Intel MacBook **cannot run Qwen3-Coder-Next** — it's an 80B parameter model that needs 26GB+ even at the most aggressive quantization. But with 32GB, you can comfortably run 14B parameter models — a massive quality upgrade over the 7B class.

**What you're working with:**
- 32GB LPDDR4X RAM (~59.7 GB/s bandwidth)
- Intel i7-1068NG7 @ 2.3GHz, 4 cores / 8 threads
- **AVX-512 support** — gives ~10-20% speedup for quantized inference vs AVX2-only chips (notably, later Intel CPUs dropped AVX-512, so this is an advantage)
- NVMe SSD, macOS
- Realistic budget for the model: **20-24GB RAM** (OS + apps use ~8-12GB)

**What this means in practice:**
- You'll run **14B parameter models** comfortably — serious coding quality
- 7B models leave room for larger context windows or running alongside other apps
- Inference is CPU-bound: ~3-8 tok/s for 14B, ~8-15 tok/s for 7B
- Context windows: 8K-16K for 14B, 16K-32K for 7B
- Closing heavy apps (Chrome, Docker) helps at the margins but isn't a prerequisite

---

## Step 1: Install Ollama

Ollama is the easiest path. One install, one command to pull models, and it exposes an OpenAI-compatible API that both Aider and OpenCode can talk to.

```bash
# Download and install from https://ollama.com/download/mac
# Or via Homebrew:
brew install ollama

# Start the Ollama service (safe start — skips if already running)
if ! pgrep ollama >/dev/null 2>&1; then
  ollama serve &
  sleep 2
fi
```

Verify it's running:
```bash
curl http://localhost:11434/api/tags
```

**Useful Ollama commands:**
```bash
ollama list          # Show downloaded models and sizes
ollama ps            # Show currently loaded models (and VRAM/RAM usage)
ollama rm <model>    # Delete a model to free disk space
ollama stop <model>  # Unload a model from memory without deleting it
```

---

## Step 2: Pick and pull your models

### Primary: Qwen 2.5 Coder 14B (best local coding experience)

```bash
ollama pull qwen2.5-coder:14b
```

- **Size on disk:** ~9GB (Q4 quantized by default)
- **RAM usage:** ~12-14GB during inference (8K context)
- **Strengths:** Strong code generation, repair, and reasoning across 40+ languages. Meaningful quality jump over 7B.
- **Context:** 32K max, but 8K-16K is the sweet spot on your hardware

### Fast mode: Qwen 2.5 Coder 7B (quick iteration)

```bash
ollama pull qwen2.5-coder:7b
```

- **Size on disk:** ~4.7GB (Q4 quantized by default)
- **RAM usage:** ~6-8GB during inference
- **Strengths:** Nearly 2x the speed of 14B, good for rapid prototyping and simpler tasks
- **Context:** Can push to 16K-32K with RAM to spare

### Alternative: Qwen 3 14B (general-purpose + coding)

```bash
ollama pull qwen3:14b
```

- **Size on disk:** ~9.3GB
- **RAM usage:** ~12-14GB during inference
- **Strengths:** Broader general knowledge alongside coding; good if you want one model for everything

### Lightweight fallback: Qwen 3 4B

```bash
ollama pull qwen3:4b
```

- **Size on disk:** ~2.6GB
- **RAM usage:** ~4-5GB during inference
- **Strengths:** Very fast on CPU, minimal resource footprint
- **Trade-off:** Noticeably weaker on complex multi-file tasks

### Experimental: Qwen 3.5 35B-A3B (MoE — smaller than it sounds)

```bash
ollama pull qwen3.5:35b-a3b
```

- **Size on disk:** ~22GB (Q4_K_M)
- **RAM usage:** ~22-24GB during inference — fits in 32GB but leaves little headroom
- **Architecture:** 35B total parameters, but only **3B active** per token (Mixture of Experts)
- **Trade-off:** Fewer active parameters than the dense 14B means potentially less compute per token, but MoE gives access to a wider pool of specialized knowledge
- **Honest assessment:** MoE on CPU is largely uncharted territory for coding tasks. It _fits_ in 32GB, but whether it _outperforms_ the dense 14B for code is an open question. Benchmark both on your own workloads before committing.

### Quick comparison

| Model | Disk | RAM (8K ctx) | Speed (Intel i7) | Best for |
|-------|------|-------------|-------------------|----------|
| `qwen2.5-coder:14b` | ~9GB | ~12-14GB | 3-8 tok/s | **Primary** — serious coding, refactors, debugging |
| `qwen2.5-coder:7b` | ~4.7GB | ~6-8GB | 8-15 tok/s | Fast mode — quick iteration, simpler tasks |
| `qwen3:14b` | ~9.3GB | ~12-14GB | 3-8 tok/s | General-purpose alternative with coding ability |
| `qwen3.5:35b-a3b` | ~22GB | ~22-24GB | 2-5 tok/s | Experimental — MoE, wide knowledge, tight RAM fit |
| `qwen3:4b` | ~2.6GB | ~4-5GB | 15-25 tok/s | Lightweight fallback, battery-friendly |

**My pick:** Start with `qwen2.5-coder:14b` as your daily driver. Pull `qwen2.5-coder:7b` too for when you want faster responses on simpler tasks. Try `qwen3.5:35b-a3b` if you're curious about MoE — but benchmark it against the 14B before switching.

### Why not Qwen3-Coder (30B/80B MoE)?

You might see "only 3B active parameters" and think the MoE models would fit. They won't — **all** the weights (30B or 80B) must be loaded into RAM regardless of how many are "active" during inference. The 30B needs ~20GB+ and the 80B needs 50GB+. Stick with the dense 14B models (or the smaller 35B-A3B MoE above, which barely fits).

---

## Step 3: Choose your coding agent

### Option A: Aider

Terminal-based AI pair programming. Mature, well-tested, works great with local models.

```bash
# Install with uv (recommended — fast, isolated)
uv tool install aider-chat

# Or with the one-liner installer
curl -LsSf https://aider.chat/install.sh | sh
```

**Run with your local model:**

```bash
aider --model ollama_chat/qwen2.5-coder:14b
```

Aider will connect to Ollama on localhost automatically. You can start editing files right away — just add files to the chat and describe what you want changed.

**Useful flags:**

```bash
aider --model ollama_chat/qwen2.5-coder:14b \
      --no-auto-commits \
      --map-tokens 2048
```

- `--no-auto-commits` — Prevents automatic git commits (review changes yourself)
- `--map-tokens 2048` — Repo map budget; 2048 is a good balance with 14B's context capacity

**Suppress model warnings.** Aider doesn't know about local Ollama models and will warn about "Unknown context window size." Create `~/.aider.model.settings.yml` to fix this:

```yaml
- name: ollama_chat/qwen2.5-coder:14b
  edit_format: diff
  extra_params:
    num_ctx: 16384

- name: ollama_chat/qwen2.5-coder:7b
  edit_format: diff
  extra_params:
    num_ctx: 32768

- name: ollama_chat/qwen3:14b
  edit_format: diff
  extra_params:
    num_ctx: 16384

- name: ollama_chat/qwen3.5:35b-a3b
  edit_format: diff
  extra_params:
    num_ctx: 8192
```

This tells Aider the correct context window for each model and sets `diff` edit format (more token-efficient than the default `whole` format for local models).

### Option B: OpenCode

Newer terminal coding agent. Clean TUI, fast, works with Ollama.

```bash
# Install via Homebrew (recommended)
brew install anomalyco/tap/opencode

# Or via npm (requires Node.js 18+)
npm install -g @opencode/cli
```

**Configure for local models.** Create or edit `~/.config/opencode/opencode.jsonc`:

```jsonc
{
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "http://localhost:11434/v1"
      },
      "models": {
        // Primary — best coding quality
        "qwen2.5-coder:14b": {
          "name": "Qwen 2.5 Coder 14B",
          "limit": {
            "context": 16000,
            "output": 8000
          }
        },
        // Fast mode — quicker responses, simpler tasks
        "qwen2.5-coder:7b": {
          "name": "Qwen 2.5 Coder 7B (fast)",
          "limit": {
            "context": 24000,
            "output": 8000
          }
        }
      }
    }
  }
}
```

**Run it:**
```bash
opencode
```

### Option C: Pi (extensible coding agent)

Pi is a coding agent with built-in tool use (file editing, shell commands, web search) and a plugin system for extending its capabilities.

```bash
# Install via Homebrew
brew install pi-coding-agent

# Or via npm
npm install -g @mariozechner/pi-coding-agent
```

**Configure for Ollama.** Create `~/.pi/agent/models.json`:

```json
{
  "models": [
    {
      "id": "qwen2.5-coder:14b",
      "provider": "ollama",
      "baseUrl": "http://localhost:11434"
    },
    {
      "id": "qwen2.5-coder:7b",
      "provider": "ollama",
      "baseUrl": "http://localhost:11434"
    }
  ]
}
```

**Run it:**
```bash
pi
```

Pi gives you more control over the agent loop than Aider or OpenCode — useful if you want to customise tool behaviour or add your own integrations.

### Which one?

| | Aider | OpenCode | Pi |
|---|---|---|---|
| **Setup ease** | Simplest — one install, one command | Config file needed | Config file needed |
| **Maturity** | Very mature, large community | Newer, fast-moving | Newer, extensible |
| **Git integration** | Built-in auto-commits | Manual | Manual |
| **UI** | Clean terminal chat | Polished TUI with panels | Terminal chat + tools |
| **Local model support** | Excellent, one-liner | Good, needs config | Good, needs config |
| **Best for** | Pair programming, quick edits | Longer sessions, exploration | Custom workflows, extensibility |

**If you just want to get started fast:** Aider. One install, one command, done.

---

## Quick tasks with `llm` CLI

Not every question needs a full coding agent. Simon Willison's [`llm`](https://llm.datasette.io/) is a command-line tool for sending one-off prompts to any model — perfect for piping code, explaining errors, or generating commit messages.

```bash
# Install
brew install llm
llm install llm-ollama

# Use the 7B model for fast one-off tasks
llm -m qwen2.5-coder:7b "Explain what this function does" < src/utils.py

# Pipe in an error message
echo "TypeError: cannot unpack non-sequence NoneType" | llm -m qwen2.5-coder:7b "Explain this Python error and how to fix it"

# Generate a commit message from a diff
git diff --staged | llm -m qwen2.5-coder:7b "Write a concise git commit message for these changes"

# Quick code review
cat src/handler.py | llm -m qwen2.5-coder:7b "Review this code for bugs and suggest improvements"

# Generate docstrings
cat src/api.py | llm -m qwen2.5-coder:7b "Add docstrings to all functions in this Python file"
```

Use 7B for `llm` tasks — speed matters more than peak quality for one-liners, and 7B responds in seconds.

### Model naming across tools

Different tools use different naming conventions for the same Ollama models:

| Model | Aider | OpenCode / Pi / llm |
|-------|-------|---------------------|
| Qwen 2.5 Coder 14B | `ollama_chat/qwen2.5-coder:14b` | `qwen2.5-coder:14b` |
| Qwen 2.5 Coder 7B | `ollama_chat/qwen2.5-coder:7b` | `qwen2.5-coder:7b` |
| Qwen 3 14B | `ollama_chat/qwen3:14b` | `qwen3:14b` |
| Qwen 3.5 35B-A3B | `ollama_chat/qwen3.5:35b-a3b` | `qwen3.5:35b-a3b` |
| Qwen 3 4B | `ollama_chat/qwen3:4b` | `qwen3:4b` |

Aider requires the `ollama_chat/` prefix. All other tools use the bare Ollama model name.

---

## Step 4: Optimise for your hardware

With 32GB you have comfortable headroom, but these tweaks still improve the experience.

### Ollama environment variables

```bash
# Set number of CPU threads (match physical cores, not hyperthreads)
# Hyperthreads share execution units and don't help matrix math
# Check yours with: sysctl -n hw.physicalcpu
export OLLAMA_NUM_THREADS=4

# Only keep one model loaded at a time (default, saves RAM)
export OLLAMA_MAX_LOADED_MODELS=1

# Single inference stream
export OLLAMA_NUM_PARALLEL=1
```

Add these to your `~/.zshrc` to persist them.

**Advanced tip:** With 32GB, you _can_ load both 7B and 14B simultaneously (`OLLAMA_MAX_LOADED_MODELS=2`). This uses ~20GB for models alone, leaving ~12GB for everything else. Workable if you keep other apps light, and lets you quickly switch between fast/quality modes without reload delays.

### Verify AVX-512 is available

Your i7-1068NG7 supports AVX-512, which Ollama/llama.cpp uses automatically for faster quantized inference. Verify it's detected:

```bash
sysctl -a | grep -i avx
```

You should see `hw.optional.avx512f: 1` (among others). If this shows `0`, something is wrong with your CPU detection.

### Custom Modelfile tuning

You can create a custom Modelfile to set default context size and generation parameters:

```bash
cat <<'EOF' > Modelfile-qwen14b
FROM qwen2.5-coder:14b
PARAMETER num_ctx 12288
PARAMETER temperature 0.2
EOF

ollama create qwen2.5-coder:14b-custom -f Modelfile-qwen14b
```

Then use `qwen2.5-coder:14b-custom` in your agent. Lower temperature (0.1-0.3) tends to produce more reliable code output.

### Context window guidance

| Model | Comfortable context | Max practical | Notes |
|-------|-------------------|--------------|-------|
| 14B | 8K-12K | 16K | RAM usage scales with context; 16K pushes ~16-18GB |
| 7B | 16K-24K | 32K | Plenty of headroom at 7B sizes |
| 4B | 16K-32K | 32K | Minimal impact at this model size |

### Monitor memory usage

```bash
# See what's eating your memory
top -l 1 -s 0 | head -20
```

Closing Chrome, Docker, or Slack before heavy sessions can reclaim 1-3GB, which translates to more context window or smoother operation — but it's an optimisation, not a requirement.

### Swap file

macOS manages swap automatically. With an NVMe SSD, swap overflow won't be catastrophic — just slower. You shouldn't hit swap often with 32GB unless you're running very large context windows.

---

## Step 5: Test it works

### Quick smoke test with Ollama directly

```bash
ollama run qwen2.5-coder:14b "Write a Python function that finds duplicate files in a directory by comparing SHA256 hashes"
```

### Benchmark your speed

Measure actual tokens per second to validate expectations:

```bash
curl -s http://localhost:11434/api/generate -d '{
  "model": "qwen2.5-coder:14b",
  "prompt": "Write a Python async web scraper class with rate limiting, retry logic, and proper error handling.",
  "stream": false
}' | python3 -c "
import sys, json
r = json.load(sys.stdin)
ns = r['eval_duration']
tokens = r['eval_count']
tok_s = tokens / (ns / 1e9)
print(f'Generated {tokens} tokens in {ns/1e9:.1f}s = {tok_s:.1f} tok/s')
"
```

### Test with Aider

```bash
mkdir test-project && cd test-project
git init
echo "# Test" > README.md
git add -A && git commit -m "init"

aider --model ollama_chat/qwen2.5-coder:14b
# Then type: "Create a Python script that watches a folder for new images and resizes them to 800px wide"
```

### Test with OpenCode

```bash
cd test-project
opencode
# Use the TUI to ask for code changes
```

---

## What to expect (reality check)

**Speed:** 3-8 tokens/second for the 14B model, 8-15 tok/s for 7B. A simple function takes 10-30 seconds. A complex refactor might take a minute or two. This is comfortable for deliberate, thoughtful work.

**Quality:** The 14B model handles real coding tasks well — writing functions, debugging, adding tests, explaining code, and managing multi-file changes. It produces solid, usable output for the majority of day-to-day coding work. Think of it as a solid mid-level dev: reliable, competent, occasionally surprising you with something clever.

**When to fall back to cloud:** Local 14B handles most coding tasks well. Reach for a cloud model (e.g. `aider --model claude-sonnet-4-20250514`) when you need large-scale architecture planning, very long context (50K+ tokens), or cutting-edge knowledge about recent APIs/frameworks.

**Battery life:** Running inference on CPU is power-hungry. Expect noticeably reduced battery life during active use. Plug in if you can.

**Thermal throttling:** The 2020 13-inch MacBook Pro is known for heat issues under sustained CPU load. During long inference sessions, expect the fans to ramp up and turbo boost to drop from 3.8GHz toward the 2.3GHz base clock. A cooling pad or hard surface helps. This doesn't affect correctness — just speed. Real-world tok/s may trend toward the lower end of estimates during extended sessions.

---

## Troubleshooting

**"Ollama is slow to respond on first message"**
Normal. The model loads into RAM on first use. A 14B model takes 10-20 seconds to load. Subsequent messages are fast. Keep `OLLAMA_MAX_LOADED_MODELS=1` to avoid loading multiple models accidentally.

**"My Mac becomes unresponsive during inference"**
Unusual with 32GB — this likely means your context window is too large. Reduce `num_ctx` or check if you have another model loaded (`ollama ps`). Activity Monitor → Memory tab will show pressure.

**"Model is slower than expected"**
Check a few things:
1. **AVX-512:** Run `sysctl -a | grep avx512` — if you don't see `hw.optional.avx512f: 1`, the CPU isn't using its fastest instruction set
2. **Thread count:** Verify `OLLAMA_NUM_THREADS=4` (not 8 — hyperthreads hurt more than help)
3. **Thermal throttling:** Run `pmset -g thermlog` to check if the system is throttling. The 2020 13-inch chassis has limited thermal headroom
4. **Other models loaded:** Run `ollama ps` to check; unload extras with `ollama stop <model>`

**"Aider says model not found"**
Make sure Ollama is running (`ollama serve`) and the model is pulled (`ollama list` to check). The model name must match exactly including the tag.

**"OpenCode won't connect"**
Check the baseURL in your config points to `http://localhost:11434/v1` (note the `/v1`). Make sure Ollama is running.

**"Output quality is poor"**
Try being more specific in your prompts. Local models need clearer instructions than frontier models. Break complex requests into smaller steps. Also try lowering temperature (0.1-0.2) for more deterministic code output.

**"Thermal throttling / fans are loud"**
Expected under sustained load. Use a cooling pad or elevated stand, ensure vents aren't blocked, and work on a hard surface. For long sessions, the 7B model generates less heat than 14B.

---

## Links

- [Ollama](https://ollama.com) — Model runner
- [Aider](https://aider.chat) — AI pair programming
- [OpenCode](https://github.com/anomalyco/opencode) — Terminal coding agent
- [Pi](https://github.com/mariozechner/pi-coding-agent) — Extensible coding agent
- [llm CLI](https://llm.datasette.io/) — Command-line LLM tool by Simon Willison
- [Qwen 2.5 Coder 14B on Ollama](https://ollama.com/library/qwen2.5-coder:14b) — Primary recommended model
- [Qwen 2.5 Coder](https://ollama.com/library/qwen2.5-coder) — Model family page
- [Qwen 3.5 35B-A3B on Ollama](https://ollama.com/library/qwen3.5:35b-a3b) — Experimental MoE model
- [Original Qwen3-Coder-Next guide](https://dev.to/sienna/qwen3-coder-next-the-complete-2026-guide-to-running-powerful-ai-coding-agents-locally-1k95) — For when you upgrade your hardware

## Inspiration and Context

Inspired by the [Qwen3-Coder-Next guide](https://dev.to/sienna/qwen3-coder-next-the-complete-2026-guide-to-running-powerful-ai-coding-agents-locally-1k95), adapted for two devices I own in terms of Macbooks, this one for my older machine: 32GB RAM, an Intel i7 with AVX-512, and no Apple Silicon — but plenty capable of running 14B coding models that produce genuinely useful output.
