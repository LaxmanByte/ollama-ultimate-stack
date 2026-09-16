#!/bin/sh
# =============================================================================
# OLLAMA MODEL AUTO-PULLER
# Waits for Ollama, then downloads the well-known open models from .env.
# Embedding first, then chat models. Duplicate names are pulled once.
# Each pull retries up to 3 times. One failed model does not skip the rest.
# =============================================================================

echo "========================================"
echo "  OLLAMA MODEL AUTO-PULLER"
echo "========================================"
echo ""
echo "Leave this running. Large models take 15-60 minutes."
echo "You are done when you see: ALL MODELS DOWNLOADED SUCCESSFULLY"
echo ""
echo "Waiting for Ollama service..."

MAX_RETRIES=90
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
        echo "Start Docker, then re-run: docker compose run --rm model-puller"
        exit 1
    fi
    echo "  Waiting for Ollama... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

echo "Ollama is ready!"
echo ""

PRIMARY_MODEL="${PRIMARY_MODEL:-qwen2.5-coder:7b}"
RESEARCH_MODEL="${RESEARCH_MODEL:-deepseek-r1:8b}"
FALLBACK_MODEL="${FALLBACK_MODEL:-qwen2.5-coder:3b}"
EMBEDDING_MODEL="${EMBEDDING_MODEL:-nomic-embed-text}"

echo "Models to download (official Ollama library tags):"
echo "  Primary coding:       $PRIMARY_MODEL"
echo "  Research/reasoning:   $RESEARCH_MODEL"
echo "  Fast fallback:        $FALLBACK_MODEL"
echo "  Embeddings / files:   $EMBEDDING_MODEL"
echo ""

FAILED=0
PULLED=" "

pull_model() {
    model_name="$1"
    purpose="$2"

    if [ -z "$model_name" ]; then
        echo "SKIP: empty model name ($purpose)"
        return 0
    fi

    case "$PULLED" in
        *" $model_name "*)
            echo "----------------------------------------"
            echo "[$purpose] Already downloaded this run: $model_name"
            echo "----------------------------------------"
            echo ""
            return 0
            ;;
    esac

    echo "----------------------------------------"
    echo "[$purpose] Pulling: $model_name"
    echo "----------------------------------------"

    retry=0
    max_retry=3

    while [ "$retry" -lt "$max_retry" ]; do
        if ollama pull "$model_name"; then
            echo "SUCCESS: $model_name downloaded"
            echo ""
            PULLED="$PULLED$model_name "
            return 0
        fi
        retry=$((retry + 1))
        echo "FAILED (attempt $retry/$max_retry), retrying in 10s..."
        sleep 10
    done

    echo "WARNING: Could not download $model_name after $max_retry attempts"
    echo ""
    FAILED=1
    return 1
}

# Small embedding model first so file chat works as soon as WebUI is used
pull_model "$EMBEDDING_MODEL" "File search / embeddings"
pull_model "$PRIMARY_MODEL" "Primary coding"
pull_model "$RESEARCH_MODEL" "Research / reasoning"
pull_model "$FALLBACK_MODEL" "Fast fallback"

echo "========================================"
if [ "$FAILED" -eq 0 ]; then
    echo "  ALL MODELS DOWNLOADED SUCCESSFULLY"
    echo "  Open http://localhost:${WEBUI_PORT:-3000} and chat."
else
    echo "  DOWNLOAD FINISHED WITH WARNINGS"
    echo "  Re-run: docker compose run --rm model-puller"
fi
echo "========================================"
echo ""
echo "Installed models:"
ollama list || true
echo ""
echo "Web chat:  http://localhost:${WEBUI_PORT:-3000}"
echo "API:       http://localhost:${OLLAMA_PORT:-11434}"
echo ""

exit "$FAILED"
