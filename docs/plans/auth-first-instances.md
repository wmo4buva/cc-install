# Auth-first, instance-aware installer

## Context

### Why

Two problems, both on [ROADMAP.md](../../ROADMAP.md):

1. **One install serves one billing pathway.** `ccauth` overwrites `.env` when you
   switch, so the previous configuration is lost. There's no way to have Bedrock
   and Anthropic available at once.
2. **A second instance can't run.** Verified: `container_name: cc-install` is
   absolute and not namespaced by Compose project, so instance two dies with
   `Conflict. The container name "/cc-install" is already in use`.

Separately, the current install flow puts sign-in **after** a 10-15 minute build.
The most likely failure — the user doesn't have Bedrock credentials yet — surfaces
at minute 15, after which they still need to open a new terminal, run `ccauth`,
then `ccdocker`. Four post-install steps.

### Does auth-first alone solve the two roadmap themes?

**No — and this was the question that prompted this plan.** Auth-first changes
*when* you're asked, not how many pathways can coexist.

| | Auth-first alone | Auth-first + instance-aware |
|---|---|---|
| Theme 1 — both backends | ✗ still one `.env`, switching destroys config | ✓ via two instances |
| Theme 2 — multiple instances | ✗ touches none of the blockers | ✓ |
| Fail fast on missing credentials | ✓ | ✓ |
| Fewer post-install steps | ✓ | ✓ |

So the two are bundled here. The payoff: **roadmap item 1.4 (saved `.env` profiles)
gets deleted rather than built** — with instances you use a second instance instead
of swapping `.env`.

### Outcome

`bash install.sh` asks how you'll sign in *before* building, and
`bash install.sh --instance bedrock` creates an additional isolated environment
with its own sign-in, port, workspace and shortcuts. Running it three times gives
three containers with three auth pathways.

### What this does NOT solve

- Per-pathway model defaults (roadmap 1.5) — still wanted, small, separate.
- Credential verification after install (roadmap 1.6) — this plan makes it
  natural but doesn't implement it.
- Which Bedrock models/regions the Batten AWS account is entitled to. External
  question for Batten IT; blocks documenting any default model ID.

---

## Decisions taken

- **Root stays the default instance.** Existing `cc-install/.env` and
  `cc-install/workspace/` are untouched and become the "default" instance. Extra
  instances live in `instances/<name>/`. Zero migration, so `ccupdate` cannot
  destroy an existing user's credentials or files.
- **Each instance gets its own workspace**; sharing one is opt-in via
  `docker-compose.override.yml`.
- **Shortcut naming:** bare names stay the default instance (`ccdocker`), named
  instances get a suffix (`ccdocker-bedrock`).

---

## Critical correctness constraint

**For the default instance, do NOT set `COMPOSE_PROJECT_NAME`.**

Compose currently derives the project name from the install directory, so existing
volumes are `<dirname>_claude-config`. Hardcoding `cc-install` would break anyone
who installed with `CC_INSTALL_DIR=something-else` — they'd lose their sign-in and
settings. Letting Compose derive it, exactly as today, preserves existing volumes
regardless of directory name.

Named instances set `COMPOSE_PROJECT_NAME=<dirbasename>-<instance>`.

---

## Design

### Layout

```
cc-install/
├── .env                     default instance credentials   (unchanged)
├── workspace/               default instance files         (unchanged)
├── docker-compose.yml       parameterized
├── instances/
│   ├── bedrock/   .env  workspace/
│   └── personal/  .env  workspace/
└── scripts/lib/
    ├── instance.sh          NEW — shared resolver
    └── instance.ps1         NEW — PowerShell mirror
```

### `docker-compose.yml`

```yaml
services:
  claude-code:
    # container_name removed — Compose derives <project>-claude-code-1
    image: cc-install:latest          # shared across instances, built once
    ports:
      - "127.0.0.1:${CC_PORT:-8080}:8080"
    volumes:
      - ${CC_WORKSPACE:-./workspace}:/home/claudeuser/workspace
      - claude-config:/home/claudeuser/.claude
      - code-server-data:/home/claudeuser/.local/share/code-server
    env_file:
      - path: ${CC_ENV_FILE:-.env}
        required: false
```

Keep the comment block in `docker-compose.yml` warning against bare
`environment:` passthrough entries — that constraint is unchanged and still
load-bearing.

### `scripts/lib/instance.sh` (new)

Sourced by every launcher and maintenance script. Responsibilities:

- Resolve instance from `CC_INSTANCE` (unset ⇒ `default`).
- Export `CC_ENV_FILE`, `CC_WORKSPACE`, `CC_PORT` (read from the instance's
  `.env`, default 8080), and `COMPOSE_PROJECT_NAME` **only for named instances**.
