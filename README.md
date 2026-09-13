# Ollama Ultimate Stack

Free ChatGPT-style AI on **your** computer: **Ollama** + **Open WebUI** + automatic download of well-known open models.

No account. No API key. No license key. When the installer finishes, you open a browser and chat.

**Web chat:** http://localhost:3000  
**API:** http://localhost:11434

```text
You (browser)  →  Open WebUI (:3000)  →  Ollama (:11434)  →  models on disk
                      │
                      └── attach a PDF / file in chat (built into Open WebUI)
```

---

## You are done when

1. The install window prints **`ALL MODELS DOWNLOADED SUCCESSFULLY`**
2. http://localhost:3000 opens
3. The model dropdown is **not empty** — type a message and send

Do not close the install window during the first run. Model files are large (often 15–60 minutes).

---

## Complete install

You need Git. Docker is installed for you if it is missing.

### Windows (easiest)

1. Install [Git for Windows](https://git-scm.com/download/win) if `git` is not already on your PC.
2. Open **PowerShell** and run:

```powershell
git clone https://github.com/LaxmanByte/ollama-ultimate-stack.git
cd ollama-ultimate-stack
explorer .
```

3. In the folder that opened, **double-click `check-hardware.cmd`**. Read RUN / SLOW / CRASH. Press any key.
4. **Double-click `install.cmd`**.
5. If Docker Desktop was just installed: open it from the Start menu, wait until it says the engine is running, then double-click `install.cmd` again.
6. Wait until you see **`ALL MODELS DOWNLOADED SUCCESSFULLY`**.
7. Open http://localhost:3000 — pick a model — send `Hello`.

Same steps without double-click:

```powershell
powershell -ExecutionPolicy Bypass -File .\check-hardware.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### Linux / macOS / WSL

```bash
git clone https://github.com/LaxmanByte/ollama-ultimate-stack.git
cd ollama-ultimate-stack
bash check-hardware.sh
bash install.sh
```

Then open http://localhost:3000

If Docker was just installed on Linux, log out and back in (or reboot) so your user can use Docker, then run `bash install.sh` again.

---

## What gets downloaded

The hardware check picks models that **fit this machine**. The installer then pulls those tags from the official [Ollama library](https://ollama.com/library) — well-known open models, not a private catalog.

| Role | Typical tag | What it is |
|------|-------------|------------|
| Fast coding (fits most PCs) | `qwen2.5-coder:7b` | Qwen2.5 Coder 7B |
| Research / reasoning | `deepseek-r1:8b` or `deepseek-r1:14b` | DeepSeek R1 distill |
| Strong coding (32GB or RTX 4090-class) | `devstral:24b` | Mistral Devstral |
| Strong coding + GPU RAM | `qwen3-coder:30b` | Qwen3 Coder 30B |
| File chat (always) | `nomic-embed-text` | Tiny embedding model so you can attach PDFs |

**Honest hardware**

- **8GB RAM:** 7B / 8B only. 24B will not run.
- **16GB RAM, no GPU:** 7B is the daily driver. 14B is slow. 24B will crash.
- **32GB RAM or a 24GB GPU (RTX 4090 class):** 24B is realistic.

The checker writes `.hardware-profile`. The installer copies `profiles/8gb.env`, `16gb.env`, or `32gb.env`, then applies those model picks. It does **not** overwrite a `.env` you already customized.

---

## Use it

| You want | Do this |
|----------|---------|
| Chat | http://localhost:3000 → choose a model → type |
| Ask about a PDF / Word / code file | In the same chat, click **+** or the paperclip, attach the file, ask |
| List downloaded models | `docker exec ollama ollama list` |
| Stop | `docker compose stop` |
| Start again later | `docker compose start` (models stay on disk; no re-download) |

More: [USAGE-GUIDE.md](USAGE-GUIDE.md) (Continue, Cline, API, troubleshooting).

---

## Update later

```bash
# Linux / macOS / WSL
bash update.sh

# Windows
.\update.ps1
```

This keeps your `.env` (models, ports, secret). It does **not** delete downloaded models.

If a model failed mid-download, only re-run the puller:

```bash
docker compose run --rm model-puller
```

---

## Commands

```text
make check           Hardware diagnostic (no Docker required)
make up              Start Ollama + WebUI
make down            Stop everything
make chat            Terminal chat (coding model)
make models          List installed models
make update          Git pull + image pull (keeps .env)
make info            URLs and next steps
make help            All targets
```

Windows without Make: `check-hardware.cmd`, `install.cmd`, `.\update.ps1`.

---

## Requirements

- ~8GB RAM minimum (16GB recommended)
- ~20–50GB free disk (depends on which models fit)
- Internet **once**, for Docker images + model files
- After that, everything is local

---

## Need help?

| Channel | Notes |
|---------|-------|
| [GitHub Issues](https://github.com/LaxmanByte/ollama-ultimate-stack/issues) | Bugs, install failures, hardware-check questions |
| Email [support@gridvoxsystems.com](mailto:support@gridvoxsystems.com) | Short install questions |
| Remote setup | Optional screen-share until first chat works |

The stack stays **free and MIT**. Optional help is not a license.

A GUI one-click installer (no typing) is on the roadmap. It is **not for sale yet**. Waitlist: email [support@gridvoxsystems.com](mailto:support@gridvoxsystems.com) with subject **one-click waitlist**.

## License

MIT. Models have their own licenses (Apache 2.0, etc.). Open WebUI keeps its own branding.
