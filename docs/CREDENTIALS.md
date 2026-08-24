# Signing in to Claude Code

Claude Code needs to know who's paying for it. This page covers how to set that
up, and — the part people get stuck on — **how it works when you use the browser
IDE (`ccvscode`) instead of the terminal.**

---

## The short version

```bash
ccauth
```

Run that once, pick one of three options, done. It applies to **both**
`ccdocker` (terminal) and `ccvscode` (browser IDE).

If a shortcut isn't found, open a new Terminal/PowerShell window first.

---

## Using the browser IDE (`ccvscode`)?

This is the bit that isn't obvious, so it gets its own section.

**There is no Claude Code button in the browser IDE.** VS Code Server is just an
editor. Claude Code is a command you run in its terminal:

1. Run `ccvscode`. Your browser opens `http://localhost:8088`.
2. In VS Code, open **Terminal → New Terminal** (or press <kbd>Ctrl</kbd>+<kbd>`</kbd>).
3. Type `claude` and press Enter.

That terminal is running *inside the container*, so it's the same Claude Code,
with the same settings and the same sign-in, as `ccdocker`.

### Where do the credentials go?

It depends which option you picked:

| How you signed in | Where it's stored | Do you have to do anything in the IDE? |
|---|---|---|
| `ccauth` → Claude account | The `claude-config` Docker volume, after one browser login | **Yes, once** — see below |
| `ccauth` → Anthropic API key | `.env` on your computer | No. `claude` just works. |
| `ccauth` → Amazon Bedrock | `.env` on your computer | No. `claude` just works. |

**If you're using a Claude account**, the one-time sign-in has to happen inside
Claude Code itself. The easiest path is to do it in a normal terminal first:

```bash
ccdocker        # sign in here once, following the prompts
```

After that, `claude` in the browser IDE is already signed in — same volume.

You *can* do it from the IDE terminal instead. One wrinkle: Claude Code prints a
sign-in URL, and <kbd>Ctrl</kbd>/<kbd>Cmd</kbd>-clicking it may not work from a
container terminal. **Select the URL, copy it, and paste it into a new browser
tab.** Then paste the code it gives you back into the terminal.

**Never type an API key or AWS secret into the IDE terminal.** It would apply to
that one session only, and would be lost on the next restart. Use `ccauth`.

`ccvscode` writes a **START-HERE.md** into your workspace with these same
instructions, so it's there in the file explorer when you need it.

---

## The three options in detail

### Option 1 — Your Claude account (recommended for most people)

Uses a Claude Pro, Max, or Team subscription. No keys to manage, no per-token
billing to think about.

```bash
ccauth          # choose 1
ccdocker        # sign in when prompted — happens once
```

Claude Code prints a URL, you log in, you paste back a code. The login is saved
in the `claude-config` Docker volume and survives container restarts, rebuilds
and `ccupdate`.

To sign out: run `ccdocker`, then type `/logout`.

### Option 2 — Anthropic API key

Pay-as-you-go, billed to whoever owns the key.

1. Create a key at <https://console.anthropic.com/settings/keys>
2. `ccauth` → choose 2 → paste the key (input is hidden)

The key is written to `.env` in your cc-install folder, `chmod 600`, and passed
into the container as `ANTHROPIC_API_KEY`.

### Option 3 — Amazon Bedrock (UVA / Batten AWS account)

Usage is billed to the university rather than to you. Ask Batten IT for
credentials if you don't have them.

```bash
ccauth          # choose 3
```

It asks for:

- **AWS Access Key ID** and **Secret Access Key** (hidden input)
- **AWS Region** — defaults to `us-east-1`
- **Session token** — only if you were given temporary credentials
- **Bedrock model ID** — optional; leave blank unless Batten IT gave you one

This writes `CLAUDE_CODE_USE_BEDROCK=1` plus the AWS variables to `.env`.

#### Using AWS SSO instead of long-lived keys

If you sign in with `aws sso login` on your own machine, you can share that
session with the container rather than copying keys:

1. Copy `docker-compose.override.yml.example` to `docker-compose.override.yml`
2. Uncomment the `${HOME}/.aws` volume mount
3. Put `AWS_PROFILE=<your-profile>` in `.env`
4. `ccrestart`

Re-run `aws sso login` **on your computer** (not in the container) when the
session expires, then `ccrestart`.

---

## Only one option at a time

`ccauth` clears the other options when you pick one, on purpose. Set by hand and
you can end up with two, in which case Claude Code silently uses this order:

1. `CLAUDE_CODE_USE_BEDROCK=1` → Bedrock wins
2. `ANTHROPIC_API_KEY` → the key wins
3. neither → your interactive Claude account login

**This is the single most common confusion:** you sign in with your Claude
account, but a leftover `ANTHROPIC_API_KEY` in `.env` overrides it and bills the
wrong place. `ccauth` → option 4 clears everything.

---

## Checking what's set

```bash
ccdiagnose      # macOS/Linux and Windows
```

It reports which option is active, whether the credentials are actually present,
whether `.env` has safe permissions, and whether your browser IDE is exposed
beyond your own machine.

---

## Where things are stored

| What | Where | Survives rebuild? |
|---|---|---|
| API key / AWS credentials | `.env` in your cc-install folder | Yes |
| Claude account login | `claude-config` Docker volume | Yes |
| Claude Code settings, skills | `claude-config` Docker volume | Yes |
| Your files | `workspace/` on your computer | Yes |

`.env` holds secrets in plain text. It's gitignored and set to `chmod 600`
(owner-only). Don't email it, don't commit it, don't put it in a shared folder.

---

## Browser IDE security

`ccvscode` runs code-server with **no password**, because Docker publishes the
port on `127.0.0.1` only — reachable from your computer and nothing else.

Anyone who *can* open that page gets a full shell in the container, so if you
change the port binding to expose it on your network, set a password first:

```bash
# in .env
CC_VSCODE_PASSWORD=something-long-and-random
```

Then `ccrestart` and `ccvscode`. `ccdiagnose` warns you if the port is exposed
without a password.

---

## Troubleshooting

**"It asks me to sign in every single time."**
Something is wiping the volume, or you're signing in inside the IDE terminal
without completing the browser step. Run `ccdiagnose` and check the sign-in
section. Then run `ccauth` and set it up properly.

**"I ran `ccauth` but Claude Code still asks for credentials."**
The container needs restarting to pick up `.env`. `ccauth` does this for you,
but if Docker wasn't running at the time it can't — run `ccrestart`.

**"I typed my API key into Claude Code and now it's gone."**
Expected: keys typed at a prompt aren't persisted. Run `ccauth` instead.

**"I get an AWS credentials or region error."**
Run `ccdiagnose`. Most often `CLAUDE_CODE_USE_BEDROCK=1` is set but the keys are
missing or expired, or the region has no Bedrock model access. Confirm with
Batten IT which region and model your account is entitled to.

**"`ccauth` says command not found."**
Open a new Terminal/PowerShell window. If it still fails, run
`bash scripts/installers/setup-shortcuts.sh` (or the `.ps1` on Windows) from
your cc-install folder.

**"Can I edit `.env` by hand?"**
Yes. `.env.example` documents every variable. Run `ccrestart` afterwards.
