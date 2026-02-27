#!/bin/bash
#
# setup-llm-local.sh — Configure Simon Willison's llm CLI for local llama-server.
# Run: ./setup-llm-local.sh
# Optional args: ./setup-llm-local.sh [port] [model_id_alias] [model_name]

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

PORT="${1:-8080}"
MODEL_ID="${2:-qwen-local}"
MODEL_NAME="${3:-qwen2.5-coder-14b}"
LLM_DIR="$HOME/Library/Application Support/io.datasette.llm"
YAML_FILE="$LLM_DIR/extra-openai-models.yaml"

printf "\n${BOLD}Setting up llm CLI for local llama-server${RESET}\n\n"

if ! command -v llm >/dev/null 2>&1; then
  fail "llm CLI not found. Install with: brew install llm"
  exit 1
fi
pass "llm CLI found"

if curl -fsS "http://localhost:$PORT/v1/models" >/dev/null 2>&1; then
  pass "llama-server responding on port $PORT"
  detected=$(curl -fsS "http://localhost:$PORT/v1/models" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  if [[ -n "$detected" ]]; then
    MODEL_NAME="$detected"
    info "Detected model: $MODEL_NAME"
  fi
else
  warn "llama-server not responding on port $PORT (writing config anyway)"
fi

mkdir -p "$LLM_DIR"

ENTRY="- model_id: $MODEL_ID
  model_name: $MODEL_NAME
  api_base: \"http://localhost:$PORT/v1\""

if [[ -f "$YAML_FILE" ]]; then
  if grep -q "model_id: $MODEL_ID" "$YAML_FILE"; then
    warn "Model alias '$MODEL_ID' already exists in $YAML_FILE"
    read -rp "  Overwrite this alias? [y/N] " answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
      info "No changes made."
      exit 0
    fi

    tmp=$(mktemp)
    awk -v id="$MODEL_ID" '
      BEGIN { skipping=0 }
      /^- model_id:/ {
        if ($0 ~ "model_id: " id "$") { skipping=1; next }
        if (skipping==1) { skipping=0 }
      }
      skipping==0 { print }
    ' "$YAML_FILE" > "$tmp"
    mv "$tmp" "$YAML_FILE"
  fi
  printf "%s\n" "$ENTRY" >> "$YAML_FILE"
  pass "Updated $YAML_FILE"
else
  printf "%s\n" "$ENTRY" > "$YAML_FILE"
  pass "Created $YAML_FILE"
fi

printf "\n${BOLD}Config written:${RESET}\n"
sed 's/^/    /' "$YAML_FILE"

printf "\n${BOLD}Usage:${RESET}\n"
info "llm -m $MODEL_ID \"Write a Python function to reverse a linked list\""
info "git diff | llm -m $MODEL_ID -s \"Write a concise conventional commit message\""
printf "\n"
