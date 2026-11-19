#!/usr/bin/env bash
# Writes /data/settings.json from environment variables, then runs the worker
# in the foreground (--daemon boot, no detach).
set -euo pipefail

: "${CLAUDE_MEM_LOCAL_API_TOKEN:?CLAUDE_MEM_LOCAL_API_TOKEN is required}"
: "${CLAUDE_MEM_WORKER_INGEST_TOKEN:?CLAUDE_MEM_WORKER_INGEST_TOKEN is required}"
: "${OLLAMA_MODEL:?OLLAMA_MODEL is required}"

mkdir -p /data
jq -n \
  --arg token "$CLAUDE_MEM_LOCAL_API_TOKEN" \
  --arg ingest "$CLAUDE_MEM_WORKER_INGEST_TOKEN" \
  --arg base "${OLLAMA_BASE_URL:-http://ollama:11434/v1}" \
  --arg model "$OLLAMA_MODEL" \
  '{
    CLAUDE_MEM_DATA_DIR: "/data",
    CLAUDE_MEM_WORKER_HOST: "0.0.0.0",
    CLAUDE_MEM_WORKER_PORT: "37777",
    CLAUDE_MEM_LOCAL_API_TOKEN: $token,
    CLAUDE_MEM_WORKER_INGEST_TOKEN: $ingest,
    CLAUDE_MEM_PROVIDER: "openai-compatible",
    CLAUDE_MEM_OPENAI_COMPAT_PRESET: "ollama",
    CLAUDE_MEM_OPENAI_COMPAT_BASE_URL: $base,
    CLAUDE_MEM_OPENAI_COMPAT_MODEL: $model,
    CLAUDE_MEM_OPENAI_COMPAT_API_KEY: "ollama",
    CLAUDE_MEM_QUOTA_FALLBACK_PROVIDER: "off",
    CLAUDE_MEM_AUTO_UPDATE: "false",
    CLAUDE_MEM_CHROMA_ENABLED: "false"
  }' > /data/settings.json
chmod 600 /data/settings.json

exec bun /opt/claude-mem/scripts/worker-service.cjs --daemon
