# Ollama Ultimate Stack — usage guide

Step-by-step for chat, files, RAG, Continue, Cline, and troubleshooting. Everything is local. No API keys. No license activation.

**Order:** unzip or clone → start Docker → wait for **`ALL MODELS DOWNLOADED SUCCESSFULLY`** → open http://localhost:3000. Models stay on disk; the next start does not download them again.

| Machine | Run |
|---------|-----|
| Windows (Docker already running) | `start.cmd` or the two `docker compose` lines in SETUP.txt |
| Windows (no Docker yet) | `setup.cmd` or `powershell -ExecutionPolicy Bypass -File .\setup.ps1` |
| Mac / Linux / WSL | `bash setup.sh` |

You do not need to know Intel vs ARM or which model to pick. Setup will not overwrite a custom `.env`.

Advanced (optional): `check-hardware.cmd` / `bash check-hardware.sh` alone, then `install.cmd` / `bash install.sh`.

Need a human to install it on a screen-share? See [docs/remote-setup.html](docs/remote-setup.html) for a fixed quote after a short hardware check, or email [support@gridvoxsystems.com](mailto:support@gridvoxsystems.com).

---

## 1. Chat

### Web (recommended)

1. Open http://localhost:3000
2. Choose a model in the dropdown (whatever this machine downloaded — often `qwen2.5-coder:7b`)
3. Type and send
4. History is saved automatically (Docker volume `open_webui_data`)

First install waits until models are fully downloaded. If the dropdown is empty, run `docker compose run --rm model-puller`, wait for **ALL MODELS DOWNLOADED SUCCESSFULLY**, then refresh.

### Terminal

```bash
make chat            # coding — devstral:24b
make chat-research   # reasoning — deepseek-r1:14b
make chat-fast       # quick — qwen2.5-coder:7b
```

Windows without Make:

```powershell
docker exec -it ollama ollama run devstral:24b
```

### API

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "devstral:24b",
  "prompt": "Write a Python function to reverse a string",
  "stream": false
}'
```

OpenAI-compatible:

`http://localhost:11434/v1`

---

## 2. File upload

1. Go to http://localhost:3000
2. Start a chat
3. Click **+** or the paperclip under the box
4. Select PDF, Word, text, markdown, source, or images
5. Ask a question about **that file**

Examples:

- `Summarize this PDF in 10 bullets`
- `Find the bug in this Python file`
- `Extract every deadline from this contract`

**Mounted folders** (visible inside the stack):

```text
./projects  →  /projects
./uploads   →  /uploads
```

```bash
mkdir -p projects uploads
cp report.pdf uploads/
cp -r my-app projects/
```

Then mention `/uploads/report.pdf` or `/projects/my-app` in chat.

---

## 3. Document research (RAG)

Embedding model `nomic-embed-text` is pulled first so document chat works as soon as WebUI is up.

1. Upload one or more documents (or put them in `uploads/`)
2. Ask grounded questions: `What methodology did they use?`
3. Upload several files and compare: `Compare the architecture in these two PDFs`

Chunking (edit `.env`, then `make update`):

| RAM | `CHUNK_SIZE` | `RAG_TOP_K` |
|-----|--------------|-------------|
| 8GB | 500 | 3 |
| 16GB | 1000 | 5 |
| 32GB | 1500 | 8 |

If answers ignore the PDF, raise `OLLAMA_CONTEXT_LENGTH` (16k+ is recommended for documents).

Deep reasoning in the terminal:

```bash
make chat-research
```

---

## 4. Code editing (VS Code + Continue)

Continue talks to local Ollama and can **apply** edits to files.

