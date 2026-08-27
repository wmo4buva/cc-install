# Security

How cc-install handles credentials and isolation, what it deliberately trades
away, and how to report a problem.

## Reporting a vulnerability

Email Batten IT, or open an issue at
<https://github.com/wmo4buva/cc-install/issues>. Don't include credentials,
tokens or AWS keys in an issue.

## What's protected

**Credentials are never in the repository.** `.env` holds them, it's gitignored,
and `ccauth` writes it `chmod 600` (owner-read/write only). `.env.example` is a
template with placeholders. `ccdiagnose` warns if `.env` permissions are loose.

**The container is non-root and unprivileged.** It runs as `claudeuser`
(UID 1000). It is not `privileged`, has no added capabilities, and the Docker
socket is **not** mounted — so a process inside it cannot control Docker or reach
the host.

**Host filesystem exposure is limited to one folder.** Only `./workspace` is bind
mounted. The rest of your machine isn't visible to the container unless you add a
mount yourself in `docker-compose.override.yml`.

**The browser IDE is loopback-only.** `docker-compose.yml` publishes port 8080 as
`127.0.0.1:8080:8080`, so code-server is reachable from your computer and nowhere
else.

**Downloads are HTTPS-only**, from `raw.githubusercontent.com`, `codeload.github.com`,
`claude.ai`, `code-server.dev` and `deb.nodesource.com`.

## Deliberate trade-offs

These are choices, not oversights. Each one buys usability for a
single-user laptop and would need revisiting for a shared or multi-tenant host.

**code-server runs with `--auth none`.** Acceptable *only* because of the
loopback binding above. Anyone who can load that page gets a full shell in the
container. If you change the port binding to expose it on your network, set a
password first:

```bash
# .env
CC_VSCODE_PASSWORD=something-long-and-random
```

`ccdiagnose` flags an exposed port with no password as an error.

**`claudeuser` has passwordless sudo inside the container.** This lets people
`apt install` what they need for their work. It grants root *in the container
only* — with no socket mount and no privileged flag, that is not a path to the
host. Users already have a shell there, so this is convenience rather than a new
privilege. Remove the `/etc/sudoers.d/claudeuser` line in the `docker/Dockerfile` if
your environment can't accept it.

**Install scripts are piped from the network.** `curl … | bash` and `irm … | iex`
are how the one-line install works, and the Dockerfile pipes the official Claude
Code and code-server installers. This trusts GitHub and Anthropic. To review
before running, download first:

```bash
curl -fsSL https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.sh -o install.sh
less install.sh
bash install.sh
```

You can also pin a specific release instead of tracking `main`:

```bash
CC_INSTALL_REF=v1.3.0 bash install.sh
```

**Third-party skills are cloned at build time** from `anthropics/skills`,
`multica-ai/andrej-karpathy-skills` and `obra/superpowers`, unpinned (`--depth 1`
of the default branch). You inherit whatever those repositories contain at build
time. Remove the skills block from the `docker/Dockerfile` if that's not acceptable.

## What to check on your own install

```bash
ccdiagnose
```

Reports which sign-in method is active, whether `.env` permissions are safe, and
whether the browser IDE is exposed beyond your machine.

## Credential precedence

If more than one is configured, Claude Code uses, in order:

1. `CLAUDE_CODE_USE_BEDROCK=1` → Amazon Bedrock
2. `ANTHROPIC_API_KEY` → that key
3. neither → your interactive Claude account login

A leftover `ANTHROPIC_API_KEY` therefore silently overrides an account login and
bills the wrong place. `ccauth` clears the others whenever you pick one, and
`ccauth` → option 4 clears everything. See [docs/CREDENTIALS.md](docs/CREDENTIALS.md).
