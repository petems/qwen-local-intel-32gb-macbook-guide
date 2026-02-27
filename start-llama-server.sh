#!/bin/bash
#
# start-llama-server.sh — Start llama-server with Intel-friendly defaults.
# Run: ./start-llama-server.sh
#
# Overrides:
#   PORT=9090 ./start-llama-server.sh
#   MODEL_VARIANT=7b ./start-llama-server.sh
#   CTX_SIZE=8192 THREADS=4 BATCH_SIZE=256 UBATCH_SIZE=64 ./start-llama-server.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { printf "  ${GREEN}OK${RESET} %s\n" "$1"; }
warn() { printf "  ${YELLOW}WARN${RESET} %s\n" "$1"; }
fail() { printf "  ${RED}FAIL${RESET} %s\n" "$1"; }
info() { printf "  ${BLUE}INFO${RESET} %s\n" "$1"; }

PORT="${PORT:-8080}"
HOST="${HOST:-127.0.0.1}"
MODEL_VARIANT="${MODEL_VARIANT:-14b}"

printf "\n${BOLD}Preparing llama-server config...${RESET}\n\n"

if [[ "$(uname)" != "Darwin" ]]; then
  fail "Not macOS ($(uname))."
  exit 1
fi

arch=$(uname -m)
if [[ "$arch" != "x86_64" ]]; then
  warn "Architecture is $arch; this script is tuned for Intel x86_64."
else
  pass "Intel/x86_64 detected"
fi

if ! command -v llama-server >/dev/null 2>&1; then
  fail "llama-server not found. Install with: brew install llama.cpp"
  exit 1
fi
pass "llama-server installed"

if lsof -i ":$PORT" >/dev/null 2>&1; then
  fail "Port $PORT is already in use"
  info "Check: lsof -i :$PORT"
  exit 1
fi
pass "Port $PORT is free"

physical_cores=$(sysctl -n hw.physicalcpu 2>/dev/null || echo 4)
THREADS="${THREADS:-$physical_cores}"

# Pick model + defaults aligned with README guidance.
case "$MODEL_VARIANT" in
  14b)
    MODEL_HF="${MODEL_HF:-bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:Q4_K_M}"
    CTX_SIZE="${CTX_SIZE:-12288}"
    BATCH_SIZE="${BATCH_SIZE:-256}"
    UBATCH_SIZE="${UBATCH_SIZE:-64}"
    ;;
  7b)
    MODEL_HF="${MODEL_HF:-bartowski/Qwen2.5-Coder-7B-Instruct-GGUF:Q4_K_M}"
    CTX_SIZE="${CTX_SIZE:-16384}"
    BATCH_SIZE="${BATCH_SIZE:-512}"
    UBATCH_SIZE="${UBATCH_SIZE:-128}"
    ;;
  35b-a3b)
    MODEL_HF="${MODEL_HF:-unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M}"
    CTX_SIZE="${CTX_SIZE:-8192}"
    BATCH_SIZE="${BATCH_SIZE:-128}"
    UBATCH_SIZE="${UBATCH_SIZE:-32}"
    warn "Using experimental 35B-A3B profile on 32GB Intel; keep other apps closed."
    ;;
  *)
    fail "Unknown MODEL_VARIANT='$MODEL_VARIANT' (use: 14b, 7b, 35b-a3b)"
    exit 1
    ;;
esac

N_GPU_LAYERS="${N_GPU_LAYERS:-0}"
if [[ "$N_GPU_LAYERS" != "0" ]]; then
  warn "Intel iGPU offload is usually not useful; recommended N_GPU_LAYERS=0"
fi

printf "\n${BOLD}Configuration:${RESET}\n"
info "Model:       $MODEL_HF"
info "Variant:     $MODEL_VARIANT"
info "Context:     $CTX_SIZE"
info "Threads:     $THREADS"
info "Batch:       $BATCH_SIZE"
info "Ubatch:      $UBATCH_SIZE"
info "GPU layers:  $N_GPU_LAYERS"
info "Endpoint:    http://$HOST:$PORT/v1"

free_gb=$(df -g / | awk 'NR==2 {print $4}')
if [[ $free_gb -lt 15 ]]; then
  warn "Only ${free_gb}GB free disk space; model download may fail"
fi

printf "\n${BOLD}Starting llama-server...${RESET}\n"
info "Press Ctrl+C to stop."

exec llama-server \
  -hf "$MODEL_HF" \
  --ctx-size "$CTX_SIZE" \
  --threads "$THREADS" \
  --batch-size "$BATCH_SIZE" \
  --ubatch-size "$UBATCH_SIZE" \
  --n-gpu-layers "$N_GPU_LAYERS" \
  --host "$HOST" \
  --port "$PORT"
