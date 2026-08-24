#!/usr/bin/env bash
# Container entrypoint.
#
# Runs on every container start, before the main command. It repairs the two
# things that Docker volumes get wrong, both of which are invisible until
# something fails oddly:
#
#   1. Volume ownership. A named volume mounted at a path that does not exist in
#      the image is created root-owned, which locks claudeuser out.
#   2. Bundled skills. A volume is seeded from the image only once, so anything
#      baked into ~/.claude is frozen at the user's very first build.

set -uo pipefail

BUNDLED_SKILLS="/opt/cc-install/skills"
USER_SKILLS="$HOME/.claude/skills"
CODE_SERVER_DATA="$HOME/.local/share/code-server"

# ---------------------------------------------------------------------------
# Make volume-backed directories writable by claudeuser.
#
# Docker copies ownership from the image when it initializes an EMPTY named
# volume. Two cases still end up root-owned:
#   * the path didn't exist in the image when the volume was first created
#     (this shipped in 1.3.0 for code-server-data), or
#   * the volume already has content, so Docker won't re-initialize it — meaning
#     a rebuild alone does NOT fix an existing install.
#
# Symptoms when this is wrong: code-server dies on startup with
# "EACCES: permission denied, mkdir .../coder-logs", and every extension install
# fails. Repairing here is what makes the fix reach existing installs.
# ---------------------------------------------------------------------------
ensure_writable() {
    local dir="$1" label="$2"

    mkdir -p "$dir" 2>/dev/null

    # Cheap check that actually reflects what the process can do, rather than
    # parsing ownership.
    if [ -w "$dir" ] && touch "$dir/.cc-write-probe" 2>/dev/null; then
        rm -f "$dir/.cc-write-probe"
        return 0
    fi

    echo "[cc-install] $label is not writable — repairing ownership" >&2
    if sudo chown -R "$(id -u):$(id -g)" "$dir" 2>/dev/null; then
        echo "[cc-install] $label ownership repaired"
    else
        echo "[cc-install] WARNING: could not repair $label." >&2
        echo "[cc-install]          code-server and extension installs may fail." >&2
        echo "[cc-install]          Run: ccdiagnose" >&2
    fi
}

ensure_writable "$CODE_SERVER_DATA" "code-server data directory"
ensure_writable "$HOME/.claude"     "Claude Code config directory"

# ---------------------------------------------------------------------------
# Refresh bundled skills.
#
# They ship in /opt rather than ~/.claude precisely because a volume is seeded
# from the image only once — anything baked into ~/.claude would be frozen at the
# user's first build forever.
# ---------------------------------------------------------------------------
sync_bundled_skills() {
    [ -d "$BUNDLED_SKILLS" ] || return 0

    mkdir -p "$USER_SKILLS" || return 0

    # cp -R overwrites bundled skills of the same name and leaves anything the
    # user added alone. Failure here must never block container startup.
    if cp -R "$BUNDLED_SKILLS/." "$USER_SKILLS/" 2>/dev/null; then
        echo "[cc-install] skills synced to ~/.claude/skills"
    else
        echo "[cc-install] WARNING: could not sync bundled skills" >&2
    fi
}

sync_bundled_skills

exec "$@"
