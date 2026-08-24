#!/usr/bin/env bash
# Container entrypoint.
#
# Runs on every container start, before the main command. Its only job is to
# refresh the bundled skills into ~/.claude, which is a persistent volume.
#
# Why this exists: a Docker volume is seeded from the image exactly once, when
# the volume is first created. Anything baked into ~/.claude in the image is
# therefore invisible to every existing installation after the first run. So the
# skills ship in /opt/cc-install/skills and get copied in here instead.

set -uo pipefail

BUNDLED_SKILLS="/opt/cc-install/skills"
USER_SKILLS="$HOME/.claude/skills"

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
