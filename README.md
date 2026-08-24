# Claude Code Installer (cc-install)

A Docker-based installer for [Claude Code](https://claude.ai/code) that gets you
running in one command — no dependency management, no configuration, no prior
Docker knowledge needed.

You get Claude Code in your terminal, VS Code in your browser, and a folder on
your computer that both of them share.

**Inspired by the [DAAF project](https://github.com/DAAF-Contribution-Community/daaf)** —
credit to their Docker-based installation approach. See [ATTRIBUTION.md](ATTRIBUTION.md).

---

## New here? Start with a guide

No technical background required.

| Guide | Best for |
|-------|----------|
| [📘 Visual Guide (PDF)](docs/installGuides/Claude%20Code%20Visual%20Guide.pdf) | **Start here** — one-page printable walkthrough |
| [🖥️ Visual Guide (HTML)](docs/installGuides/Claude%20Code%20Visual%20Guide.html) | The same guide on-screen |
| [💡 Tip Sheet (PDF)](docs/installGuides/ClaudeCodeTipSheet.pdf) | Everyday usage once you're running |
| [📝 Install Guide (Markdown)](docs/INSTALL_GUIDE.md) | Longer plain-language version, readable on GitHub |
| [⚡ Quick Reference](docs/QUICK_REFERENCE.md) | Command cheat-sheet |
| [🔑 Signing in](docs/CREDENTIALS.md) | **How to set up credentials** |

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
ccvscode     # VS Code in your browser (http://localhost:8080)
```

---

## Using the browser IDE

`ccvscode` opens VS Code in your browser. **There's no Claude Code button** — VS
Code Server is just the editor. To use Claude Code in it:

1. **Terminal → New Terminal** (or <kbd>Ctrl</kbd>+<kbd>`</kbd>)
2. Type `claude`

That terminal runs inside the container, so it shares the same sign-in and
settings as `ccdocker`. `ccvscode` also drops a **START-HERE.md** into your
workspace with these instructions.

→ [docs/CREDENTIALS.md](docs/CREDENTIALS.md) covers signing in from the IDE.

### Installing extensions (including the Claude Code extension)

Open the **Extensions** panel in the browser IDE
(<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>X</kbd>), search, click **Install**. They
persist in the `code-server-data` volume, so they survive restarts and `ccupdate`.

Two things to know:

**code-server uses [Open VSX](https://open-vsx.org), not the Microsoft
Marketplace.** Microsoft's marketplace terms restrict it to Microsoft products, so
code-server ships with Open VSX instead. Most extensions are on both, but not all
— if something you want is missing, that's why.

**The Claude Code extension is on Open VSX** as `Anthropic.claude-code`, so it
installs normally. It is **optional** — running `claude` in the IDE terminal works
without it. The extension adds the sidebar panel and inline diffs.

From a terminal instead of the panel:

```bash
docker compose exec claude-code code-server --install-extension Anthropic.claude-code
docker compose exec claude-code code-server --list-extensions
```

<details>
<summary>Baking the Claude Code extension into the image (for IT / fleet builds)</summary>

Off by default because it adds **~670 MB**: the extension ships its own
per-platform Claude binary (~326 MB in `resources/native-binary/`), duplicating
the CLI this image already installs at the same version.

To include it anyway, add to `.env` and rebuild:

```bash
CC_INSTALL_VSCODE_EXTENSION=1
```

```bash
ccupdate
```

Or for a one-off build: `docker compose build --build-arg INSTALL_VSCODE_EXTENSION=1`

**Caveat:** this only reaches machines whose `code-server-data` volume is still
empty — i.e. new installs. Docker seeds a named volume from the image only once,
so an existing install won't pick up a baked-in extension. Those users install it
from the Extensions panel (which takes seconds). Verified both ways.
</details>

<details>
<summary>Extensions won't install, or the IDE won't start</summary>

Run `ccdiagnose` — it checks whether the extensions directory is writable.

Installs failing with a permission error, or code-server dying with
`EACCES: permission denied, mkdir .../coder-logs`, was a **bug in v1.3.0-1.3.1**:
the `code-server-data` volume was created root-owned, locking the container user
out. Fixed in 1.3.2 — `ccrestart` repairs it, and `ccupdate` prevents it
recurring.
</details>

---

## Commands

Available from anywhere after installation:

| Command | What it does |
|---|---|
| `ccauth` | Set up or change how you sign in |
| `ccdocker` | Claude Code in your terminal |
| `ccvscode` | VS Code in your browser |
| `ccstop` | Stop the container |
| `ccrestart` | Restart the container (applies `.env` changes) |
| `cclogs` | View container logs |
| `ccdiagnose` | Check the install for problems |
| `ccbackup` | Back up your workspace |
| `ccupdate` | Update to the latest version |

<details>
<summary>Running the scripts directly instead</summary>

From inside the `cc-install` directory:

| | macOS / Linux | Windows |
|---|---|---|
| Claude Code | `./claude` | `claude.cmd` |
| VS Code Server | `./vscode` | `vscode.cmd` |
| Sign-in setup | `./scripts/installers/setup-credentials.sh` | `.\scripts\installers\setup-credentials.ps1` |
| Diagnostics | `./scripts/maintenance/diagnose.sh` | `.\scripts\maintenance\diagnose.ps1` |
| Update | `./scripts/maintenance/update.sh` | `.\scripts\maintenance\update.ps1` |
| Backup | `./scripts/maintenance/backup.sh` | `.\scripts\maintenance\backup.ps1` |
| Restore | `./scripts/maintenance/restore.sh <file>` | `.\scripts\maintenance\restore.ps1 <file>` |
| Uninstall | `./scripts/maintenance/uninstall.sh` | `.\scripts\maintenance\uninstall.ps1` |

`run_claude.sh` / `.ps1` also accept `bash`, `logs`, `stop`, `restart`, `auth`.
</details>

---

## Your files

Everything lives in `cc-install/workspace/` on your computer. It's a normal
folder — open it in Finder or Explorer, back it up, sync it. Inside the container
it appears at `/home/claudeuser/workspace`, and the two stay in sync
automatically.

It survives container restarts, rebuilds and updates.

---

## Working on your own projects

Claude Code can only see what's mounted into the container. By default that's
exactly one folder: `cc-install/workspace/`. So to work on an existing project,
it has to be reachable there.

### The easy way — move or copy it into `workspace/`

Drag your project folder into `cc-install/workspace/` in Finder or Explorer.
That's it. **No restart needed** — it appears inside Claude Code immediately, and
edits flow both ways in real time.

```
cc-install/workspace/my-research-paper/
cc-install/workspace/thesis-data/
```

Then open it:

**In the browser editor (`ccvscode`)**
**File → Open Folder**, then enter `/home/claudeuser/workspace/my-research-paper`
and press OK. VS Code reloads rooted at your project.

**In the terminal (`ccdocker`)**
`ccdocker` starts you in `workspace/`, which means Claude Code sees *all* your
projects at once. To root it on one project:

```bash
ccdocker bash                  # opens a shell in the container
cd my-research-paper
claude
```

### ⚠️ Symlinks do not work

Creating a shortcut/alias/symlink inside `workspace/` that points somewhere else
on your computer **will not work**, and fails confusingly: the link shows up
inside the container but every file under it reads as "No such file or
directory". The container can't follow a link to a path that was never mounted.
Copy or move the folder instead.

### Keeping a project where it already lives

If a project can't move — it's in OneDrive, or a Git repo you'd rather not
relocate — mount it as a second folder:

1. Copy `docker-compose.override.yml.example` to `docker-compose.override.yml`
2. Uncomment the "Mount an extra folder" block and set your path:

   ```yaml
   services:
     claude-code:
       volumes:
         - /Users/you/Documents/research:/home/claudeuser/research
   ```

   Windows paths use forward slashes: `C:/Users/you/Documents/research`.
3. `ccrestart`

It then appears at `/home/claudeuser/research`, read **and** write, alongside
`workspace/`. Compose merges the two mounts, so `workspace/` keeps working.
`docker-compose.override.yml` is gitignored, so it survives `ccupdate`.

> Editing YAML is more than most people want to do. If you're setting this up for
> someone else, do it for them once — they won't need to touch it again.

---

## Pre-installed skills

The image bundles skills so they're available the moment you start:

- **[Anthropic official skills](https://github.com/anthropics/skills)**
- **[Andrej Karpathy guidelines](https://github.com/multica-ai/andrej-karpathy-skills)** — AI/ML practices and coding patterns
- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent — workflow and productivity

List them with `/skills`, invoke with `/<skill-name>`. They're refreshed on every
`ccupdate`, and any skills you add yourself are left alone.

---

## Updating

```bash
ccupdate
```

This updates **both** the cc-install scripts and the Docker image (which pulls
the latest Claude Code and code-server). Your `workspace/`, sign-in and settings
are untouched.

<details>
<summary>Why you can't use Claude Code's built-in updater here</summary>

Claude Code is baked into the Docker image, not stored in a persistent volume.
An update applied inside a running container is discarded the next time the image
is rebuilt. `ccupdate` is the durable path: it re-downloads the cc-install files,
rebuilds the image from scratch (`--no-cache`, so the official installer re-runs
and fetches the latest Claude Code), restarts the container, refreshes your
shortcuts, and prints the new versions.

There's no way to pin a specific Claude Code version without editing the
`Dockerfile`.

**About the "update available" notice:** it refers to a new version of *this
installer*. Running `ccupdate` gets you both that and the latest Claude Code.
</details>

---

## Backup and restore

```bash
ccbackup                                     # timestamped archive of workspace/
./scripts/maintenance/restore.sh <file>      # restore from one
```

`ccbackup` works from anywhere. Restoring is deliberately not a shortcut — it
overwrites files, so you run it from inside `cc-install` with the backup you mean.
Windows: `.\scripts\maintenance\restore.ps1 <file>`.

---

## Troubleshooting

**Run this first:**

```bash
ccdiagnose
```

It checks Docker, the container, the port, disk space, volumes, your sign-in
setup, and whether the browser IDE is exposed to your network — and suggests a
fix for each problem it finds.

<details>
<summary>Common problems</summary>

**`ccdocker: command not found`**
Open a *new* terminal window. If it persists, run
`bash scripts/installers/setup-shortcuts.sh` from your cc-install folder
(`.\scripts\installers\setup-shortcuts.ps1` on Windows).

**`[ERROR] Docker daemon is not running`**
Start Docker Desktop, wait for it to finish loading, try again.

**`port 8080 is already allocated`**
Copy `docker-compose.override.yml.example` to `docker-compose.override.yml` and
change the port to `127.0.0.1:8081:8080`. Then use `http://localhost:8081`.

**Container won't start**
`docker compose logs` to see why, then `ccupdate` to rebuild.

**`claude: command not found` inside the container**
Give the container ~10 seconds to finish starting. If it persists, `ccupdate`.

**Build fails**
Check your internet connection, confirm you have ~3 GB of free disk space, and
check Docker Desktop has enough resources (Settings → Resources). Then retry.

**Claude Code keeps asking me to sign in**
See [docs/CREDENTIALS.md](docs/CREDENTIALS.md) — usually a leftover
`ANTHROPIC_API_KEY` in `.env` overriding your account login.
</details>

---

## Uninstalling

```bash
./scripts/maintenance/uninstall.sh      # or uninstall.ps1 on Windows
```

Stops and removes the container, removes the image, and removes the Docker
volumes (with confirmation). Your `workspace/` is **not** deleted unless you
explicitly confirm.

---

## How it works

A single Docker container running:

- **Debian Bookworm** (slim)
- **Claude Code** — latest, via Anthropic's official installer
- **code-server 4.133.0** — VS Code in the browser
- **Node.js 22 LTS** — required by code-server
- **Non-root user** `claudeuser` (UID 1000)

Image size is roughly **1.5-2 GB**.

```
cc-install/
├── Dockerfile                          # image definition
├── docker-compose.yml                  # container orchestration
├── docker-compose.override.yml.example # optional local tweaks (ports, ~/.aws)
├── .env.example                         # credential template → copy to .env
├── VERSION
├── claude / claude.cmd                  # root launcher: Claude Code
├── vscode / vscode.cmd                  # root launcher: VS Code Server
├── workspace/                           # your files (persisted, gitignored)
├── scripts/
│   ├── container/   entrypoint.sh                       # runs inside the image
│   ├── installers/  install, setup-shortcuts, setup-credentials
│   ├── launchers/   run_claude, run_vscode
│   └── maintenance/ update, backup, restore, uninstall, check-update, diagnose
└── docs/
    ├── CREDENTIALS.md      # signing in
    ├── INSTALL_GUIDE.md    # step-by-step for non-technical users
    ├── QUICK_REFERENCE.md  # cheat sheet
    ├── DEVELOPMENT.md      # for maintainers
    └── installGuides/      # PDF / HTML guides
```

Every script exists in both `.sh` (macOS/Linux) and `.ps1` (Windows) form.

### Security

- Container runs as a non-root user, isolated from your host filesystem apart
  from `workspace/`.
- The browser IDE is published on **`127.0.0.1` only** — reachable from your
  computer and nothing else. It runs without a password on that basis; anyone who
  can open the page gets a shell in the container, so if you expose the port to
  your network, set `CC_VSCODE_PASSWORD` in `.env` first.
- `.env` holds credentials in plain text, `chmod 600`, and is gitignored.
- `ccdiagnose` flags an exposed port or loose `.env` permissions.

---

## FAQ

**Do I need to know Docker?** No. The scripts handle all of it.

**Will this conflict with Claude Code already installed on my machine?** No —
it's fully containerized with its own config.

**What if I delete the container?** Your files (`workspace/`) and settings
(`claude-config` volume) live outside it. `ccupdate` rebuilds and everything's
still there.

**Can I customise the environment?** Yes — edit the `Dockerfile` and run
`ccupdate`. For ports, extra mounts or resource limits, use
`docker-compose.override.yml.example` instead, which survives updates.

**Can several people use one computer?** Yes, but each person should install
under their own user account so they get their own workspace and settings.

---

## Support

- **[ROADMAP.md](ROADMAP.md)** — what's planned, including multi-instance and dual auth backends
- **Claude Code docs** — <https://docs.claude.com/en/docs/claude-code>
- **code-server docs** — <https://coder.com/docs/code-server/>
- **Docker docs** — <https://docs.docker.com/>
- **DAAF** (inspiration) — <https://github.com/DAAF-Contribution-Community/daaf>

## License

Provided as-is for educational and research purposes. Claude Code is a product of
Anthropic; see Anthropic's terms of service for usage.

---

**Made for anyone who wants to explore AI-assisted coding without the setup hassle.**
