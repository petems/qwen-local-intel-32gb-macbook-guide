#!/bin/bash
#
# check-compatibility.sh — Quick check for this Intel 32GB local coding setup.
# Run: ./check-compatibility.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

pass()  { printf "  ${GREEN}OK${RESET} %s\n" "$1"; }
warn()  { printf "  ${YELLOW}WARN${RESET} %s\n" "$1"; }
fail()  { printf "  ${RED}FAIL${RESET} %s\n" "$1"; }
info()  { printf "  ${BLUE}INFO${RESET} %s\n" "$1"; }
header(){ printf "\n${BOLD}%s${RESET}\n" "$1"; }

errors=0
warnings=0

header "Operating System"
if [[ "$(uname)" == "Darwin" ]]; then
  pass "macOS $(sw_vers -productVersion)"
else
  fail "Not macOS ($(uname))."
  exit 1
fi

header "Processor"
arch=$(uname -m)
chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")
physical_cores=$(sysctl -n hw.physicalcpu 2>/dev/null || echo "unknown")
logical_cores=$(sysctl -n hw.logicalcpu 2>/dev/null || echo "unknown")

if [[ "$arch" == "x86_64" ]]; then
  pass "Intel/x86_64 detected — $chip"
else
  warn "Architecture is $arch (this repo is tuned for Intel x86_64)."
  ((warnings+=1))
fi
info "Cores: ${physical_cores} physical / ${logical_cores} logical"

avx512=$(sysctl -n hw.optional.avx512f 2>/dev/null || echo 0)
if [[ "$avx512" == "1" ]]; then
  pass "AVX-512 available (good for quantized CPU inference)"
else
  warn "AVX-512 not detected; performance may be lower."
  ((warnings+=1))
fi

header "Memory"
ram_bytes=$(sysctl -n hw.memsize)
ram_gb=$((ram_bytes / 1073741824))

if [[ $ram_gb -ge 32 ]]; then
  pass "${ram_gb}GB RAM — target tier for this guide"
  info "Recommended: qwen2.5-coder:14b"
  info "Fast mode:   qwen2.5-coder:7b"
  ram_tier="target"
elif [[ $ram_gb -ge 24 ]]; then
  warn "${ram_gb}GB RAM — workable, but prefer 7B and lower context."
  info "Try: qwen2.5-coder:7b or qwen3:4b"
  ram_tier="reduced"
  ((warnings+=1))
else
  fail "${ram_gb}GB RAM — below practical target for the README defaults."
  info "Use smaller models (4B/7B) and lower context windows."
  ram_tier="low"
  ((errors+=1))
fi

header "Disk Space"
free_gb=$(df -g / | awk 'NR==2 {print $4}')
if [[ $free_gb -ge 25 ]]; then
  pass "${free_gb}GB free"
elif [[ $free_gb -ge 15 ]]; then
  warn "${free_gb}GB free — enough for 7B/14B, but limited headroom"
  ((warnings+=1))
else
  fail "${free_gb}GB free — likely insufficient for model downloads"
  ((errors+=1))
fi

header "Core Tools"
if command -v brew >/dev/null 2>&1; then
  pass "Homebrew installed ($(brew --version | head -1))"
else
  fail "Homebrew not found — install from https://brew.sh"
  ((errors+=1))
fi

if command -v ollama >/dev/null 2>&1; then
  pass "Ollama installed"
  if pgrep -x ollama >/dev/null 2>&1; then
    pass "Ollama is running"
    models=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
    if [[ -n "$models" ]]; then
      info "Installed Ollama models:"
      while IFS= read -r model; do
        [[ -n "$model" ]] && info "  $model"
      done <<< "$models"
    fi
  else
    warn "Ollama installed but not running (start with: ollama serve)"
    ((warnings+=1))
  fi
else
  warn "Ollama not installed (install with: brew install ollama)"
  ((warnings+=1))
fi

if command -v llama-server >/dev/null 2>&1; then
  pass "llama-server installed"
else
  info "llama-server not installed (optional: brew install llama.cpp)"
fi

if command -v node >/dev/null 2>&1; then
  node_version=$(node --version | sed 's/v//')
  node_major=$(echo "$node_version" | cut -d. -f1)
  if [[ $node_major -ge 18 ]]; then
    pass "Node.js $node_version"
  else
    warn "Node.js $node_version — need 18+ for OpenCode / Pi"
    ((warnings+=1))
  fi
else
  info "Node.js not installed (needed for OpenCode / Pi)"
fi

if command -v python3 >/dev/null 2>&1; then
  py_version=$(python3 --version | awk '{print $2}')
  py_major=$(echo "$py_version" | cut -d. -f1)
  py_minor=$(echo "$py_version" | cut -d. -f2)
  if [[ $py_major -eq 3 && $py_minor -ge 10 ]]; then
    pass "Python $py_version"
  else
    warn "Python $py_version — need 3.10+ for Aider / llm CLI"
    ((warnings+=1))
  fi
else
  info "Python 3 not installed (needed for Aider / llm CLI)"
fi

header "Coding Tools"
found_tool=false
for tool in aider opencode pi llm; do
  if command -v "$tool" >/dev/null 2>&1; then
    pass "$tool installed"
    found_tool=true
  fi
done
if [[ "$found_tool" == false ]]; then
  info "No coding tools installed yet — see README setup sections."
fi

header "Summary"
if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
  printf "  ${GREEN}${BOLD}Ready${RESET} for the Intel 32GB workflow.\n"
elif [[ $errors -eq 0 ]]; then
  printf "  ${YELLOW}${BOLD}Mostly ready${RESET} — %d warning(s).\n" "$warnings"
else
  printf "  ${RED}${BOLD}Not ready${RESET} — %d error(s), %d warning(s).\n" "$errors" "$warnings"
fi

echo ""
