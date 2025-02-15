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

# Install node using nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    . ~/.nvm/nvm.sh && \
    nvm install --lts && \
    nvm alias default node

# Install pnpm using corepack
RUN . ~/.nvm/nvm.sh && \
    corepack enable && \
    corepack prepare pnpm@latest --activate


# Add node and pnpm to PATH
ENV PATH="/home/vscode/.local/share/pnpm:/home/vscode/.nvm/versions/node/$(. ~/.nvm/nvm.sh && node -v)/bin:${PATH}"


# Clean up
RUN sudo apt-get autoremove -y && sudo apt-get clean -y