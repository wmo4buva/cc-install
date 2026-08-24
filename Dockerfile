# Claude Code Installer - Docker Image
# Inspired by DAAF (https://github.com/DAAF-Contribution-Community/daaf)
# Ships Claude Code CLI + code-server (VS Code in the browser).

FROM debian:bookworm-slim

# Pin the moving parts here so `update.sh` picks up new versions on rebuild.
ARG CODE_SERVER_VERSION=4.133.0
ARG NODE_MAJOR=22

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies.
#   git/curl/wget/jq  - Claude Code and everyday work
#   ripgrep           - Claude Code's file search is much faster with it
#   less              - pagers used by git and Claude Code
#   procps            - pgrep, used by the launchers to detect code-server
#   unzip             - code-server extension installs
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    less \
    procps \
    ripgrep \
    sudo \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Node.js (required by code-server)
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd -m -u 1000 -s /bin/bash claudeuser && \
    echo "claudeuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claudeuser && \
    chmod 0440 /etc/sudoers.d/claudeuser

# code-server (VS Code in the browser)
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version="${CODE_SERVER_VERSION}"

# Bundled Claude Code skills.
#
# These live in /opt, NOT in ~/.claude/skills. ~/.claude is a Docker volume, and
# a volume is only seeded from the image the FIRST time it is created. If the
# skills were baked into ~/.claude/skills they would be frozen at whatever the
# very first build shipped, and `update.sh` could never refresh them. The
# entrypoint copies them into ~/.claude/skills on every container start instead.
RUN mkdir -p /opt/cc-install/skills && \
    for repo in \
        https://github.com/anthropics/skills \
        https://github.com/multica-ai/andrej-karpathy-skills \
        https://github.com/obra/superpowers ; do \
        dir="$(mktemp -d)" ; \
        if git clone --depth 1 "$repo" "$dir" 2>/dev/null && [ -d "$dir/skills" ]; then \
            cp -R "$dir/skills/." /opt/cc-install/skills/ ; \
            echo "bundled skills from $repo" ; \
        else \
            echo "WARNING: could not bundle skills from $repo" >&2 ; \
        fi ; \
        rm -rf "$dir" ; \
    done && \
    chown -R claudeuser:claudeuser /opt/cc-install && \
    ls -1 /opt/cc-install/skills

COPY --chmod=0755 scripts/container/entrypoint.sh /usr/local/bin/cc-entrypoint

USER claudeuser
WORKDIR /home/claudeuser

# Claude Code CLI
RUN curl -fsSL https://claude.ai/install.sh | bash

# ~/.local/bin holds the claude binary. Set it in ENV (for `docker compose exec`)
# and in .bashrc (for interactive shells spawned by code-server's terminal).
ENV PATH="/home/claudeuser/.local/bin:${PATH}"
RUN printf '\n# Added by cc-install\nexport PATH="$HOME/.local/bin:$PATH"\n' >> /home/claudeuser/.bashrc

RUN mkdir -p /home/claudeuser/workspace

# Create code-server's data directory NOW, owned by claudeuser, because
# docker-compose.yml mounts a named volume over it.
#
# Docker copies ownership and contents from the image path when it initializes an
# empty named volume — but if the path does NOT exist in the image, it creates the
# mountpoint as root:root instead. claudeuser (UID 1000) then can't write there,
# which makes code-server throw `EACCES: permission denied, mkdir .../coder-logs`
# on startup and makes every extension install fail. Verified both ways.
RUN mkdir -p /home/claudeuser/.local/share/code-server/extensions

# Optionally bake the Claude Code VS Code extension into the image.
#
# Off by default on purpose: it costs ~670 MB, because the extension ships its own
# per-platform Claude binary in resources/native-binary/ — a ~326 MB duplicate of
# the CLI this image already installs at the same version. Users can install it
# from the Extensions panel in seconds instead (it's on Open VSX, which is the
# registry code-server uses).
#
# Turn it on for a fleet build with either:
#   docker compose build --build-arg INSTALL_VSCODE_EXTENSION=1
#   CC_INSTALL_VSCODE_EXTENSION=1 in .env, then ccupdate
ARG INSTALL_VSCODE_EXTENSION=0
RUN if [ "$INSTALL_VSCODE_EXTENSION" = "1" ]; then \
        echo "Installing the Claude Code VS Code extension into the image..." ; \
        code-server --install-extension Anthropic.claude-code || \
            echo "WARNING: could not pre-install the extension; users can add it from the Extensions panel" >&2 ; \
    else \
        echo "Skipping VS Code extension pre-install (INSTALL_VSCODE_EXTENSION=0)" ; \
    fi

WORKDIR /home/claudeuser/workspace

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/cc-entrypoint"]
CMD ["sleep", "infinity"]
