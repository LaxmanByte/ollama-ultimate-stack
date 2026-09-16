# Ollama Ultimate Stack

Free ChatGPT-style AI on **your** computer: **Ollama** + **Open WebUI** + automatic download of well-known open models.

No account. No API key. No license key.  
**You do not need to know** whether you are on Windows, Mac, or Linux — or Intel vs Apple Silicon / ARM. Setup detects that and picks models that fit your RAM and GPU.

**When setup finishes:** open http://localhost:3000 and chat.

```text
You (browser)  →  Open WebUI (:3000)  →  Ollama (:11434)  →  models on disk
                      │
                      └── attach a PDF / file in chat (built into Open WebUI)
```

---

## You are done when

1. The setup window prints **`ALL MODELS DOWNLOADED SUCCESSFULLY`**
2. http://localhost:3000 opens
3. The model dropdown is **not empty** — type a message and send

Do not close the window during the first run (often **15–60 minutes**). Models are large.

---

## Setup

**Windows + Docker Desktop already running (easiest):** download the [ZIP](https://github.com/LaxmanByte/ollama-ultimate-stack/archive/refs/heads/main.zip), unzip, then in that folder:

```powershell
docker compose up -d ollama open-webui
docker compose run --rm model-puller
```

Or double-click **`start.cmd`**. If Smart App Control blocks the `.cmd` file, use the two PowerShell lines above. Do not use GitHub's `ghcr.io` Open WebUI image; this stack pulls **`openwebui/open-webui`** from Docker Hub.

**Mac / Linux / first-time Docker install:**

```bash
git clone https://github.com/LaxmanByte/ollama-ultimate-stack.git
cd ollama-ultimate-stack
```

| Your computer | What to run |
|---------------|-------------|
| **Windows** (no Docker yet) | Double-click **`setup.cmd`**, or `powershell -ExecutionPolicy Bypass -File .\setup.ps1` |
| **Mac / Linux / WSL** | `bash setup.sh` |

Setup will read RAM/GPU, pick models that fit, install Docker if needed, start the stack, and wait until models finish.

If Docker Desktop was just installed on Windows: open it, wait until the engine is running, then run **`start.cmd`** (or the two `docker compose` lines).

On Linux, if Docker was just installed: log out and back in (or reboot), then run `bash setup.sh` again.

### 3. Chat

Open **http://localhost:3000** → pick a model → send `Hello`.

---

## What gets downloaded

Well-known open models from the official [Ollama library](https://ollama.com/library) — whatever fits your machine, for example:

| Role | Typical tag |
|------|-------------|
| Fast on 16GB laptops | `qwen2.5-coder:3b` |
| Coding (most PCs) | `qwen2.5-coder:7b` |
| Research | `deepseek-r1:8b` (14B only with a real NVIDIA GPU) |
| Strong coding (32GB RAM or NVIDIA GPU) | `devstral:24b` or `qwen3-coder:30b` |
| File / PDF chat | `nomic-embed-text` |

**Honest limits:** 8GB and 16GB Docker laptops should use **3B** if chat is slow; 16GB without NVIDIA should not run 14B/24B; 32GB RAM or a 24GB-class NVIDIA GPU can. Docker Ollama on **Windows + AMD Radeon** is CPU-only — install [native Ollama](https://ollama.com/download), pause the Docker `ollama` container, keep Open WebUI.

---

## Use it

| You want | Do this |
|----------|---------|
| Chat | http://localhost:3000 |
| Ask about a PDF / Word / code file | Paperclip or **+** in chat → attach → ask |
| List models | `docker exec ollama ollama list` |
| Stop | `docker compose stop` |
| Start again later | `docker compose start` (no re-download) |

More detail: [USAGE-GUIDE.md](USAGE-GUIDE.md).

---

## Update later

Same idea — one command for your machine:

```bash
# Mac / Linux / WSL
bash update.sh

# Windows PowerShell
.\update.ps1
```

Keeps your `.env`. Does not delete models.

If a download failed mid-way:

```bash
docker compose run --rm model-puller
```

---

## Commands (optional)

```text
start.cmd / docker compose  Windows when Docker is already running
bash setup.sh / setup.cmd   Full first-time setup (installs Docker if needed)
make check                  Hardware diagnostic only
make up / make down         Start / stop
make models                 List models
make update                 Refresh from GitHub + images
make info                   URLs and tips
```

---

## Requirements

- About **8GB+ RAM** (16GB nicer)
- About **20–50GB** free disk (depends on models)
- Internet **once** for Docker images + models  
- After that, everything stays on your machine

---

## Need help?

| Path | Notes |
|------|-------|
| Free DIY | ZIP or clone → `start.cmd` / `docker compose` / `bash setup.sh` → wait for models → http://localhost:3000 |
| [GitHub Issues](https://github.com/LaxmanByte/ollama-ultimate-stack/issues) | Bugs and install failures |
| Email [support@gridvoxsystems.com](mailto:support@gridvoxsystems.com) | Short questions |
| **[Remote setup (paid)](docs/remote-setup.html)** | Fixed quote after a short hardware & privacy check (no listed sticker price) |

The stack stays **free and MIT**. Paid help is a human on screen-share, not a software license. Open WebUI branding stays. You are not buying Ollama or Open WebUI.

A GUI one-click installer (no typing) is on the roadmap — not for sale yet. Waitlist: email [support@gridvoxsystems.com](mailto:support@gridvoxsystems.com) with subject **one-click waitlist**.

## License

MIT. Models have their own licenses. Open WebUI keeps its own branding.
