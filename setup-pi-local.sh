#!/bin/bash
#
# setup-pi-local.sh — Configure Pi for local Ollama and/or llama-server.
# Run: ./setup-pi-local.sh

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { printf "  ${GREEN}OK${RESET} %s\n" "$1"; }
warn() { printf "  ${YELLOW}WARN${RESET} %s\n" "$1"; }
fail() { printf "  ${RED}FAIL${RESET} %s\n" "$1"; }
info() { printf "  ${BLUE}INFO${RESET} %s\n" "$1"; }

LLAMA_PORT="${LLAMA_PORT:-8080}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
PI_DIR="$HOME/.pi/agent"
MODELS_FILE="$PI_DIR/models.json"

printf "\n${BOLD}Setting up Pi for local models${RESET}\n\n"

if ! command -v pi >/dev/null 2>&1; then
  fail "Pi not found. Install with: brew install pi-coding-agent"
  exit 1
fi
pass "Pi available"

ram_bytes=$(sysctl -n hw.memsize)
ram_gb=$((ram_bytes / 1073741824))
pass "Detected RAM: ${ram_gb}GB"

if [[ $ram_gb -ge 32 ]]; then
  llama_ctx=12288
else
  llama_ctx=8192
fi

providers=""
usage_lines=""

if curl -fsS "http://localhost:$LLAMA_PORT/v1/models" >/dev/null 2>&1; then
  detected=$(curl -fsS "http://localhost:$LLAMA_PORT/v1/models" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  llama_model_id="${detected:-qwen2.5-coder-14b}"

  pass "llama-server responding on port $LLAMA_PORT"
  info "llama-server model id: $llama_model_id"

  providers="\"llama-server\": {
      \"baseUrl\": \"http://localhost:$LLAMA_PORT/v1\",
      \"api\": \"openai-completions\",
      \"apiKey\": \"local\",
      \"models\": [
        { \"id\": \"$llama_model_id\", \"contextWindow\": $llama_ctx, \"maxTokens\": 4096 }
      ]
    }"
  usage_lines="${usage_lines}pi --model llama-server/$llama_model_id\n"
else
  info "llama-server not responding on port $LLAMA_PORT (skipping)"
fi

if curl -fsS "http://localhost:$OLLAMA_PORT/v1/models" >/dev/null 2>&1; then
  pass "Ollama responding on port $OLLAMA_PORT"

  ollama_models=""
  if command -v ollama >/dev/null 2>&1; then
    while IFS= read -r model_name; do
      [[ -z "$model_name" ]] && continue
      ollama_models="${ollama_models}${ollama_models:+,\n        }{ \"id\": \"$model_name\" }"
      usage_lines="${usage_lines}pi --model ollama/$model_name\n"
    done < <(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
  fi

  if [[ -z "$ollama_models" ]]; then
    ollama_models="{ \"id\": \"qwen2.5-coder:14b\" },
        { \"id\": \"qwen2.5-coder:7b\" }"
    usage_lines="${usage_lines}pi --model ollama/qwen2.5-coder:14b\n"
    usage_lines="${usage_lines}pi --model ollama/qwen2.5-coder:7b\n"
  fi

  if [[ -n "$providers" ]]; then
    providers="${providers},\n    "
  fi

  providers="${providers}\"ollama\": {
      \"baseUrl\": \"http://localhost:$OLLAMA_PORT/v1\",
      \"api\": \"openai-completions\",
      \"apiKey\": \"ollama\",
      \"models\": [
        $ollama_models
      ]
    }"
else
  info "Ollama not responding on port $OLLAMA_PORT (skipping)"
fi

if [[ -z "$providers" ]]; then
  fail "No local model servers found. Start Ollama or llama-server first."
  info "Ollama: ollama serve"
  info "llama-server: ./start-llama-server.sh"
  exit 1
fi

mkdir -p "$PI_DIR"

if [[ -f "$MODELS_FILE" ]]; then
  warn "Existing $MODELS_FILE found"
  read -rp "  Overwrite? [y/N] " answer
  if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    info "No changes made."
    exit 0
  fi
fi

cat > "$MODELS_FILE" <<EOF2
{
  "providers": {
    $providers
  }
}
EOF2

pass "Written $MODELS_FILE"

printf "\n${BOLD}Verify:${RESET}\n"
info "pi --list-models"

printf "\n${BOLD}Usage:${RESET}\n"
printf "%b" "$usage_lines" | while IFS= read -r line; do
  [[ -n "$line" ]] && info "$line"
done
printf "\n"
