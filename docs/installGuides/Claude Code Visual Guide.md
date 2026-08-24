# Claude Code — Get Started

**Install once, in about 20 minutes. No coding or Docker knowledge required.**

*Visual Guide · Rev. Aug 2026 · v1.3.3*

> **Source of truth for the one-page guide.** This is the editable version of
> `Claude Code Visual Guide.html` / `.pdf`. Edit here, then carry changes into the
> HTML and re-export. Keep the version stamp above in sync with `VERSION`.

---

## Before you start

Request your **UVA Amazon Bedrock credentials** from Batten IT now — you'll need
them at Step 3, and usage is billed to the University, not to you.

---

## 1 · Install Docker Desktop

Download from **docker.com/products/docker-desktop** — pick Apple chip / Intel /
Windows. Accept the defaults; on Windows allow **WSL 2** and restart if asked.

Open Docker Desktop and wait for *"Docker Desktop is running"* (whale icon) before
Step 2.

## 2 · Run one command

**macOS — Terminal app**

```bash
curl -fsSL https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.sh -o install.sh && bash install.sh
```

**Windows — PowerShell only**

```powershell
irm https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.ps1 | iex
```

Takes 10–15 min. Scrolling text is normal; wait for the green
**Installation Complete!**

## 3 · New terminal, then sign in

Close the old window first — the shortcuts only appear in a fresh one. Then type
`ccauth` and choose option **3 — Amazon Bedrock** (the UVA option, billed to the
University).

Enter the Access Key ID and Secret Access Key from Batten IT —
**nothing appears as you type or paste; that's normal**. Press Enter to accept
region `us-east-1`, then press Enter **twice more** to skip the optional session
token and model ID.

> **"command not found"?** You're still in the old terminal window. Sign-in is once
> only and survives updates.

## 4 · Launch Claude Code

Type `ccdocker` for Claude Code in your terminal, or `ccvscode` for the
browser-based editor at **localhost:8088**.

Your sign-in applies to both, so either one just works.

---

## Commands — work from anywhere

| Command | What it does |
|---|---|
| `ccauth` | Set up or change how you sign in |
| `ccdocker` | Launch Claude Code in the terminal |
| `ccvscode` | Launch the browser editor (localhost:8088) |
| `ccstop` | Stop it when you're done for the day |
| `ccrestart` | Restart if something seems stuck |
| `ccdiagnose` | Check your install and get fixes |
| `ccbackup` | Back up your workspace |
| `ccupdate` | Update everything (10–15 min, keeps your files) |
| `cclogs` | Show technical logs for troubleshooting |

---

## In the browser editor

There is **no Claude Code button**. Choose **Terminal → New Terminal**, type
`claude`, press Enter. Same sign-in as the terminal.

**Extensions** install from the Extensions panel (Ctrl+Shift+X) and persist across
updates — the Claude Code extension is optional, and lives in a different store
(Open VSX) than desktop VS Code.

---

## If something goes wrong

**Always run `ccdiagnose` first.** It checks Docker, ports, disk space and your
sign-in, then tells you the fix.

| Problem | Fix |
|---|---|
| *"Docker daemon is not running"* | Open Docker Desktop, wait until it says running. |
| Install command doesn't work on Windows | Use PowerShell, not Command Prompt. |
| Browser editor won't open | Wait ~10s, then visit localhost:8088 manually. |
| *"Port 8088 already allocated"* | Run `ccdiagnose`, or contact Batten IT. |
| Keeps asking you to sign in | Run `ccdiagnose`, then `ccauth`. |

---

## Using it day to day

**Just talk to it**
Type what you want in plain English — *"summarize the CSV in my workspace"* or
*"draft a Python script to rename these files."* Claude Code reads, writes and
edits files for you.

**Skills are pre-installed**
Type `/skills` inside Claude Code to see the skill packs already included, and
`/help` for commands.

**Update safely**
Back up first, then update: `ccbackup` → `ccupdate`. Your workspace and sign-in
are untouched.

---

## Your files & your own projects

Everything lives in `cc-install/workspace/` — a normal folder you can open, drag
files into, and back up.

To work on a project you already have, **drag its folder into `workspace/`** — it
appears instantly, no restart. In the browser editor use **File → Open Folder** →
`/home/claudeuser/workspace/your-folder`.

Shortcuts and aliases pointing outside `workspace/` will **not** work — copy the
real folder in.

---

**Need help?** Contact **Batten IT** — include your OS (Mac/Windows) and the
`ccdiagnose` output or a screenshot.

Full detail: [INSTALL_GUIDE.md](../INSTALL_GUIDE.md) ·
[QUICK_REFERENCE.md](../QUICK_REFERENCE.md) · [CREDENTIALS.md](../CREDENTIALS.md)
