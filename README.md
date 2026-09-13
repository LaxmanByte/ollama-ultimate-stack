# Ollama Ultimate Stack

Free, self-hosted AI on your machine: **Ollama + Open WebUI + RAG + automatic model pull**.

No subscription. No API keys. No license key. Clone, run the installer, open a browser.

**WebUI:** http://localhost:3000  
**API:** http://localhost:11434

```text
Browser  →  Open WebUI (:3000)  →  Ollama (:11434)
                │                      │
                └── file upload / RAG  └── models from .env
                     (nomic-embed-text)
```

## Quick start

### Linux / macOS / WSL

```bash
git clone https://github.com/LaxmanByte/ollama-ultimate-stack.git
cd ollama-ultimate-stack
bash install.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/LaxmanByte/ollama-ultimate-stack.git
cd ollama-ultimate-stack
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer detects OS and RAM, installs Docker if missing, generates `WEBUI_SECRET_KEY`, enables the NVIDIA GPU overlay when `nvidia-smi` is present, starts the stack, and follows model downloads. First run is typically 15–60 minutes. After that, open http://localhost:3000.

## What you get

| Feature | How |
|---------|-----|
| Fast web chat | Open WebUI at http://localhost:3000 |
| File upload (PDF, Word, code, images) | **+** / paperclip in chat |
| Ask questions about documents (RAG) | Uses `nomic-embed-text` |
| Switch models mid-chat | Dropdown in WebUI |
| Code highlighting + markdown | Built into Open WebUI |
| Conversation history | Persistent Docker volume |
| Terminal chat | `make chat` / `make chat-research` / `make chat-fast` |
| VS Code editing | Continue + `continue-config.json` |
| Autonomous multi-file edits | VS Code Cline, Agent mode |

Default 16GB profile models (all open-weight, from `.env`):

| Model | Role |
|-------|------|
| `devstral:24b` | Primary coding |
| `deepseek-r1:14b` | Research / reasoning |
| `qwen2.5-coder:7b` | Fast fallback + tab autocomplete |
| `nomic-embed-text` | RAG embeddings |

## Hardware profiles

`install.sh` / `install.ps1` pick a profile from installed RAM. Override anytime:

```bash
cp profiles/8gb.env .env      # or 16gb.env / 32gb.env
# keep your WEBUI_SECRET_KEY / ports if you already set them
make update
```

| Profile | Primary | Research | Context |
|---------|---------|----------|---------|
| 8GB | `qwen2.5-coder:7b` | `deepseek-r1:8b` | 4k |
| **16GB (default)** | `devstral:24b` | `deepseek-r1:14b` | 16k |
| 32GB | `qwen3-coder:30b` | `deepseek-r1:32b` | 32k |

**Honest hardware notes**

- **8GB cannot run 24B.** The 8GB profile stays on 7B/8B models.
- **16GB default may struggle without a GPU.** CPU-only 16GB often swaps or is very slow on 24B.
- **Devstral 24B really wants ~32GB RAM or a 4090-class GPU.** If you have neither, use `profiles/8gb.env` or chat with `qwen2.5-coder:7b` (`make chat-fast`).

NVIDIA GPUs: if `nvidia-smi` exists, install enables `docker-compose.gpu.yml` automatically.

## File upload and RAG

**In the browser**

1. Open http://localhost:3000
2. Click **+** or the paperclip under the input
3. Attach PDF, `.docx`, `.txt`, `.md`, source files, or images
4. Ask: `Summarize this` or `What are the key findings?`

**Folder mounts**

- `./projects` → `/projects`
- `./uploads` → `/uploads`

Embedding model `nomic-embed-text` is pulled first so document chat works as soon as WebUI is up.

## Continue setup (VS Code)

1. Install [VS Code](https://code.visualstudio.com/) and the **Continue** extension
2. `Ctrl+Shift+P` → **Continue: Open Config.json**
3. Paste `continue-config.json` from this repo
4. Open a project folder → `Ctrl+L` → select `devstral:24b`
5. Highlight code, ask for a change, click **Apply**

Tab autocomplete uses `qwen2.5-coder:7b`. Custom commands: `/test`, `/fix`, `/explain`, `/refactor`, `/document`.

For agentic multi-file work, install **Cline**, provider **Ollama**, URL `http://localhost:11434`, model `devstral:24b`, mode **Agent**.

## Update a client (preserves `.env`)

```bash
# Linux / macOS / WSL
bash update.sh

# Windows
.\update.ps1
```

`update.sh` / `update.ps1` / `make update`:

1. `git pull --ff-only` (new compose, scripts, docs)
2. **Keeps that machine’s `.env`** (RAM profile, ports, secret)
3. `docker compose pull` + `docker compose up -d`

**Image-only auto-updates** (Ollama + Open WebUI, no git): in `.env` set:

```env
COMPOSE_PROFILES=auto-update
WATCHTOWER_POLL_INTERVAL=3600
```

Then `make update` once. Watchtower checks hourly (use `120` in a lab). Compose/script changes still need `update.sh` on the client.

## Commands

```text
make up              Start everything
make down            Stop everything
make chat            Terminal chat (coding model)
make chat-research   Terminal chat (research model)
make chat-fast       Terminal chat (fast model)
make models          List installed AI models
make ps              Show running models
make status          Check if services are running
make logs            View Ollama logs
make webui-logs      View WebUI logs
make pull-coding     Update coding model
make pull-research   Update research model
make pull-all        Update all models
make update          Git pull + image pull + recreate
make clean           Remove unused containers/images
make nuke            WARNING: delete all models and chat history
make info            Show connection URLs and guides
make help            Show all commands
```

Windows without Make: `.\install.ps1`, `.\update.ps1`, and `docker compose` as in [USAGE-GUIDE.md](USAGE-GUIDE.md).

## Requirements

- Docker + Docker Compose (installers handle this)
- 8GB+ RAM (16GB recommended; 32GB or a strong GPU for Devstral 24B)
- ~50GB disk for default models
- Internet for the first image + model download only

## Support

Need help installing? Contact [barrelaxman@gmail.com](mailto:barrelaxman@gmail.com) for remote setup services.

Remote setup (optional): $200 individuals / $500 business.

## License

MIT. Models have their own licenses (Apache 2.0, etc.). Open WebUI keeps its own branding.
