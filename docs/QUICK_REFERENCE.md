# Quick Reference

One page, everything you'll actually use.

## Commands (work from anywhere)

```bash
ccauth        # set up or change how you sign in    ← run this first
ccdocker      # Claude Code in your terminal
ccvscode      # VS Code in your browser (http://localhost:8088)
ccstop        # stop the container
ccrestart     # restart it (applies .env changes)
cclogs        # view container logs
ccdiagnose    # check the install for problems
ccbackup      # back up your workspace
ccpath        # change which folder is your workspace
ccupdate      # update to the latest version
```

Shortcut not found? Open a **new** terminal window.

## Claude Code in the browser IDE

There is no Claude Code button. In VS Code: **Terminal → New Terminal**, then
type `claude`. Same sign-in and settings as `ccdocker`.

→ [CREDENTIALS.md](CREDENTIALS.md)

### Extensions in the browser IDE

Extensions panel (<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>X</kbd>) → search →
Install. They persist across `ccupdate`.

```bash
docker compose exec claude-code code-server --install-extension Anthropic.claude-code
docker compose exec claude-code code-server --list-extensions
```

code-server uses **Open VSX**, not the Microsoft Marketplace — a few extensions
aren't available. The Claude Code extension *is* (`Anthropic.claude-code`) and is
optional; `claude` in the terminal works without it.

## Signing in

| Option | When | Stored in |
|---|---|---|
| Claude account | You have Pro/Max/Team | `claude-config` volume |
| Anthropic API key | Personal, pay-as-you-go | `.env` |
| Amazon Bedrock | UVA / Batten AWS account | `.env` |

`ccauth` sets one and clears the others. Only one applies at a time.

## Running the scripts directly

From inside the `cc-install` directory:

```bash
./bin/claude                                          # Claude Code       (Windows: claude.cmd)
./bin/vscode                                          # VS Code Server    (Windows: vscode.cmd)
./scripts/installers/setup-credentials.sh         # same as ccauth
./scripts/maintenance/diagnose.sh                 # same as ccdiagnose
./scripts/maintenance/update.sh                   # same as ccupdate
./scripts/maintenance/backup.sh                   # archive workspace/ (same as ccbackup)
./scripts/maintenance/set-workspace.sh            # change workspace folder (same as ccpath)
./scripts/maintenance/restore.sh backup.tar.gz    # restore one
./scripts/maintenance/uninstall.sh                # remove everything
```

`run_claude.sh` also takes: `bash`, `logs`, `stop`, `restart`, `auth`.

Windows: same paths with `.ps1`.

## Working on your own projects

Claude Code only sees `workspace/`. Drag a project folder into
`cc-install/workspace/` — it appears instantly, no restart.

```
File -> Open Folder -> /home/claudeuser/workspace/my-project    # browser editor
ccdocker bash && cd my-project && claude                        # terminal
```

**Symlinks/aliases pointing outside `workspace/` do not work** — the link is
visible in the container but the files read as missing. Copy the folder instead.

To keep a project where it lives, mount it via `docker-compose.override.yml`
(see the README) and `ccrestart`.

## File locations

| Item | Where |
|---|---|
| Your files | `./workspace/` |
| Credentials | `./.env` (chmod 600, gitignored) |
| Local Compose tweaks | `./docker-compose.override.yml` |
| Backups | `./backups/` |
| Claude config, login, skills | Docker volume `claude-config` |
| VS Code settings, extensions | Docker volume `code-server-data` |
| Shortcuts | `~/.local/bin/cc*` · Windows: your PowerShell profile |
| Container / image | `cc-install` · `cc-install:latest` |

## Raw Docker commands

Only needed if something's badly stuck.

```bash
docker compose ps                    # what's running
docker compose logs -f               # follow logs
docker compose up -d                 # start
docker compose stop                  # stop
docker compose build --no-cache      # rebuild image
docker compose down -v               # remove container AND volumes (destroys your sign-in)
docker stats cc-install              # live resource usage
```

## Troubleshooting

Always start with `ccdiagnose`.

**Container won't start**
```bash
docker compose logs
docker compose down && docker compose up -d
```

**Port 8080 in use** — copy `docs/docker-compose.override.yml.example` to
`docker-compose.override.yml` and uncomment the port block. It uses
`ports: !override`; without that tag Compose appends and publishes both ports.
`ccvscode` picks up the new port automatically.

**Docker not running** — start Docker Desktop, wait for it to finish loading.

**Signed out every time** — see [CREDENTIALS.md](CREDENTIALS.md). Usually a
leftover `ANTHROPIC_API_KEY` in `.env` overriding an account login.

**Start over**
```bash
./scripts/maintenance/uninstall.sh   # then re-run the installer from README.md
```

## What's inside

| | |
|---|---|
| Base OS | Debian Bookworm (slim) |
| Claude Code | latest, at image build time |
| code-server | 4.133.0 |
| Node.js | 22 LTS |
| Image size | ~1.5-2 GB |
| Build time | 10-15 min |
| Container user | `claudeuser` (UID 1000, non-root) |

Check what you're actually running:

```bash
docker compose exec claude-code claude --version
docker compose exec claude-code code-server --version
cat VERSION
```

## Keyboard shortcuts

**VS Code Server** — <kbd>Ctrl</kbd>+<kbd>`</kbd> terminal ·
<kbd>Ctrl</kbd>+<kbd>B</kbd> sidebar · <kbd>Ctrl</kbd>+<kbd>P</kbd> open file ·
<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd> command palette

**Claude Code** — <kbd>Ctrl</kbd>+<kbd>C</kbd> interrupt ·
<kbd>Ctrl</kbd>+<kbd>D</kbd> exit · `/help` commands · `/skills` list skills

## Safe update routine

```bash
ccbackup                           # 1. back up
ccupdate                           # 2. update scripts + image
ccdocker --version                 # 3. confirm
```

If something broke: `./scripts/maintenance/restore.sh backups/<file>`

## Docs

- [RUNBOOK.md](../RUNBOOK.md) — the manual: every command explained
- [README.md](../README.md) — what this is, and how to install it
- [CREDENTIALS.md](CREDENTIALS.md) — signing in
- [INSTALL_GUIDE.md](INSTALL_GUIDE.md) — step-by-step, non-technical
- [../SECURITY.md](../SECURITY.md) — security posture and trade-offs
- [DEVELOPMENT.md](DEVELOPMENT.md) — for maintainers
- [../CHANGELOG.md](../CHANGELOG.md) — what changed
