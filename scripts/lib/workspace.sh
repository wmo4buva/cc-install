#!/usr/bin/env bash
# Shared workspace-path resolution (macOS/Linux).
#
# Sourced by the launchers and maintenance scripts so every one of them agrees on
# where the user's files actually live on the host. Before this existed, six
# scripts hardcoded ./workspace; once the mount became relocatable that meant
# `ccbackup` would happily archive an empty ./workspace while the real files sat
# somewhere else entirely.
#
# Resolution order deliberately mirrors what Docker Compose does when it
# interpolates ${CC_WORKSPACE:-./workspace} in docker-compose.yml:
#   1. the shell environment
#   2. .env in the install directory
#   3. the ./workspace default
# If these two ever disagree, the scripts operate on a different directory than
# the container mounts — so keep them in lockstep.
#
# Sourced, not executed. Every function is prefixed cc_ to avoid colliding with
# the sourcing script.

# Absolute-path check that doesn't depend on realpath/readlink -f (macOS ships
# neither in a form we can rely on).
cc_is_absolute() {
    case "$1" in
        /*) return 0 ;;
        *)  return 1 ;;
    esac
}

# Reads CC_WORKSPACE out of .env. Returns empty if unset or commented out.
# Takes the LAST assignment, matching how a shell would source the file.
cc_workspace_from_env_file() {
    local env_file="${1:-.env}" raw=""

    [ -f "$env_file" ] || return 0

    raw="$(grep -E '^[[:space:]]*CC_WORKSPACE[[:space:]]*=' "$env_file" 2>/dev/null | tail -1)" || true
    [ -n "$raw" ] || return 0

    # Strip the key, then surrounding quotes. Compose treats quotes as optional
    # in .env, so a hand-edited CC_WORKSPACE="/some/path" has to work too.
    raw="${raw#*=}"
    raw="${raw#\"}" ; raw="${raw%\"}"
    raw="${raw#\'}" ; raw="${raw%\'}"

    printf '%s' "$raw"
}

# The host workspace directory. Always prints something.
cc_workspace_dir() {
    local dir="${CC_WORKSPACE:-}"

    [ -n "$dir" ] || dir="$(cc_workspace_from_env_file)"
    [ -n "$dir" ] || dir="./workspace"

    printf '%s' "$dir"
}

# True when the workspace has been pointed away from the bundled default.
cc_workspace_is_relocated() {
    local dir
    dir="$(cc_workspace_dir)"
    [ "$dir" != "./workspace" ] && [ "$dir" != "workspace" ]
}

# A label for user-facing output: shows the path, and flags it as relocated so
# people aren't confused about why ./workspace looks empty.
cc_workspace_label() {
    local dir
    dir="$(cc_workspace_dir)"
    if cc_workspace_is_relocated; then
        printf '%s (relocated via ccpath)' "$dir"
    else
        printf '%s' "$dir"
    fi
}

# Compare a bind-mount source reported by `docker inspect` against a host path.
#
# Docker Desktop does NOT echo back the path you gave it. On macOS and Windows it
# reports bind sources through its VM, prefixed with /host_mnt — so the configured
# /Users/you/cc-install/workspace comes back as
# /host_mnt/Users/you/cc-install/workspace, and C:\Users\you as /host_mnt/c/Users/you.
# A naive string compare therefore reports a mismatch on every Docker Desktop
# install, which is worse than not checking at all: it tells people to recreate a
# container that is already correct, and trains them to ignore the warning when a
# real mismatch happens. Native Linux Docker returns the path unchanged.
cc_normalise_mount_path() {
    local p="$1"

    p="$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]' | tr '\\' '/')"
    p="${p%/}"
    p="${p#/host_mnt}"

    # /c/users/... (Docker's form for a Windows drive) -> c:/users/...
    case "$p" in
        /[a-z]/*) p="${p#/}" ; p="${p%%/*}:/${p#*/}" ;;
    esac

    printf '%s' "$p"
}

cc_mount_matches() {
    local a b
    a="$(cc_normalise_mount_path "$1")"
    b="$(cc_normalise_mount_path "$2")"
    [ "$a" = "$b" ]
}

# Compose does NOT expand ~, so a hand-edited CC_WORKSPACE=~/foo would create a
# directory literally named "~". ccpath always writes absolute paths; this
# catches the case where someone edited .env by hand. Returns 1 on a bad value.
cc_workspace_validate() {
    local dir
    dir="$(cc_workspace_dir)"

    case "$dir" in
        "~"*)
            echo "CC_WORKSPACE in .env starts with '~': $dir" >&2
            echo "Docker Compose does not expand ~, so this would mount a folder" >&2
            echo "literally named '~'. Fix it with: ccpath \"\$HOME/${dir#\~/}\"" >&2
            return 1
            ;;
    esac

    # Relative paths other than the bundled default are a footgun: they resolve
    # against whatever directory the caller happened to be in.
    if ! cc_is_absolute "$dir" && [ "$dir" != "./workspace" ] && [ "$dir" != "workspace" ]; then
        echo "CC_WORKSPACE in .env is a relative path: $dir" >&2
        echo "Use an absolute path so it resolves the same from any directory." >&2
        echo "Fix it with: ccpath /full/path/to/folder" >&2
        return 1
    fi

    return 0
}