- Provide a `dc()` wrapper so call sites don't repeat flags:

  ```bash
  dc() { docker compose --env-file "$CC_ENV_FILE" "$@"; }
  ```

- `cc_instance_list()` — enumerate `default` plus `instances/*/`.
- `cc_instance_validate <name>` — reject names that aren't `[a-z0-9-]+`, and
  reject `default`.

`scripts/lib/instance.ps1` mirrors this with a `Invoke-Dc` function.

**Verify first (one command, before writing anything else):** that
`${CC_ENV_FILE}` interpolates correctly in the `env_file:` path *and* that
`--env-file` supplies `CC_PORT` for interpolation in the same invocation:

```bash
CC_ENV_FILE=instances/bedrock/.env CC_PORT=8081 \
  docker compose --env-file instances/bedrock/.env config
```

If `env_file` path interpolation doesn't work, fall back to passing the container
env explicitly from the resolver rather than via `env_file:`.

### Port allocation — do NOT count up from 8080

The obvious scheme (8080, 8081, 8082…) is wrong, and would actively break a real
machine — including the one this project is developed on. 8080 is heavily
contended, and consecutive ports above it are worse: a local MLX/LLM setup here
reserves **8080, 8081 and 8082** for Gemma-fast, Qwen-deep and Qwen-vision. Three
instances counting up from 8080 would collide with all three. Because that
tooling's start/stop actions `kill` whatever holds the port, the collision is
destructive in both directions — clicking "Stop Gemma" would kill an instance's
port forward.

Rules:

1. **Allocate from an uncontended base.** Default `CC_PORT_BASE=8790`. Clear of
   8080-8082, 3000/3001, 5000, 5432/5433, 7000, 8000, 9000.
2. **Probe before assigning.** At `ccinstance add`, walk up from the base and skip
   anything already listening. Never assume the base is free.
3. **Record the result** as `CC_PORT=<n>` in the instance's `.env`, so it's stable
   across restarts and never silently reshuffles.
4. **Re-probe on start** and fail naming the process holding the port, rather than
   letting Docker emit a bare `port is already allocated`.
5. **Leave the default instance on 8080** for back-compat — but if 8080 is busy
   during a *new* default install, say so and offer the next free port.

### A hand-written `docker-compose.override.yml` breaks multi-instance

`docker-compose.override.yml` is auto-loaded for **every** instance, because they
share a directory. So a user override containing `ports:` pins *all* instances to
one port and collides them with each other.

Not hypothetical: this is exactly the fix applied to `~/cc-install` to get clear of
the MLX collision, and it would silently defeat instances later.

`ccinstance add` must:

- detect a `ports:` key in `docker-compose.override.yml`,
- refuse to create a second instance while it's present, and
- explain the migration — delete the hand-written block and set `CC_PORT=8088` in
  the instance's `.env`, which achieves the same result through the parameterized
  path.

Then make `CC_PORT` **the** documented way to move a port, and reduce the `ports:`
block in `docker-compose.override.yml.example` to a comment pointing at `CC_PORT`
so nobody hand-writes one again.

**Compose merges lists by appending.** An override without the `!override` tag
publishes both the old and the new port and leaves the conflict in place. Verified
— and it caught me out while fixing the MLX collision, so the example file and
`ccdiagnose` guidance both now say so explicitly.

### Auth-first in `install.sh`

