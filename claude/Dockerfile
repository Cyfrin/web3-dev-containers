# Cyfrin Claude Code dev container (shared by the mounted + unmounted variants).
# Reproducibility: base + source images pinned by digest; downloaded tools pinned
# by ARG and kept current by Renovate. System packages (curl, bash, git, ...) are
# frozen by the base image digest — apt repos only ever serve the latest patch, so
# pinning them with `apt-get install pkg=ver` is not reproducible.
#
# Inspired by The Red Guild (https://blog.theredguild.org/where-do-you-run-your-code/).
# Supply-chain hardening and the `vscode` user pattern are adapted from Trail of
# Bits' claude-code-devcontainer (MIT); firewall patterns from Anthropic's
# reference devcontainer.

# --- uv: static, multi-arch binary copied in below ----------------------------
FROM ghcr.io/astral-sh/uv:0.11.23@sha256:d0a0a753ab981624b49c97abc98821c1c09f4ca69d1ef5cee69c501be3d88479 AS uv

# --- base ---------------------------------------------------------------------
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04@sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae

ARG TZ=UTC
ENV TZ="$TZ"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# System packages (versions frozen by the pinned base image digest; pinning apt
# package versions is not reproducible because the repo only serves the latest).
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    bubblewrap \
    ca-certificates \
    curl \
    dnsutils \
    fd-find \
    git \
    gnupg \
    ipset \
    iptables \
    iproute2 \
    jq \
    nano \
    ripgrep \
    socat \
    tmux \
    unzip \
    vim \
    zsh \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# git-delta (better diffs / pager)
# renovate: datasource=github-releases depName=dandavison/delta
ARG GIT_DELTA_VERSION=0.19.2
RUN ARCH="$(dpkg --print-architecture)" \
  && curl -fsSL "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" -o /tmp/git-delta.deb \
  && dpkg -i /tmp/git-delta.deb \
  && rm /tmp/git-delta.deb

# fzf (newer than apt; ships shell integration)
# renovate: datasource=github-releases depName=junegunn/fzf
ARG FZF_VERSION=0.73.1
RUN ARCH="$(dpkg --print-architecture)" \
  && case "${ARCH}" in \
       amd64) FZF_ARCH="linux_amd64" ;; \
       arm64) FZF_ARCH="linux_arm64" ;; \
       *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; \
     esac \
  && curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${FZF_ARCH}.tar.gz" \
       | tar -xz -C /usr/local/bin

# uv + uvx (static binaries) via multi-stage copy
COPY --from=uv /uv /uvx /usr/local/bin/

# Persisted directories (named volumes mount over these on the mounted variant).
RUN mkdir -p /commandhistory /home/vscode/.claude \
  && touch /commandhistory/.zsh_history \
  && chown -R vscode:vscode /commandhistory /home/vscode/.claude

ENV DEVCONTAINER=true \
    SHELL=/bin/zsh \
    EDITOR=nano \
    VISUAL=nano

# Package-manager supply-chain hardening (block install scripts, enforce a publish
# delay, pin exact versions, no telemetry).
ENV NPM_CONFIG_IGNORE_SCRIPTS=true \
    NPM_CONFIG_SAVE_EXACT=true \
    NPM_CONFIG_AUDIT=true \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_MINIMUM_RELEASE_AGE=1440 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UV_LINK_MODE=copy

# Egress firewall: install the script and replace the base image's blanket
# passwordless sudo with a single scoped rule. vscode may run ONLY the firewall
# as root, so untrusted code can neither flush iptables nor edit the root-owned
# allowlist. `lair --sudo` (LAIR_SUDO=true) keeps blanket sudo for trusted work,
# which voids that guarantee (see claude/SECURITY.md).
ARG LAIR_SUDO=false
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod 0755 /usr/local/bin/init-firewall.sh \
  && mkdir -p /etc/devcontainer \
  && echo 'vscode ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh' >/etc/sudoers.d/vscode-firewall \
  && chmod 0440 /etc/sudoers.d/vscode-firewall \
  && visudo -cf /etc/sudoers.d/vscode-firewall \
  && if [ "${LAIR_SUDO}" != "true" ]; then rm -f /etc/sudoers.d/vscode; fi

WORKDIR /workspace
USER vscode
ENV PATH="/home/vscode/.local/bin:$PATH"

# Python 3.13 (prebuilt download) + ast-grep
RUN uv python install 3.13 --default \
  && uv tool install ast-grep-cli

# Node 22 via fnm
ARG NODE_VERSION=22
ENV FNM_DIR="/home/vscode/.fnm"
RUN curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell \
  && export PATH="$FNM_DIR:$PATH" \
  && eval "$(fnm env)" \
  && fnm install "${NODE_VERSION}" \
  && fnm default "${NODE_VERSION}"

# Foundry (pinned stable; prebuilt glibc binaries verified against release attestations)
# renovate: datasource=github-releases depName=foundry-rs/foundry
ARG FOUNDRY_VERSION=v1.7.1
ENV PATH="/home/vscode/.foundry/bin:$PATH"
RUN curl -fsSL https://foundry.paradigm.xyz | bash \
  && /home/vscode/.foundry/bin/foundryup --install "${FOUNDRY_VERSION}"

# Claude Code (stable channel)
RUN curl -fsSL https://claude.ai/install.sh | bash -s stable

# Oh My Zsh + custom shell config
# renovate: datasource=github-releases depName=deluan/zsh-in-docker
ARG ZSH_IN_DOCKER_VERSION=1.2.1
RUN sh -c "$(curl -fsSL https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- -p git -x

COPY --chown=vscode:vscode .zshrc /home/vscode/.zshrc.custom
RUN echo 'source ~/.zshrc.custom' >> /home/vscode/.zshrc

COPY --chown=vscode:vscode post_install.py /opt/post_install.py
