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

## Setup (one path)

### 1. Clone

Install [Git](https://git-scm.com/downloads) if you need it, then:

```bash
git clone https://github.com/LaxmanByte/ollama-ultimate-stack.git
cd ollama-ultimate-stack
```

### 2. Run setup (auto-detects your machine)

| Your computer | What to run |
|---------------|-------------|
| **Windows** | Double-click **`setup.cmd`** |
| **Mac / Linux / WSL** | `bash setup.sh` |

That is the whole install. Setup will:

1. Read your RAM, CPU, GPU, and disk  
2. Choose safe models for **this** machine (you do not pick tags)  
3. Install Docker if it is missing  
4. Start Ollama + Open WebUI  
5. Download the models and **wait until they finish**

If Docker Desktop was just installed on Windows: open it, wait until the engine is running, then double-click **`setup.cmd`** again.

On Linux, if Docker was just installed: log out and back in (or reboot), then run `bash setup.sh` again.

### 3. Chat

Open **http://localhost:3000** → pick a model → send `Hello`.

---

## What gets downloaded

Well-known open models from the official [Ollama library](https://ollama.com/library) — whatever fits your machine, for example:

| Role | Typical tag |
|------|-------------|
| Coding (most PCs) | `qwen2.5-coder:7b` |
| Research | `deepseek-r1:8b` or `deepseek-r1:14b` |
| Strong coding (lots of RAM / GPU) | `devstral:24b` or `qwen3-coder:30b` |
| File / PDF chat | `nomic-embed-text` |

**Honest limits:** 8GB RAM stays on small models; 16GB without a strong GPU should not run 24B; 32GB RAM or a 24GB-class GPU can.

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
bash setup.sh / setup.cmd   Full first-time setup (recommended)
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
| Free DIY | Clone → `setup.cmd` / `bash setup.sh` → wait for models → http://localhost:3000 |
| [GitHub Issues](https://github.com/LaxmanByte/ollama-ultimate-stack/issues) | Bugs and install failures |
| Email [support@gridvoxsystems.com](mailto:support@gridvoxsystems.com) | Short questions |
| **[Remote setup (paid)](docs/remote-setup.html)** | 

The stack stays **free and MIT**. Paid help is a human on screen-share, not a software license. Open WebUI branding stays. You are not buying Ollama or Open WebUI.

A GUI one-click installer (no typing) is on the roadmap — not for sale yet. Waitlist: email [support@gridvoxsystems.com](mailto:support@gridvoxsystems.com) with subject **one-click waitlist**.

## License

MIT. Models have their own licenses. Open WebUI keeps its own branding.
