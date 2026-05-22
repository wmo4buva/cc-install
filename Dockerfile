# Claude Code Faculty Installer - Docker Image
# Inspired by DAAF (https://github.com/DAAF-Contribution-Community/daaf)
# Simplified for Claude Code and VS Code Server only

FROM debian:bookworm-slim

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    wget \
    git \
    jq \
    sudo \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for code-server)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash claudeuser && \
    echo "claudeuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claudeuser && \
    chmod 0440 /etc/sudoers.d/claudeuser

# Install code-server (VS Code in browser)
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version=4.117.0

# Switch to non-root user for remaining installations
USER claudeuser
WORKDIR /home/claudeuser

# Install Claude Code CLI
RUN curl -fsSL https://console.anthropic.com/install.sh | bash

# Ensure Claude Code is in PATH
ENV PATH="/home/claudeuser/.local/bin:${PATH}"

# Create workspace directory
RUN mkdir -p /home/claudeuser/workspace

# Set working directory
WORKDIR /home/claudeuser/workspace

# Expose code-server port
EXPOSE 8080

# Default command (can be overridden)
CMD ["bash"]
