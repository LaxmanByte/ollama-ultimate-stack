# Ollama Ultimate Stack — type: make help
-include .env
export

PRIMARY_MODEL     ?= qwen2.5-coder:7b
RESEARCH_MODEL    ?= deepseek-r1:8b
FALLBACK_MODEL    ?= qwen2.5-coder:7b
EMBEDDING_MODEL   ?= nomic-embed-text
WEBUI_PORT        ?= 3000
OLLAMA_PORT       ?= 11434

.DEFAULT_GOAL := help

.PHONY: check up down chat chat-research chat-fast models ps status logs webui-logs \
	pull-coding pull-research pull-all update clean nuke info help stop restart

check: ## Hardware diagnostic (no Docker required)
	@bash scripts/check-hardware.sh

up: ## Start the entire AI stack
	docker compose up -d

down: ## Stop the entire AI stack
	docker compose down

stop: ## Stop services without removing containers
	docker compose stop

restart: ## Restart the stack
	docker compose restart

chat: ## Terminal chat with the primary coding model
	docker exec -it ollama ollama run $(PRIMARY_MODEL)

chat-research: ## Terminal chat with the research model
	docker exec -it ollama ollama run $(RESEARCH_MODEL)

chat-fast: ## Terminal chat with the fast fallback model
	docker exec -it ollama ollama run $(FALLBACK_MODEL)

models: ## List installed AI models
	docker exec ollama ollama list

ps: ## Show currently loaded models
	docker exec ollama ollama ps

status: ## Check if all services are running
	docker compose ps

logs: ## Follow Ollama logs
	docker compose logs -f ollama

webui-logs: ## Follow Open WebUI logs
	docker compose logs -f open-webui

pull-coding: ## Re-download / update the primary coding model
	docker exec ollama ollama pull $(PRIMARY_MODEL)

pull-research: ## Re-download / update the research model
	docker exec ollama ollama pull $(RESEARCH_MODEL)

pull-all: ## Update embedding + all chat models
	docker exec ollama ollama pull $(EMBEDDING_MODEL)
	docker exec ollama ollama pull $(PRIMARY_MODEL)
	docker exec ollama ollama pull $(RESEARCH_MODEL)
	docker exec ollama ollama pull $(FALLBACK_MODEL)

update: ## Pull latest stack files from GitHub, refresh images, recreate
	@if [ -x ./update.sh ]; then ./update.sh; else docker compose pull && docker compose up -d; fi

clean: ## Remove unused Docker data (keeps model + chat volumes)
	docker system prune -f

nuke: ## WARNING: deletes ALL models and chat history
	docker compose down -v

info: ## Print WebUI URL, API, upload steps, models, VS Code, Make commands
	@PRIMARY_MODEL=$(PRIMARY_MODEL) RESEARCH_MODEL=$(RESEARCH_MODEL) \
		FALLBACK_MODEL=$(FALLBACK_MODEL) EMBEDDING_MODEL=$(EMBEDDING_MODEL) \
		WEBUI_PORT=$(WEBUI_PORT) OLLAMA_PORT=$(OLLAMA_PORT) \
		sh scripts/print-info.sh

help: ## Show this help
	@echo ""
	@echo "Ollama Ultimate Stack"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'
	@echo ""
	@echo "Windows (no Make):  check-hardware.cmd   install.cmd   .\\update.ps1"
	@echo "WebUI: http://localhost:$(WEBUI_PORT)   API: http://localhost:$(OLLAMA_PORT)"
	@echo ""
