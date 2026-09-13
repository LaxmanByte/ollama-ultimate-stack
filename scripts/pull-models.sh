#!/bin/sh
# =============================================================================
# OLLAMA MODEL AUTO-PULLER
# Waits for Ollama, pulls the embedding model first (RAG), then chat models.
# Each pull retries up to 3 times. One failed model does not skip the rest.
# =============================================================================

echo "========================================"
echo "  OLLAMA MODEL AUTO-PULLER"
echo "========================================"
echo ""
echo "Waiting for Ollama service..."

MAX_RETRIES=60
RETRY_COUNT=0
OLLAMA_URL="${OLLAMA_HOST:-http://ollama:11434}"

wait_for_ollama() {
    if command -v curl >/dev/null 2>&1; then
        curl -sf "${OLLAMA_URL}/api/tags" >/dev/null 2>&1
        return $?
    fi
    ollama list >/dev/null 2>&1
}

while ! wait_for_ollama; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        echo "ERROR: Ollama service did not start within timeout"
        exit 1
    fi
    echo "  Waiting for Ollama... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

echo "Ollama is ready!"
echo ""

PRIMARY_MODEL="${PRIMARY_MODEL:-devstral:24b}"
RESEARCH_MODEL="${RESEARCH_MODEL:-deepseek-r1:14b}"
FALLBACK_MODEL="${FALLBACK_MODEL:-qwen2.5-coder:7b}"
EMBEDDING_MODEL="${EMBEDDING_MODEL:-nomic-embed-text}"

echo "Models to install:"
echo "  Primary Coding:       $PRIMARY_MODEL"
echo "  Research/Reasoning:   $RESEARCH_MODEL"
echo "  Fallback (Fast):      $FALLBACK_MODEL"
echo "  Embedding (RAG/docs): $EMBEDDING_MODEL"
echo ""

FAILED=0

pull_model() {
    model_name="$1"
    purpose="$2"
    echo "----------------------------------------"
    echo "[$purpose] Pulling: $model_name"
    echo "----------------------------------------"

    retry=0
    max_retry=3

    while [ "$retry" -lt "$max_retry" ]; do
        if ollama pull "$model_name"; then
            echo "SUCCESS: $model_name downloaded"
            echo ""
            return 0
        fi
        retry=$((retry + 1))
        echo "FAILED (attempt $retry/$max_retry), retrying in 10s..."
        sleep 10
    done

    echo "WARNING: Could not download $model_name after $max_retry attempts"
    echo ""
    return 1
}

# Embedding first so RAG/document chat works as soon as WebUI is used
if ! pull_model "$EMBEDDING_MODEL" "RAG/Document Analysis"; then
    FAILED=1
fi

if ! pull_model "$PRIMARY_MODEL" "Primary Coding"; then
    FAILED=1
fi

if ! pull_model "$RESEARCH_MODEL" "Research/Reasoning"; then
    FAILED=1
fi

if ! pull_model "$FALLBACK_MODEL" "Fast Fallback"; then
    FAILED=1
fi

echo "========================================"
if [ "$FAILED" -eq 0 ]; then
    echo "  ALL MODELS DOWNLOADED SUCCESSFULLY"
else
    echo "  DOWNLOAD FINISHED WITH WARNINGS"
    echo "  Re-run: docker compose run --rm model-puller"
fi
echo "========================================"
echo ""
echo "Installed models:"
ollama list || true
echo ""
echo "Web chat + file upload:  http://localhost:${WEBUI_PORT:-3000}"
echo "API endpoint:            http://localhost:${OLLAMA_PORT:-11434}"
echo ""

exit "$FAILED"
