# Claude Code Installer (cc-install)

A Docker-based installer for [Claude Code](https://claude.ai/code) that gets you
running in one command — no dependency management, no configuration, no prior
Docker knowledge needed.

You get Claude Code in your terminal, VS Code in your browser, and a folder on
your computer that both of them share.

**Why it exists:** installing Claude Code normally means dealing with Node
versions, PATH problems and per-machine differences. This packages the whole
environment into one container so a person with no Docker knowledge can install it,
sign in, and get working without help. Everything is scripted for both macOS/Linux
and Windows.

**Inspired by the [DAAF project](https://github.com/DAAF-Contribution-Community/daaf)** —
credit to their Docker-based installation approach. See
[docs/ATTRIBUTION.md](docs/ATTRIBUTION.md).

---

## Where to look for what

**Getting started — no technical background required**

| Guide | Best for |
|---|---|
| [📘 Visual Guide (PDF)](docs/installGuides/Claude%20Code%20Visual%20Guide.pdf) | **Start here** — printable illustrated walkthrough |
| [🖥️ Visual Guide (HTML)](docs/installGuides/Claude%20Code%20Visual%20Guide.html) | The same guide on-screen |
| [📄 Visual Guide (Markdown)](docs/installGuides/Claude%20Code%20Visual%20Guide.md) | The editable source of that guide |
| [💡 Tip Sheet (PDF)](docs/installGuides/ClaudeCodeTipSheet.pdf) | Everyday usage once you're running |
| [📝 Install Guide](docs/INSTALL_GUIDE.md) | Longer plain-language version, readable here on GitHub |

**Using it day to day**

| Document | What's in it |
|---|---|
| [📕 **RUNBOOK.md**](RUNBOOK.md) | **The manual.** Every command explained, changing your workspace folder, updating, backup, the Bedrock model picker, troubleshooting |
| [⚡ Quick Reference](docs/QUICK_REFERENCE.md) | One-page command card — print it or pin it up |
| [🔑 Signing in](docs/CREDENTIALS.md) | Credentials: Claude account, API key, or AWS Bedrock |

**Project detail**

| Document | What's in it |
|---|---|
| [CHANGELOG.md](CHANGELOG.md) | What changed in each version |
| [ROADMAP.md](ROADMAP.md) | Planned work — multiple instances, dual auth backends |
| [SECURITY.md](SECURITY.md) | Security posture and reporting |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | For maintainers — architecture, gotchas, release process |
| [docs/ATTRIBUTION.md](docs/ATTRIBUTION.md) | Credits and licenses |

---

## Install

### Step 1 — Docker Desktop

Download from <https://www.docker.com/products/docker-desktop/>.

**Which build?**
- **Windows:** Settings → System → About → System type. "x64-based" → **Windows x86_64**; "ARM64-based" → **Windows ARM64**
- **Mac:**  → About This Mac. Apple M-series → **Mac with Apple chip**; Intel → **Mac with Intel chip**

Install it, accept the defaults (enable WSL 2 on Windows), then **start Docker
Desktop and wait for it to finish loading** (~30-60 seconds). The tray/menu-bar
icon should say "Docker Desktop is running".

<details>
<summary><b>Windows only:</b> WSL setup</summary>

Windows Subsystem for Linux lets Docker run Linux containers. Docker Desktop
requires it.

Check whether you already have it:

```powershell
wsl --status
```

If that prints version information, you're set — skip to Step 2. Otherwise open
**PowerShell as Administrator** (Windows+X → Terminal (Admin)), run:

```powershell
wsl --update
```

then **restart your computer** and install Docker Desktop.
</details>

### Step 2 — Run one command

**macOS / Linux** — open Terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.sh -o install.sh && bash install.sh
```

**Windows** — open **PowerShell** (not Command Prompt: Windows+X → Terminal) and paste:

```powershell
irm https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.ps1 | iex
```

⏱️ The Docker image build takes **10-15 minutes**. Grab a coffee.

| Situation | Total time |
|---|---|
| Docker already installed and running | 10-15 min |
| Need to install Docker first | 20-30 min |
| Need WSL + Docker + a restart | 30-45 min |

### Step 3 — Open a new terminal window

**This matters.** The shortcuts don't exist in the window you installed from.
Close it and open a fresh Terminal (macOS/Linux) or PowerShell (Windows).

### Step 4 — Sign in, once

```bash
ccauth
```

Pick one of three options — your Claude account, an Anthropic API key, or UVA
Amazon Bedrock. Whatever you choose applies everywhere.

→ Full detail, including SSO and troubleshooting: **[docs/CREDENTIALS.md](docs/CREDENTIALS.md)**

### Step 5 — Go

```bash
ccdocker     # Claude Code in your terminal
ccvscode     # VS Code in your browser (http://localhost:8088)
```

---

## Claude Code in VS Code

`ccvscode` opens VS Code in your browser. **Out of the box there is no Claude Code
button** — VS Code Server is just the editor. There are two ways to use Claude
Code in it, and you can use both.

### Option 1 — the terminal (works immediately, nothing to install)

1. **Terminal → New Terminal** (or <kbd>Ctrl</kbd>+<kbd>`</kbd>)
2. Type `claude`

That terminal runs inside the container, so it shares the same sign-in as
`ccdocker`. This is the fastest route and it always works.

### Option 2 — the Claude Code extension (sidebar panel and inline diffs)

The extension adds a proper Claude panel and shows edits as inline diffs instead
of terminal text. It's optional, and takes under a minute:

1. In the browser IDE, click the **Extensions** icon in the left sidebar
   (or press <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>X</kbd>)
2. Type **claude** in the search box
3. Find **Claude Code** by Anthropic and click **Install**
4. When it finishes, click the **Claude** icon that appears in the left sidebar

That's it — it picks up the sign-in you already set with `ccauth`, so there's
nothing further to configure.

Prefer to do it from a terminal? One command:

```bash
docker compose exec claude-code code-server --install-extension Anthropic.claude-code
```

A few things worth knowing:

- **It survives updates.** Extensions live in a Docker volume, so `ccupdate` and
  restarts don't remove them. You install it once.
- **You still need `claude` in the terminal for some things** — the extension is a
  front-end, not a replacement.
- **If you can't find it in the search results,** the browser IDE uses
  [Open VSX](https://open-vsx.org) rather than Microsoft's marketplace. Claude Code
  is published there, so it will appear — but some other extensions you're used to
  may not exist.

→ Extension troubleshooting, and how IT can bake it into the image for a fleet:
**[RUNBOOK.md § Installing extensions](RUNBOOK.md#installing-extensions)**.

---

## Everyday commands

**Run these in a terminal on your own computer** — Terminal on macOS, PowerShell on
Windows. Not inside the browser IDE, and not inside the container: these commands
drive Docker from the outside, so they only work from your own shell.

You can run them from any folder; they find your install themselves.

| Command | What it does |
|---|---|
| `ccauth` | Set up or change how you sign in |
| `ccdocker` | Claude Code in your terminal |
| `ccvscode` | VS Code in your browser |
| `ccpath` | Change which folder on your computer is your workspace |
| `ccdiagnose` | Check the install for problems |
| `ccupdate` | Update to the latest version |

If a command isn't found, open a **new** terminal window — they're added to your
shell profile, and windows you already had open won't see them.

→ Full list with explanations, plus updating, backup, the model picker and
troubleshooting: **[RUNBOOK.md](RUNBOOK.md)**. For a printable card:
[docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md).

---

## Pre-installed skills

The image bundles skills so they're available the moment you start:

- **[Anthropic official skills](https://github.com/anthropics/skills)**
- **[Andrej Karpathy guidelines](https://github.com/multica-ai/andrej-karpathy-skills)** — AI/ML practices and coding patterns
- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent — workflow and productivity

List them with `/skills`, invoke with `/<skill-name>`. They're refreshed on every
`ccupdate`, and any skills you add yourself are left alone.

---

## How it works

A single Docker container running:

- **Debian Bookworm** (slim)
- **Claude Code** — latest, via Anthropic's official installer
- **code-server 4.133.0** — VS Code in the browser
- **Node.js 22 LTS** — required by code-server
- **Non-root user** `claudeuser` (UID 1000)

Image size is roughly **1.5-2 GB**.

Your files live in a folder on your computer that's mounted into the container, so
both sides see the same files in real time. Your sign-in and editor settings live
in Docker volumes, which is why they survive rebuilds and updates.

```
cc-install/
├── docker-compose.yml       # container orchestration (must stay at root —
│                            #   every `docker compose` call resolves it from cwd)
├── VERSION                  # update-check reads this over raw.githubusercontent
├── .env.example             # credential template → copy to .env
├── README.md  CHANGELOG.md  ROADMAP.md  SECURITY.md
├── RUNBOOK.md               # the operations manual
├── CLAUDE.md                # guidance for Claude Code working in this repo
├── bin/
│   ├── claude / claude.cmd  # launcher: Claude Code
│   └── vscode / vscode.cmd  # launcher: VS Code Server
├── docker/
│   └── Dockerfile           # image definition
├── workspace/               # your files by default (persisted, gitignored)
│                            #   — relocatable with `ccpath`
├── scripts/
│   ├── container/   entrypoint.sh                       # runs inside the image
│   ├── lib/         workspace.sh, Workspace.ps1         # shared path resolution
│   ├── installers/  install, setup-shortcuts, setup-credentials
│   ├── launchers/   run_claude, run_vscode
│   └── maintenance/ update, backup, restore, uninstall, check-update,
│                    diagnose, set-workspace
└── docs/
    ├── CREDENTIALS.md      # signing in
    ├── INSTALL_GUIDE.md    # step-by-step for non-technical users
    ├── QUICK_REFERENCE.md  # one-page command card
    ├── DEVELOPMENT.md      # for maintainers
    ├── ATTRIBUTION.md      # credits and licenses
    ├── docker-compose.override.yml.example  # optional local tweaks (ports, ~/.aws)
    └── installGuides/      # printable visual guide + tip sheet
```

The launchers live in `bin/` but `cd` to the repo root before doing anything, so
they work from any directory.

Every script exists in both `.sh` (macOS/Linux) and `.ps1` (Windows) form.

### Security

- The container runs as a non-root user, isolated from your host filesystem apart
  from your workspace folder.
- The browser IDE is published on **`127.0.0.1` only** — reachable from your
  computer and nothing else. It runs without a password on that basis; anyone who
  can open the page gets a shell in the container, so if you expose the port to
  your network, set `CC_VSCODE_PASSWORD` in `.env` first.
- `.env` is the only place credentials belong. Plain text, `chmod 600`, gitignored.
- `ccdiagnose` flags an exposed port or loose `.env` permissions.

→ More detail in [SECURITY.md](SECURITY.md) and
[RUNBOOK.md § Security](RUNBOOK.md#security).

---

## FAQ

**Do I need to know Docker?** No. The scripts handle all of it.

**Will this conflict with Claude Code already installed on my machine?** No —
it's fully containerized with its own config.

**What if I delete the container?** Your files and settings live outside it.
`ccupdate` rebuilds and everything's still there.

**Can I customise the environment?** Yes — edit `docker/Dockerfile` and run
`ccupdate`. For ports, extra mounts or resource limits, use
`docs/docker-compose.override.yml.example` instead, which survives updates.

**Can several people use one computer?** Yes, but each person should install under
their own user account so they get their own workspace and settings.

**Can I run more than one instance, with different credentials?** Not yet
supported. See [ROADMAP.md](ROADMAP.md) for the plan and the current manual recipe.

---

## Support

- **[RUNBOOK.md](RUNBOOK.md)** — start here for anything operational
- **Claude Code docs** — <https://docs.claude.com/en/docs/claude-code>
- **code-server docs** — <https://coder.com/docs/code-server/>
- **Docker docs** — <https://docs.docker.com/>
- **DAAF** (inspiration) — <https://github.com/DAAF-Contribution-Community/daaf>

## License

Provided as-is for educational and research purposes. Claude Code is a product of
Anthropic; see Anthropic's terms of service for usage.

---

**Made for anyone who wants to explore AI-assisted coding without the setup hassle.**