Current `main()` ([install.sh:305-333](../../scripts/installers/install.sh#L305-L333)):

```
preflight_checks → download_files → cd → build_image → start_container
→ initialize_workspace → setup-shortcuts → print_success_message
```

New:

```
preflight_checks → download_files → cd
→ choose_auth            ← NEW, before the 10-15 min build
→ build_image → start_container → initialize_workspace
→ setup-shortcuts → print_success_message   (branched on the auth choice)
```

`choose_auth` calls the existing script rather than duplicating logic:

```bash
CC_SKIP_RESTART=1 bash scripts/installers/setup-credentials.sh
```

Placing it after `download_files` is deliberate — `setup-credentials.sh` requires
`docker-compose.yml` and seeds from `.env.example`, both of which exist only after
extraction. The download is ~3.6 MB, so this still runs within seconds of start.

**Must never block:**
- `CC_INSTALL_SKIP_AUTH=1` skips the step entirely (scripted/IT deployment).
- Auto-skip when non-interactive (`INTERACTIVE=0`, already computed at
  [install.sh:37-42](../../scripts/installers/install.sh#L37-L42)).
- Menu option 5 becomes "Skip for now — set this up later with `ccauth`" instead
  of "Quit without changing anything", so browsing without credentials is a
  first-class choice.

### Changes to `setup-credentials.{sh,ps1}`

Reuse the existing primitives — `strip_auth_vars`, `set_var`, `read_secret`,
`read_plain` at [setup-credentials.sh:45-78](../../scripts/installers/setup-credentials.sh#L45-L78)
are all fine as-is. Three changes:

1. **`restart_container` must honour `CC_SKIP_RESTART`.** It currently runs
   `docker compose up -d --force-recreate`
   ([setup-credentials.sh:80-92](../../scripts/installers/setup-credentials.sh#L80-L92)).
   Called pre-build that would **silently trigger the image build inside the auth
   step**, bypassing `--progress plain`. Skip silently when the flag is set.
2. **`ENV_FILE` comes from the resolver** instead of hardcoded
   `$INSTALL_DIR/.env` ([setup-credentials.sh:30](../../scripts/installers/setup-credentials.sh#L30)).
3. Option 5 relabelled as above.

Keep `-Choice`/`$1` non-interactive selection — it's what makes the non-secret
paths testable.

### Shortcuts — `setup-shortcuts.{sh,ps1}`

The `SHORTCUTS` array and write loop
([setup-shortcuts.sh:18-52](../../scripts/installers/setup-shortcuts.sh#L18-L52))
need two changes:

- Write to `$BIN_DIR/${name}${SUFFIX}` where `SUFFIX` is empty for the default
  instance and `-<instance>` otherwise.
- The generated script exports the instance so launchers resolve it without
  argument parsing:

  ```bash
  cd "$INSTALL_DIR" || { ... }
  CC_INSTANCE=bedrock exec ./scripts/launchers/run_claude.sh "$@"
  ```

This also **fixes the verified collision bug**: today a second install silently
repoints every `cc*` command at itself.

Add `ccinstance` (list / add / remove / default) as a thin wrapper over
`install.sh --instance` and the resolver.

PowerShell equivalent: the managed-block markers and in-place replacement at
`setup-shortcuts.ps1` already handle idempotence — extend `Get-ShortcutBlock` to
take a suffix and emit `$env:CC_INSTANCE` per function.

### Correctness fixes bundled in (bugs today, not new features)

These are why Phase 0 ships first — they're wrong for single-instance users too.

| File | Problem |
|---|---|
| `uninstall.{sh,ps1}` | Hardcodes `docker rmi cc-install:latest` and `docker volume rm cc-install_claude-config`. With instances this removes the **shared image** and possibly the **wrong volume**. Derive from `docker compose config --volumes` / `docker compose images`, scope to the resolved instance, and refuse if other instances still exist. |
| `diagnose.{sh,ps1}` | Greps for a container literally named `cc-install` and inspects `cc-install_claude-config`; port check hardcodes 8080. All three report false failures for any instance. Use compose-derived names and `$CC_PORT`. |
| `update.{sh,ps1}` | Rebuild the shared image once, then recreate each instance. |

### Files touched

78 `docker compose` call sites across 14 files, all routed through `dc` /
`Invoke-Dc`. Same pattern in every file: source the resolver at the top, replace
`docker compose` with the wrapper.

- New: `scripts/lib/instance.sh`, `scripts/lib/instance.ps1`
- `docker-compose.yml`
- `scripts/installers/`: `install.{sh,ps1}`, `setup-credentials.{sh,ps1}`, `setup-shortcuts.{sh,ps1}`
- `scripts/launchers/`: `run_claude.{sh,ps1}`, `run_vscode.{sh,ps1}`
- `scripts/maintenance/`: `update.{sh,ps1}`, `diagnose.{sh,ps1}`, `uninstall.{sh,ps1}`, `backup.{sh,ps1}`
- Docs: `README.md`, `docs/CREDENTIALS.md`, `docs/QUICK_REFERENCE.md`, `docs/INSTALL_GUIDE.md`, `docs/DEVELOPMENT.md`, `ROADMAP.md` (delete item 1.4), `CHANGELOG.md`, `VERSION` → 1.4.0
- Trivial: remove the stray empty `scripts/install/` and `scripts/launcher/` directories

---

## Phases

Each phase leaves the product working and shippable on its own.

**Phase 0 — correctness + parameterization.** Drop `container_name`; add
`${CC_PORT}`, `${CC_WORKSPACE}`, `${CC_ENV_FILE}`; fix the destructive `uninstall`
and the wrong names in `diagnose`. No user-visible feature change. Verify the
interpolation question above before proceeding.

**Phase 1 — auth-first.** Ordering change in `install.sh`, `CC_SKIP_RESTART`,
skip paths, branched closing message. Delivers the UX win independently.

**Phase 2 — named instances.** `scripts/lib/instance.{sh,ps1}`,
`install.sh --instance`, suffixed shortcuts, `ccinstance`.

**Phase 3 — multi-instance maintenance + docs.** `update`/`diagnose`/`backup`
across instances; rewrite the roadmap's "manual recipe" section as the supported
path; delete roadmap item 1.4.

---

## Verification

### Regression — existing single-instance install must be untouched

The highest risk in this plan. Before and after Phase 0:

```bash
docker volume ls | grep claude-config        # name must NOT change
docker compose config                         # port still 127.0.0.1:8080
ccdocker --version ; ccvscode ; ccdiagnose ; ccbackup
```

Then simulate a non-default directory, since that's what the
`COMPOSE_PROJECT_NAME` constraint protects:

```bash
CC_INSTALL_DIR=cc-odd-name bash install.sh
# volumes must be cc-odd-name_claude-config, NOT cc-install_claude-config
```

Confirm a pre-1.4.0 install still works after `ccupdate` — sign-in intact, files
intact, shortcuts refreshed.

### Auth-first

```bash
CC_INSTALL_DRY_RUN=1 bash install.sh              # auth step must not hang
CC_INSTALL_SKIP_AUTH=1 bash install.sh            # skips cleanly
printf '5\n' | bash install.sh                    # "skip for now" path
bash install.sh < /dev/null                       # non-interactive auto-skip
```

Then confirm the trap is closed: with `CC_SKIP_RESTART=1`, no image build is
triggered during the auth step (watch for build output before `Step 2/5`).

**Needs a real terminal, cannot be verified in this environment:** hidden
credential entry during a piped install. The existing overwrite prompt at
[install.sh:136](../../scripts/installers/install.sh#L136)
proves plain `read` works off a reattached `/dev/tty`, but `read -rs` (echo off)
is untested — a `script`-based harness fails because it closes the pty. Test by
hand on macOS and on Windows (`Read-Host -AsSecureString` under `irm | iex`).

### Multiple instances

```bash
bash install.sh                                   # default → Bedrock
bash install.sh --instance personal               # → Claude account
bash install.sh --instance apikey                 # → Anthropic key

docker ps                                         # 3 containers, 3 ports
docker volume ls | grep claude-config             # 3 distinct volumes
ccdocker ; ccdocker-personal ; ccdocker-apikey    # 3 shortcuts, right dirs
```

Prove the isolation that matters: sign in on one instance and confirm the others
are still unauthenticated (`ccdiagnose-personal` reports no sign-in).

Prove the hazard is fixed: `ccinstance remove personal` must leave the shared
image and the other instances intact.

### Cross-platform

```bash
for f in $(find scripts -name '*.sh'); do bash -n "$f" || echo "FAIL $f"; done
docker run --rm -v "$PWD/scripts:/s:ro" mcr.microsoft.com/powershell:lts-ubuntu-22.04 \
  pwsh -NoProfile -Command 'Get-ChildItem /s -Recurse -Filter *.ps1 | ForEach-Object {
    $e=$null; [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$null,[ref]$e)|Out-Null
    if ($e.Count) { Write-Output "FAIL $($_.Name)" } }'
```

Use the `lts-ubuntu-22.04` tag — `:latest` is a 32-bit `linux/arm` image that
hangs under emulation on Apple Silicon.

Full pre-release checklist: `docs/DEVELOPMENT.md`.

---

## Risks

1. **Breaking existing installs' volume names.** Mitigated by not setting
   `COMPOSE_PROJECT_NAME` for the default instance. This is the one thing to get
   right; test with a non-default `CC_INSTALL_DIR`.
1b. **Port collisions with other local services** — see the allocation rules
   above. Counting up from 8080 collides with a common local-LLM port block
   (8080/8081/8082) and the collision is destructive, because that tooling kills
   whoever holds the port. Test on a machine that has such a setup, or simulate by
   binding 8080-8082 before creating instances.
2. **`env_file` path interpolation may not work.** Verify before building on it;
   fallback noted above.
3. **78 call sites is a lot of mechanical edits**, and the `.ps1` half can't be
   run-tested here — only parse-tested. Phase 0 first keeps each step small.
4. **RAM.** Three containers at the default 4 GB limit each will strain a laptop.
   `ccinstance add` should warn and suggest lowering
   `deploy.resources.limits` in `docker-compose.override.yml`.