1. Install [VS Code](https://code.visualstudio.com/)
2. Extensions → search **Continue** → Install
3. `Ctrl+Shift+P` (Mac: `Cmd+Shift+P`) → **Continue: Open Config.json**
4. Replace the file with `continue-config.json` from this repo → Save
5. **File → Open Folder** (a folder, not a single file)
6. `Ctrl+L` / `Cmd+L` to open chat
7. Select **Ollama - devstral (Coding)**
8. Highlight code → ask for a change → click **Apply**

Custom commands (slash or command palette):

| Command | What it does |
|---------|----------------|
| `/test` | Unit tests for the selection |
| `/fix` | Find and fix bugs / security / perf |
| `/explain` | Teach the selected code |
| `/refactor` | Clean up without changing behavior |
| `/document` | Docstrings and comments |

Tab autocomplete uses `qwen2.5-coder:7b`.

Context: `@file path`, `@folder`, `@codebase`, `@diff`.

---

## 5. Autonomous editing (Cline Agent)

Cline can read many files, write new ones, and show diffs for approval.

1. VS Code → Extensions → **Cline**
2. Cline icon → settings
3. Provider: **Ollama**
4. Base URL: `http://localhost:11434`
5. Model: `devstral:24b`
6. Mode: **Agent**
7. Prompt, for example: `Read the repo and add input validation to the main entrypoint`

Review every diff. Reject what you do not want.

Examples:

- `Add JWT auth with login and register`
- `Find every TODO and implement it`
- `Convert callback-style JS to async/await`

---

## 6. Bug fixing

**Continue (one function or file)**

1. Open the file, select the broken code
2. `Ctrl+L`
3. `This throws TypeError on empty input. Fix it.`
4. Apply the patch

**Cline (unknown cause)**

1. Agent mode
2. `Tests fail with X. Reproduce, explain, and fix.`
3. Approve file changes

**WebUI**

Upload the file and ask `Find the bug and show a corrected version` (copy the result back yourself).

---

## 7. Test generation

1. Select a function in VS Code
2. Continue command **test** / `/test`
3. Or Cline: `Write pytest coverage for src/app.py including edge cases`

Keep tests in the project’s real test folder so they run with the existing runner.

---

## 8. Project analysis

**Continue**

```text
@workspace What is the architecture of this project?
@workspace Find security issues in auth and file upload
@file src/db.py Explain the query layer
```

**WebUI + folders**

Copy the project into `projects/`, then ask about `/projects/<name>`.

**Research then implement**

1. WebUI + `deepseek-r1:14b`: research the approach
2. Cline + `devstral:24b`: implement it in the repo

---

## 9. Updating other computers

Operator (where you edit this repo):

```bash
git add -A
git commit -m "Your change"
git push
```

Each client:

```bash
bash update.sh          # Linux / macOS / WSL
.\update.ps1            # Windows
```

Local `.env` (RAM, ports, secret) is **not** overwritten. New images are pulled. For hourly image updates without git, set `COMPOSE_PROFILES=auto-update` in that client’s `.env`.

New machine:

```bash
git clone https://github.com/LaxmanByte/ollama-ultimate-stack.git
cd ollama-ultimate-stack
bash scripts/check-hardware.sh    # Windows: .\check-hardware.ps1
bash install.sh                   # Windows: .\install.ps1
```

---

## 10. Troubleshooting

### Cannot connect from VS Code / Continue / Cline

```bash
docker compose ps
curl http://localhost:11434
```

URL must be `http://localhost:11434` (no extra path required for native Ollama; `/v1` is optional for OpenAI-compatible clients).

### Empty model list in WebUI

Downloads still running:

```bash
docker compose logs -f model-puller
make models
```

Re-pull:

```bash
docker compose run --rm model-puller
# or
make pull-all
```

### Out of memory / 24B will not load

- **8GB cannot run 24B.** Copy `profiles/8gb.env` to `.env` and `make update`.
- **16GB without NVIDIA** should use `qwen2.5-coder:3b` (fast) or `qwen2.5-coder:7b` (heavier). Do not pull 14B/24B.
- **Devstral 24B** wants ~32GB RAM or a 4090-class GPU.
- Lower `OLLAMA_CONTEXT_LENGTH` to `4096`
- Close other apps; on Linux add swap if needed

### Slow first download

`devstral:24b` is ~14GB. Use `make chat-fast` until the large models finish.

### Continue cannot see files

Open a **folder** (`File → Open Folder`), not a loose file.

### Chat is very slow (16GB Windows laptop)

Use **`qwen2.5-coder:3b`**, not 7B or DeepSeek. Unload the big model: `docker exec ollama ollama stop qwen2.5-coder:7b`. Pause other stacks (LexRAG/appliance) while testing. On **AMD Radeon**, Docker Ollama cannot use the iGPU — pause the Docker `ollama` container, install [native Ollama](https://ollama.com/download), keep Open WebUI, refresh http://localhost:3000. Do not run Hub `ollama/ollama:rocm` on Windows (that image is Linux).

### Pull access denied / registry denied (Open WebUI)

```powershell
docker logout ghcr.io
docker compose pull
docker compose up -d ollama open-webui
```

This stack uses Docker Hub `openwebui/open-webui` (not `open-webui/open-webui` and not GHCR).

### Smart App Control / "file may be unsafe"

Do not double-click `setup.cmd`. Open PowerShell in the unzipped folder:

```powershell
docker compose up -d ollama open-webui
docker compose run --rm model-puller
```

### GPU not used

Linux/WSL2: NVIDIA driver + NVIDIA Container Toolkit. Re-run install so `docker-compose.gpu.yml` is attached. Docker on macOS typically does **not** pass Apple GPU into Linux containers; native Ollama is better for Metal. Windows AMD: native Ollama, not the ROCm Docker tag.

### Port 3000 or 11434 busy

Change `WEBUI_PORT` / `OLLAMA_PORT` in `.env`, then `docker compose up -d`.

### Reset everything (destroys models and chats)

```bash
make nuke
```

### Docker not running (Windows)

Start **Docker Desktop**, wait until the engine is running, then `.\install.ps1` or `.\update.ps1`.

---

## Command cheat sheet

```bash
make up
make down
make status
make logs
make models
make pull-all
make update
make info
```

Windows equivalents:

```powershell
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f ollama
docker exec ollama ollama list
.\update.ps1
```

## Support

- Free DIY: [README setup](README.md) — `setup.cmd` / `bash setup.sh`
- Stuck? Email [support@gridvoxsystems.com](mailto:support@gridvoxsystems.com)
- Paid remote setup (screen-share until first chat): [docs/remote-setup.html](docs/remote-setup.html) — fixed quote after hardware & privacy check

You are not buying Ollama or Open WebUI. Those stay free. Open WebUI branding stays.
