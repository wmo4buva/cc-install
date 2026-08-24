# Roadmap

What's planned for cc-install and why. Two themes drive it:

1. **[Supporting both AWS Bedrock and Anthropic directly](#theme-1--two-auth-backends)** — one
   install currently serves one billing pathway, and people legitimately need both.
2. **[Running several instances side by side](#theme-2--multiple-instances-multiple-auth-pathways)** —
   one user, several containers, a different sign-in in each.

Everything technical below was verified against Docker and the current scripts
rather than assumed. Findings are marked **Verified**; anything unconfirmed is
marked **Unverified** and should be checked before it's built on.

Shipped work lives in [CHANGELOG.md](CHANGELOG.md). Retired plans are in
[archive/v1.2-docs/ROADMAP.md](archive/v1.2-docs/ROADMAP.md).

---

## Where things stand (v1.3.1)

One install → one container → one sign-in, chosen with `ccauth` and stored in
`.env`. That covers the common case well, and the isolation is deliberate: the
three options are mutually exclusive so a leftover key can't silently bill the
wrong account.

The limits worth fixing:

- **One pathway at a time.** Switching from Bedrock to an Anthropic key means
  overwriting `.env` and re-entering credentials. The old configuration is gone.
- **Session state is shared.** One `claude-config` volume, so Claude Code
  settings and history are common to whatever pathway is active.
- **Two instances collide.** Documented and verified below.

---

## Theme 1 — Two auth backends

### Why both are needed

**Amazon Bedrock** is the university pathway. Usage bills to UVA rather than to
an individual, and it keeps traffic inside the AWS account and region UVA has
agreements for. That matters for anything sensitive.

**Anthropic directly** — an API key, or a Pro/Max/Team subscription — is the
simplest to get running, gets new models first, and under a subscription needs no
per-token billing conversation at all.

Neither dominates. Concretely, someone may want Bedrock for coursework and
research data, and an Anthropic subscription for everyday drafting; or they may
need Anthropic direct temporarily because a model they need isn't available on
Bedrock in their region yet.

### What makes this more than a config toggle

- **Model identifiers differ.** Bedrock uses its own IDs and inference profiles
  (`us.anthropic.claude-...-v1:0`); the Anthropic API uses plain model names. A
  setting that's valid on one is invalid on the other, so `ANTHROPIC_MODEL` can't
  be carried across pathways.
- **Bedrock access is per-account, per-region, per-model.** A model has to be
  enabled in the AWS account before it works, and the set enabled at UVA won't
  necessarily match what the Anthropic API offers. **Unverified:** which models
  and regions the Batten AWS account currently has enabled — confirm with Batten
  IT before documenting any specific model ID.
- **Credential lifetime differs.** Long-lived AWS keys, temporary session tokens,
  and AWS SSO all behave differently; SSO in particular expires and needs
  `aws sso login` on the host, not in the container.
- **Precedence is silent.** Claude Code resolves `CLAUDE_CODE_USE_BEDROCK` before
  `ANTHROPIC_API_KEY` before an interactive login. Two things set means one wins
  with no warning — which is exactly why `ccauth` clears the others.

### Plan

**1.4 — Saved profiles (near term).** Keep one container, but stop destroying
configuration on every switch. Store each pathway as `profiles/<name>.env`;
`ccauth` writes and selects them, and switching is a copy plus `ccrestart`.

```bash
ccauth save bedrock        # store the current config under a name
ccauth use anthropic       # switch to another and restart
ccauth list                # show what's saved and which is active
```

Cheap, no compose changes, and it removes the "re-enter your keys" tax. Still one
pathway active at a time.

**1.5 — Per-pathway model defaults.** Record `ANTHROPIC_MODEL` inside each profile
so a Bedrock model ID never leaks into an Anthropic-API session. Validate on
switch and warn rather than fail.

**1.6 — Preflight credential check.** `ccauth` currently saves what it's given
without testing it. Add an opt-in verification call so a typo or an expired key
surfaces immediately instead of at first use. Needs care: it costs a token and
must not log the credential.

**2.0 — Simultaneous.** Genuinely running both at once is Theme 2; it needs
separate containers.

---

## Theme 2 — Multiple instances, multiple auth pathways

The goal: one user, several isolated environments on one machine — say
`bedrock`, `anthropic`, and `personal` — each with its own sign-in, its own
files, its own Claude Code history, running at the same time.

### What already works in your favour

**Verified** by running three Compose projects from one file:

- **Named volumes are namespaced by Compose project automatically.** Three
  projects produced `cc-bedrock_cfg`, `cc-anthropic_cfg`, `cc-personal_cfg`
  without any change to the compose file. So `claude-config` and
  `code-server-data` isolate per instance for free — sign-ins and settings will
  not bleed across.
- **The image can be shared.** All instances can run the same
  `cc-install:latest`, so N instances cost one ~1.8 GB image, not N.
- **`docker compose -p <name> exec …` addresses a specific instance**, so the
  launchers' existing `docker compose` calls are already instance-correct — they
  follow whatever project context they're run in.
- **`run_vscode` already reads its published port back** from
  `docker compose port` instead of assuming 8080, so it will report the right URL
  per instance with no change.

### What blocks it today

**Verified** — a second instance fails immediately:

```
Error response from daemon: Conflict. The container name "/cc-install"
is already in use by container "18d88819b05f…"
```

The full list, from auditing the scripts:

| # | Where | Problem |
|---|---|---|
| 1 | `docker-compose.yml` `container_name: cc-install` | Absolute, not namespaced by project. Hard collision. **Verified.** |
| 2 | `docker-compose.yml` `127.0.0.1:8080:8080` | Second instance can't bind the port. |
| 3 | `docker-compose.yml` `./workspace` | Same path → instances share files. |
| 4 | `setup-shortcuts.{sh,ps1}` | Shortcut names are fixed (`ccdocker`, `ccvscode`, …) and always rewritten. A second install **silently repoints every shortcut at itself**, breaking the first. Sharpest edge here. |
| 5 | `uninstall.{sh,ps1}` | `docker rmi cc-install:latest` and `docker volume rm cc-install_claude-config` are hardcoded. In a multi-instance setup this removes the **shared image** and the **wrong volume**. Data-loss hazard — fix before promoting multi-instance. |
| 6 | `diagnose.{sh,ps1}` | Greps for a container called `cc-install` and inspects `cc-install_claude-config`. Both names change per project, so diagnostics report false failures. |
| 7 | `diagnose.{sh,ps1}` | Port availability check is hardcoded to 8080. |

### Target design

One install, many instances — **not** many copies of the install. Copying the
whole project N times means N sets of scripts to update, N chances to miss a fix,
and a `ccupdate` you have to remember to run N times.

```
cc-install/
├── docker-compose.yml          # parameterized, shared
├── scripts/                    # shared
├── instances/
│   ├── bedrock/   .env  workspace/
│   ├── anthropic/ .env  workspace/
│   └── personal/  .env  workspace/
└── instances/default -> bedrock
```

Each instance is just a name, a `.env`, a workspace, and a port. Compose does the
isolation.

**Compose changes:**

```yaml
services:
  claude-code:
    # container_name removed — let Compose derive <project>-claude-code-1
    image: cc-install:latest              # shared across instances
    ports:
      - "127.0.0.1:${CC_PORT:-8080}:8080"
    volumes:
      - ${CC_WORKSPACE:-./workspace}:/home/claudeuser/workspace
```

**Script changes:** every launcher and maintenance script resolves an instance
(from `--instance <name>`, `$CC_INSTANCE`, or the `default` symlink), then sets
`COMPOSE_PROJECT_NAME=cc-<name>` and points `--env-file` at that instance. Ports
allocate from a base (8080, 8081, 8082…) recorded in the instance's `.env` so
they're stable across restarts.

**Shortcuts:** suffixed per instance, with the bare names kept as aliases for the
default so nothing breaks for single-instance users.

```bash
ccdocker                 # default instance
ccdocker-bedrock         # a specific one
ccvscode-anthropic
ccinstance list|add|remove|default
```

**`ccupdate`** rebuilds the shared image once, then recreates each instance —
still one command.

### Phasing

| Phase | Scope |
|---|---|
| **2.0a** | Parameterize compose (items 1-3). Fix the destructive `uninstall` and the wrong names in `diagnose` (items 5-7) — these are correctness fixes worth doing even for single-instance users. |
| **2.0b** | `ccinstance` command; per-instance `.env`/workspace under `instances/`; port allocation. |
| **2.0c** | Suffixed shortcuts (item 4) with backward-compatible bare names. |
| **2.0d** | Multi-instance `ccupdate` / `ccdiagnose`; docs. |

Doing 2.0a first is deliberate: it's a small change that makes the current
single-instance product more correct, and it's the prerequisite for everything
else.

---

## Running multiple instances today (manual)

This works with v1.3.1 as shipped, before any of the above lands. It's a
reasonable way to try the workflow — but it's manual, and the shortcut collision
means you should drive each instance from its own folder.

**1. Install each instance into its own directory.**

```bash
CC_INSTALL_DIR=cc-bedrock   bash install.sh
CC_INSTALL_DIR=cc-anthropic bash install.sh
```

Because Compose derives its project name from the directory name, each gets its
own volumes automatically — `cc-bedrock_claude-config`,
`cc-anthropic_claude-config`. Sign-ins stay separate with no extra work.
**Verified.**

**2. In every instance after the first, edit two lines of `docker-compose.yml`.**

```yaml
    # container_name: cc-install        <- delete or rename this line
    ports:
      - "127.0.0.1:8081:8080"          <- a unique port per instance
```

Leaving `container_name` in place is the collision above. Deleting it is
simplest; Compose then names the container after the project.

**3. Set the sign-in per instance, from inside each directory.**

```bash
cd cc-bedrock   && ./scripts/installers/setup-credentials.sh   # choose 3, Bedrock
cd ../cc-anthropic && ./scripts/installers/setup-credentials.sh # choose 1 or 2
```

Call the script by path, **not** the global `ccauth` shortcut — the shortcut
points at whichever install ran last.

**4. Launch from inside each directory.**

```bash
cd cc-bedrock && ./claude     # or ./vscode
```

The `./claude` and `./vscode` wrappers resolve relative to their own folder, so
they're always instance-correct. **Verified.**

**5. Know the rough edges.**

- Global `cc*` shortcuts point at the last install. Either use `./claude` per
  folder, or hand-write your own suffixed shortcuts in `~/.local/bin`.
- `ccdiagnose` will report the container and volume as missing in any instance
  not named `cc-install` (item 6). The install still works.
- **Do not run `uninstall.sh` while you have multiple instances** — it removes the
  shared `cc-install:latest` image and the `cc-install_claude-config` volume by
  name, which may not be the instance you're standing in (item 5). Remove an
  instance manually instead:

  ```bash
  cd cc-bedrock && docker compose down -v && cd .. && rm -rf cc-bedrock
  ```

- Each instance is a full container. Budget RAM accordingly — the default limit
  is 4 GB each, so lower `deploy.resources.limits` in
  `docker-compose.override.yml` if you run three at once.

---

## Smaller items

- **`ccdocker <folder>`** — start Claude Code rooted on one project instead of
  always at `workspace/`. Today that needs `ccdocker bash`, `cd`, `claude`.
- **`ccadd <path>`** — attach a host folder without hand-editing
  `docker-compose.override.yml`. Would make [Working on your own
  projects](README.md#working-on-your-own-projects) a command rather than a YAML
  exercise.
- **Pin bundled skills to commit SHAs** for reproducible builds, at the cost of
  manual bumps. See [SECURITY.md](SECURITY.md).
- **Smaller image** via a multi-stage build; currently ~1.8 GB.
- **Real Windows test coverage.** PowerShell is currently validated by parsing
  under 7.4 in a container; nothing runs on Windows 5.1 automatically.
- **UID matching** for Linux hosts whose user isn't UID 1000, which can cause
  `workspace/` permission friction.
- **Regenerate the Visual Guide from a source file.** The HTML is a bundled
  artifact patched in place; the PDF is printed from it with headless Chrome. Fine
  for small edits, awkward for larger ones.

## Not planned

- **Vertex AI.** Claude Code supports it, but there's no UVA GCP pathway to
  justify the third code path.
- **Central fleet management / telemetry.** Nothing is collected today, and
  adding it needs a privacy decision first, not a technical one.
- **Hosting cc-install as a shared server.** It's designed as a single-user
  local tool; code-server runs without a password on that basis. A shared
  deployment is a different product with a different threat model.

## Open questions

- Which Bedrock models and regions is the Batten AWS account entitled to? Needed
  before any model ID is documented or defaulted.
- Do people mostly need to *switch* pathways or *run both at once*? If switching
  is enough, Theme 1's profiles may be sufficient and Theme 2 becomes optional.
- Should the repo move into the `BattenIT` org? It must stay public either way —
  the one-line installer needs unauthenticated archive access.
