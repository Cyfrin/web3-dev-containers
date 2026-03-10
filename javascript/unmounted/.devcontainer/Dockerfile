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

# Install nvm and Node.js LTS (provides node and npm)
ENV NVM_DIR="/home/vscode/.nvm"
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && source "$NVM_DIR/nvm.sh" \
    && nvm install --lts \
    && nvm use --lts

# Enable corepack and install pnpm
RUN source "$NVM_DIR/nvm.sh" \
    && corepack enable \
    && corepack prepare pnpm@latest --activate

# Add nvm to shell configuration
RUN echo 'export NVM_DIR="/home/vscode/.nvm"' >> ~/.zshrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"' >> ~/.zshrc

# Clean up
RUN sudo apt-get autoremove -y && sudo apt-get clean -y
