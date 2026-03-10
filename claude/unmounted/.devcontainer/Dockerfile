# Base debian build (latest).
FROM mcr.microsoft.com/vscode/devcontainers/base:debian

# Update packages.
RUN apt-get update

# Set the default shell to zsh
ENV SHELL=/usr/bin/zsh

# Running everything under zsh
SHELL ["/usr/bin/zsh", "-c"]

# Dropping privileges
USER vscode

# Install Claude Code via native installer
RUN curl -fsSL https://claude.ai/install.sh | bash

# Add claude to shell configuration
RUN echo 'export PATH="/home/vscode/.claude/local/bin:$PATH"' >> ~/.zshrc

# Clean up
RUN sudo apt-get autoremove -y && sudo apt-get clean -y
