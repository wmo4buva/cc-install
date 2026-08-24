# Quick Reference

One page, everything you'll actually use.

## Commands (work from anywhere)

```bash
ccauth        # set up or change how you sign in    ← run this first
ccdocker      # Claude Code in your terminal
ccvscode      # VS Code in your browser (http://localhost:8080)
ccstop        # stop the container
ccrestart     # restart it (applies .env changes)
cclogs        # view container logs
ccdiagnose    # check the install for problems
ccupdate      # update to the latest version
```

Shortcut not found? Open a **new** terminal window.

## Claude Code in the browser IDE

There is no Claude Code button. In VS Code: **Terminal → New Terminal**, then
type `claude`. Same sign-in and settings as `ccdocker`.

→ [CREDENTIALS.md](CREDENTIALS.md)

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
./claude                                          # Claude Code       (Windows: claude.cmd)
./vscode                                          # VS Code Server    (Windows: vscode.cmd)
./scripts/installers/setup-credentials.sh         # same as ccauth
./scripts/maintenance/diagnose.sh                 # same as ccdiagnose
./scripts/maintenance/update.sh                   # same as ccupdate
./scripts/maintenance/backup.sh                   # archive workspace/
./scripts/maintenance/restore.sh backup.tar.gz    # restore one
./scripts/maintenance/uninstall.sh                # remove everything
```

`run_claude.sh` also takes: `bash`, `logs`, `stop`, `restart`, `auth`.

Windows: same paths with `.ps1`.

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

**Port 8080 in use** — copy `docker-compose.override.yml.example` to
`docker-compose.override.yml`, set the port to `127.0.0.1:8081:8080`, then use
`http://localhost:8081`.

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
| Build time | 5-10 min |
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
./scripts/maintenance/backup.sh    # 1. back up
ccupdate                           # 2. update scripts + image
ccdocker --version                 # 3. confirm
```

If something broke: `./scripts/maintenance/restore.sh backups/<file>`

## Docs

- [README.md](../README.md) — install and usage
- [CREDENTIALS.md](CREDENTIALS.md) — signing in
- [INSTALL_GUIDE.md](INSTALL_GUIDE.md) — step-by-step, non-technical
- [../SECURITY.md](../SECURITY.md) — security posture and trade-offs
- [DEVELOPMENT.md](DEVELOPMENT.md) — for maintainers
- [../CHANGELOG.md](../CHANGELOG.md) — what changed
