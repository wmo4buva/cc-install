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

WORKDIR /home/claudeuser/workspace

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/cc-entrypoint"]
CMD ["sleep", "infinity"]
