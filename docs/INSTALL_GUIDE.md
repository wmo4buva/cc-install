# Getting Started with Claude Code — Install Guide

Welcome! This guide walks you through installing and using **Claude Code**, an
AI coding assistant, on your own computer. You do **not** need to be a programmer
or know anything about Docker to follow along.

**What you'll end up with:**
- Claude Code running in your terminal (a chat-style AI assistant for writing,
  editing, and understanding files and code).
- An optional browser-based code editor (VS Code) at `http://localhost:8088`.
- A `workspace` folder on your computer where all your files live.

**Time needed:** about 10–15 minutes if Docker is already installed, or 20–30
minutes the first time (Docker install adds time).

> **Need help at any point?** Contact **Batten IT** — see [Getting Help](#getting-help)
> at the bottom. There's also a built-in diagnostic tool that checks your setup
> and suggests fixes.

---

## Before you start: What you'll need

1. **A computer** running macOS (Apple Silicon or Intel) or Windows 10/11.
2. **Docker Desktop** — free software that runs Claude Code in a safe, isolated
   "container" so it never interferes with the rest of your computer. We'll
   install this in Step 1.
3. **Your UVA Amazon Bedrock credentials** — this is how Claude Code connects to
   the AI, billed to the university (not to you personally). If you don't have
   these yet, request them from **Batten IT before you start** so they're ready when
   you first launch Claude Code.

---

## Step 1 — Install Docker Desktop

Docker Desktop is what makes this "one-line install" possible. You only do this once.

1. Go to **https://www.docker.com/products/docker-desktop/** and download the
   version for your computer:

   | Your computer | Download |
   |---|---|
   | **Mac — Apple Silicon** (M1/M2/M3/M4) | "Mac with Apple chip" |
   | **Mac — Intel** | "Mac with Intel chip" |
   | **Windows** | "Windows" (choose ARM64 only if your PC is ARM-based; otherwise x86_64) |

   *Not sure which Mac you have?* Click the  menu → **About This Mac**.
   *Not sure about Windows?* **Settings → System → About → System type**.

2. **Run the installer** and accept the default options.
   - On Windows, allow it to enable **WSL 2** if asked, and **restart** if prompted.

3. **Open Docker Desktop** and wait ~30–60 seconds until it says
   **"Docker Desktop is running"** (whale icon in your menu bar / system tray).

> **Windows users:** If Docker asks for WSL and it isn't installed, open
> **PowerShell as Administrator** (Windows + X → *Terminal (Admin)*), run
> `wsl --update`, then restart your computer. Then start Docker Desktop.

✅ **Make sure Docker Desktop is running before moving to Step 2.**

---

## Step 2 — Install Claude Code (one command)

Open your terminal and paste the single command for your system. It downloads
everything, builds your environment, and sets up easy launch shortcuts.

### 🍎 macOS / Linux

Open the **Terminal** app and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.sh -o install.sh && bash install.sh
```

> You may see a macOS prompt like *"Terminal would like to make changes."* Click
> **OK** to allow it.

### 🪟 Windows

Open **PowerShell** (not Command Prompt): press **Windows + X → Terminal** or
**Windows PowerShell**, then paste:

```powershell
irm https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.ps1 | iex
```

> This command **only works in PowerShell**, not the black Command Prompt window.

**☕ Now wait.** The build takes about **10–15 minutes** the first time. You'll see
lots of text scroll by — that's normal. When it's done, you'll see a green
**"Installation Complete!"** message.

---

## Step 3 — Launch Claude Code

**First, close your terminal window and open a fresh one.** This is required so
the new shortcut commands become available.

Then, from anywhere, type:

```bash
ccdocker
```

That starts **Claude Code** in your terminal. To use the **browser-based editor**
instead:

```bash
ccvscode
```

This opens **http://localhost:8088** in your browser — a full code editor you can
use with your mouse.

| Command | What it does |
|---|---|
| `ccauth` | Set up or change how you sign in |
| `ccdocker` | Launch Claude Code (the AI assistant) |
| `ccvscode` | Launch the browser-based VS Code editor |
| `ccstop` | Stop Claude Code when you're done for the day |
| `ccrestart` | Restart it if something seems stuck |
| `cclogs` | Show technical logs (mainly for troubleshooting) |
| `ccdiagnose` | Check your install if something looks wrong |
| `ccbackup` | Make a dated backup of your workspace |
| `ccupdate` | Update to the newest version |

> **Shortcuts not found?** Make sure you opened a **brand-new terminal window**
> after the install finished. On Mac you can always fall back to:
> `cd cc-install` then `./claude` (or `./vscode`).

---

## Step 4 — Sign in (once)

Before Claude Code can do anything, it needs to know who's paying for it. Type:

```bash
ccauth
```

It asks you to pick one of three options:

**1) My Claude account** — choose this if you have a Claude Pro, Max or Team
subscription. Nothing to type here. Afterwards run `ccdocker`; Claude Code shows
a web address, you sign in there, and paste back the code it gives you. Once
only.

**2) Anthropic API key** — a personal key from
<https://console.anthropic.com/settings/keys>. Usage is billed to whoever owns
the key, so this is the personal-cost option.

**3) Amazon Bedrock** — the **UVA option**. Usage is billed to the university,
not to you. Enter the credentials Batten IT gave you:

- **AWS Access Key ID**
- **AWS Secret Access Key**
- **Region** (press Enter to accept `us-east-1` unless told otherwise)

Whichever you pick, it applies to **both** `ccdocker` and `ccvscode`. You only do
this once — it's remembered, and it survives updates.

> Don't have Bedrock credentials? **Contact Batten IT** — they'll issue them.
>
> Need more detail, or hit a problem? See
> [CREDENTIALS.md](CREDENTIALS.md).

---

## Using the browser editor

If you prefer clicking to typing, run `ccvscode`. One thing surprises everyone:

**There's no Claude Code button in the browser editor.** VS Code is just the
editor. To use Claude Code inside it:

1. In the menu, choose **Terminal → New Terminal**
2. Type `claude` and press Enter

Claude Code then runs in the panel at the bottom, with the same sign-in you set
up in Step 4. There's also a **START-HERE.md** file waiting in your workspace
with these instructions.

### Adding extensions

The browser editor can install extensions like normal VS Code. Click the
**Extensions** icon in the left sidebar (or press
<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>X</kbd>), search for what you want, and click
**Install**. They stay installed — updates won't remove them.

**The Claude Code extension is optional.** Search for **"Claude Code"** and install
it if you'd like the sidebar panel and inline diffs. You don't need it to use
Claude Code — typing `claude` in the terminal works either way.

> **Can't find an extension you expected?** The browser editor uses a different
> extension store ([Open VSX](https://open-vsx.org)) than the desktop VS Code app,
> because Microsoft's store is limited to Microsoft's own products. Most popular
> extensions are in both, but a few aren't. Not something you can change, and not
> a fault with your install.

> **Getting a permission error when installing?** That was a bug in versions
> 1.3.0-1.3.1. Run `ccrestart`, then `ccupdate`. If it persists, run `ccdiagnose`
> and send the output to Batten IT.

---

## Working on a project you already have

Claude Code can only see files inside one folder: **`cc-install/workspace/`**.
Anything outside it is invisible to Claude Code — that's the isolation that keeps
it safe.

So to work on an existing project, put it in there:

1. Open `cc-install/workspace/` in **Finder** (Mac) or **File Explorer** (Windows)
2. **Drag your project folder into it** (or copy it in)

That's all. You don't need to restart anything — it shows up in Claude Code right
away, and any change you make in either place appears in the other instantly.

**Then open it:**

- **Browser editor:** choose **File → Open Folder**, type
  `/home/claudeuser/workspace/` followed by your folder name, and click OK.
- **Terminal:** type `ccdocker bash`, then `cd` followed by your folder name, then
  `claude`. (Plain `ccdocker` also works — Claude Code just sees all your projects
  at once instead of one.)

> ⚠️ **Don't use a shortcut or alias.** Making a Mac alias or Windows shortcut
> inside `workspace/` that points to a folder elsewhere **won't work** — Claude
> Code will see the shortcut but report the files as missing. Copy or move the
> real folder instead.

**Need to leave a project where it is?** If a folder can't be moved — it's synced
by OneDrive, say — it can be attached as a second folder instead. That takes a
one-time config change, so **ask Batten IT to set it up**; see "Keeping a project
where it already lives" in the [README](../README.md).

---

## Using Claude Code day to day

- **Just talk to it.** Type what you want in plain English:
  *"Summarize the CSV file in my workspace,"* or *"Help me draft a Python script
  to rename these files."* Claude Code can read, write, and edit files for you.

- **Your files live in one place.** Everything you and Claude Code create is saved
  in the `workspace` folder inside `cc-install`:
  - **Mac:** `cc-install/workspace/`
  - It behaves like any normal folder — you can open it in Finder/Explorer, drag
    files in, and back it up.

- **Your work is safe.** Files and settings live *outside* the container, so they
  survive restarts, updates, and even rebuilding the environment.

- **Pre-installed skills.** Your install already includes helpful skill packs
  (from Anthropic and others). Type `/skills` inside Claude Code to see them.

- **When you're done**, you can close the terminal. To fully stop the background
  environment, type `ccstop`.

---

## Keeping it up to date

Because Claude Code runs inside a managed container, the normal "self-update"
won't stick. To update properly, type:

```bash
ccupdate
```

That gets you the latest Claude Code, the latest editor, and the latest version
of the installer scripts — **without touching your `workspace` files or your
sign-in**. It's the right thing to do whenever you see an "update available"
message.

It takes 10-15 minutes, because it rebuilds the environment from scratch.

---

## Backing up your work

Your `workspace` folder is just files on your computer, so you can copy it like
any folder. There's also a one-command backup:

```bash
ccbackup
```

This creates a dated backup inside `cc-install/backups/`. It's good practice to
run it before `ccupdate`.

To restore one, run this from inside the `cc-install` folder — it overwrites
files, so it deliberately isn't a from-anywhere shortcut:

```bash
cd cc-install
./scripts/maintenance/restore.sh backups/<the-backup-file>
```

On Windows use `.\scripts\maintenance\restore.ps1 backups\<the-backup-file>`.

---

## Troubleshooting

**Try the diagnostic tool first** — it checks Docker, ports, disk space, your
container and your sign-in, then tells you exactly what's wrong and how to fix it:

```bash
ccdiagnose
```

### Common issues

| Problem | Fix |
|---|---|
| *"command not found: ccdocker"* | Open a **fresh terminal window** after installing. On Mac you can also `cd cc-install` and run `./claude`. |
| *"Docker daemon is not running"* | Open **Docker Desktop** and wait until it says "running," then try again. |
| The install command *"doesn't work"* on Windows | Make sure you're in **PowerShell**, not Command Prompt (cmd). |
| Browser editor won't open | Wait ~10 seconds after `ccvscode`, then visit **http://localhost:8088** manually. |
| *"port 8080 already allocated"* | Something else is using that port. Run `ccdiagnose`, or contact Batten IT. |
| **Can't find Claude Code in the browser editor** | There's no button. Use **Terminal → New Terminal** and type `claude`. |
| It keeps asking you to sign in | Run `ccdiagnose`, then `ccauth`. See [CREDENTIALS.md](CREDENTIALS.md). |
| Everything seems stuck | Run `ccrestart`, or run `ccdiagnose`. |

---

## Getting Help

- **First stop:** run the diagnostic tool (above) and note what it reports.
- **Support:** contact **Batten IT** — include your operating system (Mac/Windows)
  and, if possible, a copy of the diagnostic output or a screenshot of the error.
- **Reference:** the full technical [README](../README.md) has additional detail
  and a command cheat-sheet ([Quick Reference](QUICK_REFERENCE.md)).

---

*Claude Code Installer • Batten • Built on the
[DAAF project](https://github.com/DAAF-Contribution-Community/daaf) approach.*
