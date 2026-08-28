# cc-install Runbook

How to operate a running install: every command, what each one does, and how to
change things later.

New here? Start with the [README](README.md) for what this is, or the
[Install Guide](docs/INSTALL_GUIDE.md) for step-by-step setup. For a one-page
command card to print or pin up, see
[docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md) — this file is the manual
version of the same commands, with explanations.

## Contents

- [Commands](#commands)
- [Using the browser IDE](#using-the-browser-ide)
- [Installing extensions](#installing-extensions)
- [Your files](#your-files)
- [Working on your own projects](#working-on-your-own-projects)
- [Changing which folder holds your files](#changing-which-folder-holds-your-files) — `ccpath`
- [Updating](#updating)
- [Backup and restore](#backup-and-restore)
- [Choosing which models appear in the picker](#choosing-which-models-appear-in-the-picker) — Bedrock
- [Available Bedrock model IDs](#available-bedrock-model-ids)
- [Troubleshooting](#troubleshooting)
- [Uninstalling](#uninstalling)
- [File locations](#file-locations)

---

## Commands

Available from anywhere after installation.

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
| `ccpath` | Change which folder on your computer is your workspace |
| `ccupdate` | Update to the latest version |

If a command isn't found, open a **new** terminal window — the shortcuts are added
to your shell profile and existing windows don't pick them up.

<details>
<summary>Running the scripts directly instead</summary>

From inside the `cc-install` directory:

| | macOS / Linux | Windows |
|---|---|---|
| Claude Code | `./bin/claude` | `bin\claude.cmd` |
| VS Code Server | `./bin/vscode` | `bin\vscode.cmd` |
| Sign-in setup | `./scripts/installers/setup-credentials.sh` | `.\scripts\installers\setup-credentials.ps1` |
| Diagnostics | `./scripts/maintenance/diagnose.sh` | `.\scripts\maintenance\diagnose.ps1` |
| Update | `./scripts/maintenance/update.sh` | `.\scripts\maintenance\update.ps1` |
| Backup | `./scripts/maintenance/backup.sh` | `.\scripts\maintenance\backup.ps1` |
| Change workspace folder | `./scripts/maintenance/set-workspace.sh` | `.\scripts\maintenance\set-workspace.ps1` |
| Restore | `./scripts/maintenance/restore.sh <file>` | `.\scripts\maintenance\restore.ps1 <file>` |
| Uninstall | `./scripts/maintenance/uninstall.sh` | `.\scripts\maintenance\uninstall.ps1` |

`run_claude.sh` / `.ps1` also accept `bash`, `logs`, `stop`, `restart`, `auth`.

The launchers live in `bin/` but `cd` to the repo root first, so they work from
any directory.
</details>

---

## Using the browser IDE

`ccvscode` opens VS Code in your browser. **There is no Claude Code button** — VS
Code Server is just the editor. To use Claude Code in it:

1. **Terminal → New Terminal** (or <kbd>Ctrl</kbd>+<kbd>`</kbd>)
2. Type `claude`

That terminal runs inside the container, so it shares the same sign-in and
settings as `ccdocker`. When your workspace is the bundled `workspace/`,
`ccvscode` also drops a **START-HERE.md** into it with these instructions. It
deliberately does *not* do that when you've pointed `ccpath` at a folder you
already own — see [Changing which folder holds your files](#changing-which-folder-holds-your-files).

Signing in from the IDE: [docs/CREDENTIALS.md](docs/CREDENTIALS.md).

---

## Installing extensions

Installing the Claude Code extension for the first time is walked through in
[README § Claude Code in VS Code](README.md#claude-code-in-vs-code). This section
is the reference: how extensions behave here, fleet builds, and what to do when one
won't install.

Open the **Extensions** panel (<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>X</kbd>),
search, click **Install**. They persist in the `code-server-data` volume, so they
survive restarts and `ccupdate`.

Two things to know:

**code-server uses [Open VSX](https://open-vsx.org), not the Microsoft
Marketplace.** Microsoft's terms restrict its marketplace to Microsoft products,
so code-server ships with Open VSX instead. Most extensions are on both, but not
all — if something you want is missing, that's why.

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
from the Extensions panel, which takes seconds. Verified both ways.
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

## Your files

By default everything lives in `cc-install/workspace/` on your computer. It's a
normal folder — open it in Finder or Explorer, back it up, sync it. Inside the
container it appears at `/home/claudeuser/workspace`, and the two stay in sync
automatically.

It survives container restarts, rebuilds and updates.

You can point that at any folder on your computer with
[`ccpath`](#changing-which-folder-holds-your-files).

---

## Working on your own projects

Claude Code can only see what's mounted into the container. By default that's
exactly one folder: `cc-install/workspace/`. So to work on an existing project, it
has to be reachable there.

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
Copy or move the folder instead — or use `ccpath` below.

### Keeping a project where it already lives

If you'd rather keep `workspace/` as-is and *add* a second folder — say a Git repo
you don't want to relocate — mount it alongside:

1. Copy `docs/docker-compose.override.yml.example` to `docker-compose.override.yml`
   in the repo root (Docker only auto-loads it from there)
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

## Changing which folder holds your files

By default your files live in the `workspace` folder inside the install. `ccpath`
points that at any folder on your computer instead.

```bash
ccpath ~/Dev/projects     # point your workspace there
ccpath --show             # where is it now?
ccpath --reset            # back to ./workspace
ccpath                    # show current, then prompt
```

**What it does:** writes `CC_WORKSPACE` into `.env`, which `docker-compose.yml`
uses as the source of the workspace mount. Inside the container your files stay at
`/home/claudeuser/workspace`, so nothing moves around in the browser IDE.

**What it handles for you:**

- Offers to copy your existing files over. It copies rather than moves, and never
  deletes the originals.
- Recreates the container. A bind mount is fixed when the container is created, so
  a plain restart would silently keep using the old folder. It then reads the mount
  back out of Docker to confirm the change actually took.
- Warns if Docker Desktop may not be able to reach the folder. On macOS it shares
  `/Users`, `/Volumes`, `/private` and `/tmp` by default; a folder outside those
  mounts as **empty with no error at all**, which is miserable to diagnose. Add the
  path under Docker Desktop → Settings → Resources → File sharing.
- Warns on cloud-synced folders (Dropbox, OneDrive, iCloud, Google Drive). The sync
  client and the container both write the same files, which can corrupt saves
  mid-write. Keep the workspace local and sync a backup instead.
- Rejects `~` and relative paths. Docker Compose expands neither, so `~/foo` would
  mount a folder literally named `~`. `ccpath` always writes an absolute path.

`ccbackup`, `ccrestore` and `ccdiagnose` all follow the new location
automatically. When the workspace is relocated, `ccvscode` does **not** write a
`START-HERE.md` into it — that folder is often a Git repo, where an unexpected
untracked file can get committed by accident.

**One caution:** `ccrestore` clears the workspace before extracting a backup. It
refuses to run if your workspace is your home directory or a filesystem root, but
don't point `ccpath` at a folder containing anything you aren't happy to have
replaced by a restore.

---

## Updating

```bash
ccupdate
```

This updates **both** the cc-install scripts and the Docker image (which pulls the
latest Claude Code and code-server). Your workspace, sign-in and settings are
untouched. It takes 10–15 minutes, because it rebuilds the image from scratch.

<details>
<summary>Why you can't use Claude Code's built-in updater here</summary>

Claude Code is baked into the Docker image, not stored in a persistent volume. An
update applied inside a running container is discarded the next time the image is
rebuilt. `ccupdate` is the durable path: it re-downloads the cc-install files,
rebuilds the image from scratch (`--no-cache`, so the official installer re-runs
and fetches the latest Claude Code), restarts the container, refreshes your
shortcuts, and prints the new versions.

There's no way to pin a specific Claude Code version without editing
`docker/Dockerfile`.

**About the "update available" notice:** it refers to a new version of *this
installer*. Running `ccupdate` gets you both that and the latest Claude Code.
</details>

---

## Backup and restore

```bash
ccbackup                                     # timestamped archive of your workspace
./scripts/maintenance/restore.sh <file>      # restore from one
```

`ccbackup` works from anywhere. Restoring is deliberately not a shortcut — it
overwrites files, so you run it from inside `cc-install` with the backup you mean.
Windows: `.\scripts\maintenance\restore.ps1 <file>`.

Both follow `ccpath`, so they act on whichever folder is currently your workspace.
If you've pointed it at a large projects folder, expect large archives.

---

## Choosing which models appear in the picker

Applies when you're signed in with AWS Bedrock (`CLAUDE_CODE_USE_BEDROCK=1`).

### Understanding the model picker

The Claude Code VS Code extension shows a built-in picker with these entries:

- **Default** — set via `ANTHROPIC_DEFAULT_OPUS_MODEL`
- **Fable** — hardcoded to the latest Fable version
- **Custom Sonnet** — set via `ANTHROPIC_DEFAULT_SONNET_MODEL`
- **Custom Opus** — set via `ANTHROPIC_DEFAULT_OPUS_MODEL`
- **Custom Haiku** — set via `ANTHROPIC_DEFAULT_HAIKU_MODEL`

**Important limitation:** you can only customise **three** models (Sonnet, Opus,
Haiku) via environment variables. The extension does not support adding multiple
versions of each to the picker.

### Where the setting lives

`~/.claude/settings.json`, inside the container. It holds your model defaults,
theme, and other Claude Code preferences.

Credentials do **not** belong in it — `.env` on the host is the single source for
those (see [Security](#security)).

### How to update the model list

**1. Access the container**

```bash
docker compose exec claude-code bash
```

**2. Change only the model IDs**

Use `jq` rather than rewriting the whole file, so you never have to retype
anything else that's in there:

```bash
jq '.env.ANTHROPIC_DEFAULT_SONNET_MODEL = "us.anthropic.claude-sonnet-5"
  | .env.ANTHROPIC_DEFAULT_OPUS_MODEL   = "us.anthropic.claude-opus-5"
  | .env.ANTHROPIC_DEFAULT_HAIKU_MODEL  = "us.anthropic.claude-haiku-4-5-20251001-v1:0"' \
  ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
```

**3. Verify**

```bash
jq '.env | with_entries(select(.key | startswith("ANTHROPIC_")))' ~/.claude/settings.json
```

**4. Exit and reload the extension**

```bash
exit
```

Then in your VS Code browser tab, reload the page (Cmd/Ctrl + R) or close and
reopen the Claude panel. That forces the extension to re-read the settings.

### Doing it from the host instead

Without entering the container:

```bash
# View just the model settings
docker compose exec claude-code bash -c 'jq ".env | with_entries(select(.key|startswith(\"ANTHROPIC_\")))" ~/.claude/settings.json'

# Change one model
docker compose exec claude-code bash -c 'jq '\''.env.ANTHROPIC_DEFAULT_SONNET_MODEL = "us.anthropic.claude-sonnet-5"'\'' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json'
```

### Using models that aren't in the picker

The picker has only three customisable slots, so the "one version prior" models
can't all live in it at once. Reach them directly instead:

```bash
claude --model us.anthropic.claude-opus-4-8      # prior Opus
claude --model us.anthropic.claude-sonnet-4-6    # prior Sonnet
```

Or switch mid-session with `/model us.anthropic.claude-opus-4-8`.

---

## Available Bedrock model IDs

Every ID below was confirmed present with `aws bedrock list-inference-profiles`
and confirmed to return a completion with `aws bedrock-runtime converse`
(verified 2026-08-27, `us-east-1`).

| Model | Bedrock inference profile ID | Context | Verified |
|---|---|---|---|
| Opus 5 | `us.anthropic.claude-opus-5` | 1M | ✅ works |
| Opus 4.8 | `us.anthropic.claude-opus-4-8` | 1M | ✅ works |
| Sonnet 5 | `us.anthropic.claude-sonnet-5` | 1M | ✅ works |
| Sonnet 4.6 | `us.anthropic.claude-sonnet-4-6` | 1M | ✅ works |
| Haiku 4.5 | `us.anthropic.claude-haiku-4-5-20251001-v1:0` | **200K** | ✅ works |
| Fable 5 | `us.anthropic.claude-fable-5` | 1M | ⚠️ blocked — see below |

### Two things that trip people up

**Current model IDs carry no date suffix.** `us.anthropic.claude-opus-5` is the
complete ID. There is no `us.anthropic.claude-opus-5-20251201-v1:0`. Only the
older-generation profiles (Haiku 4.5, Sonnet 4.5, the Claude 3 family) keep the
dated `...-v1:0` form. Don't pattern-match a date onto a newer model — the ID
simply won't resolve.

**Haiku 4.5 has no 1M variant.** It is 200K, full stop. Every other model in the
table is 1M natively — there's no separate "1M version" to select and no suffix to
add. If you want a 1M context window, you want anything other than Haiku.

### Fable 5 is blocked on this AWS account

The profile exists and appears in the picker, but invoking it fails:

```
ValidationException: data retention mode 'default' is not available for this model
```

Fable 5 requires 30-day data retention and isn't available under zero data
retention. This is an org-level AWS/Bedrock configuration, not something the
settings file can fix — talk to Batten IT if you need it. Until then, treat the
**Fable** entry in the picker as non-functional and use Opus 5 instead.

`Fable` is hardcoded into the extension's picker, so it appears whether or not it
works. You cannot remove it via the settings file.

### Checking what your AWS account actually has

```bash
aws bedrock list-inference-profiles --region us-east-1 \
  --query 'inferenceProfileSummaries[?contains(inferenceProfileId, `claude`)].inferenceProfileId' \
  --output text | tr '\t' '\n' | sort
```

Some models require opt-in through the AWS Console: **Bedrock → Model access →
request access**. Usually instant.

---

## Troubleshooting

**Run this first:**

```bash
ccdiagnose
```

It checks Docker, the container, the port, disk space, volumes, your workspace
folder and whether the container is really mounting it, your sign-in setup, and
whether the browser IDE is exposed to your network — and suggests a fix for each
problem it finds.

<details>
<summary>Commands and container</summary>

**`ccdocker: command not found`**
Open a *new* terminal window. If it persists, run
`bash scripts/installers/setup-shortcuts.sh` from your cc-install folder
(`.\scripts\installers\setup-shortcuts.ps1` on Windows).

**`[ERROR] Docker daemon is not running`**
Start Docker Desktop, wait for it to finish loading, try again.

**`port 8080 is already allocated`**
Copy `docs/docker-compose.override.yml.example` to `docker-compose.override.yml`
in the repo root and uncomment the port block, which uses `ports: !override`. The
`!override` tag matters — without it Compose appends and you publish both ports.
`ccvscode` reads the new port back from Compose automatically.

**Container won't start**
`docker compose logs` to see why, then `ccupdate` to rebuild.

**`claude: command not found` inside the container**
Give the container ~10 seconds to finish starting. If it persists, `ccupdate`.

**Build fails**
Check your internet connection, confirm ~3 GB of free disk space, and check Docker
Desktop has enough resources (Settings → Resources). Then retry.

**Claude Code keeps asking me to sign in**
See [docs/CREDENTIALS.md](docs/CREDENTIALS.md) — usually a leftover
`ANTHROPIC_API_KEY` in `.env` overriding your account login.
</details>

<details>
<summary>Workspace folder</summary>

**The folder is empty in the IDE**
Almost always Docker Desktop not sharing that path. On macOS it shares `/Users`,
`/Volumes`, `/private` and `/tmp` by default; anything else mounts empty with no
error. Add it under Docker Desktop → Settings → Resources → File sharing, then
`ccrestart`.

**`ccdiagnose` says the container is mounting a different folder**
A bind mount is fixed at container creation, so a `.env` change needs a recreate,
not a restart. Run `ccrestart`.

**I edited `CC_WORKSPACE` by hand and it broke**
Compose doesn't expand `~`, and relative paths resolve against whatever directory
you were in. Use `ccpath --reset` and set it again with `ccpath /full/path`.
</details>

<details>
<summary>Bedrock model picker</summary>

**Picker still shows old models**
1. Verify the settings saved:
   `docker compose exec claude-code bash -c 'jq .env ~/.claude/settings.json'`
2. Hard refresh the VS Code browser tab: Cmd/Ctrl + Shift + R
3. `ccrestart`

**A model is in the picker but fails when used**
1. **Wrong ID format** — current models take no date suffix. This is the most
   common cause. Check against the [verified table](#available-bedrock-model-ids).
2. **Not available in your region or account** — run the
   `list-inference-profiles` command above.
3. **No model access** — AWS Console → Bedrock → Model access.
4. **IAM permissions** — your credentials need `bedrock:InvokeModel`.
5. **Fable 5 specifically** — blocked at org level, see above.

**Settings keep reverting**
`~/.claude` is a Docker volume, so settings survive container restarts, host
reboots and Docker updates. They're lost only if you delete the volume
(`docker volume rm cc-install_claude-config`) or run the uninstaller and confirm
volume removal. To keep a copy:
`docker compose exec claude-code cat ~/.claude/settings.json > claude-settings-backup.json`
</details>

---

## Uninstalling

```bash
./scripts/maintenance/uninstall.sh      # or uninstall.ps1 on Windows
```

Stops and removes the container, removes the image, and removes the Docker volumes
(with confirmation). Your workspace is **not** deleted unless you explicitly
confirm — and if you've relocated it with `ccpath`, it's outside the install
directory entirely and is never touched.

---

## File locations

| What | Where | Persists? |
|---|---|---|
| Your files | `cc-install/workspace/`, or wherever `ccpath` points | ✅ On your computer |
| Credentials | `.env` in the install directory, `chmod 600` | ✅ Survives `ccupdate` |
| Claude Code settings | `~/.claude/settings.json` (in container) | ✅ Docker volume `claude-config` |
| VS Code settings and extensions | `~/.local/share/code-server/` (in container) | ✅ Docker volume `code-server-data` |
| Local Compose tweaks | `docker-compose.override.yml` in the install directory | ✅ Gitignored, survives `ccupdate` |
| Model picker list | Hardcoded in the extension, plus three overrides from settings | ⚠️ Only 3 customisable |

### Security

- The container runs as a non-root user, isolated from your host filesystem apart
  from your workspace folder.
- The browser IDE is published on **`127.0.0.1` only** — reachable from your
  computer and nothing else. It runs without a password on that basis; anyone who
  can open the page gets a shell in the container, so if you expose the port to
  your network, set `CC_VSCODE_PASSWORD` in `.env` first.
- **`.env` is the only place credentials belong.** It's plain text, `chmod 600`,
  and gitignored. Don't put AWS keys or API keys into
  `~/.claude/settings.json` — anything in its `env` block overrides the
  environment, so a stale key there silently shadows the good one in `.env` and
  breaks authentication in a way that's hard to trace.
- Use IAM credentials with minimal permissions — `bedrock:InvokeModel` is enough
  for Bedrock use. Temporary credentials with `AWS_SESSION_TOKEN` are better still.
- `ccdiagnose` flags an exposed port or loose `.env` permissions.

---

## See also

- [README.md](README.md) — what this is and how to install it
- [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md) — one-page command card
- [docs/CREDENTIALS.md](docs/CREDENTIALS.md) — signing in, including Bedrock and SSO
- [docs/INSTALL_GUIDE.md](docs/INSTALL_GUIDE.md) — step-by-step install for non-technical users
- [docs/installGuides/](docs/installGuides/) — printable visual guide and tip sheet
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) — for maintainers
- [ROADMAP.md](ROADMAP.md) — planned work, including multiple instances
- AWS Bedrock model IDs — <https://docs.aws.amazon.com/bedrock/latest/userguide/model-ids.html>
- Claude Code docs — <https://code.claude.com/docs>
