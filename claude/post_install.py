#!/usr/bin/env python3
"""Post-create configuration for the Cyfrin Claude dev container.

Runs once on container creation (via ``postCreateCommand``) to:
- bypass Claude Code's onboarding wizard when an auth token is present,
- enable ``bypassPermissions`` and deny reads of ``.devcontainer``,
- write a tmux config with large scrollback,
- repair ownership of named volumes that mount as root,
- provide a container-local git config without mutating the host's.

Derived from Trail of Bits' claude-code-devcontainer (MIT).
"""

from __future__ import annotations

import contextlib
import json
import os
import subprocess
import sys
from pathlib import Path


def _log(message: str) -> None:
    print(f"[post_install] {message}", file=sys.stderr)


def _config_dir() -> Path:
    """Return Claude's config directory (honors ``CLAUDE_CONFIG_DIR``)."""
    return Path(os.environ.get("CLAUDE_CONFIG_DIR") or str(Path.home() / ".claude"))


def setup_onboarding_bypass() -> None:
    """Seed auth state so ``claude`` skips the interactive onboarding wizard.

    Only runs when ``CLAUDE_CODE_OAUTH_TOKEN`` is set. ``claude -p`` writes its
    config during startup before the API call returns, so a timeout is expected
    and is treated as success once the config file exists.
    """
    if not os.environ.get("CLAUDE_CODE_OAUTH_TOKEN", "").strip():
        _log("No OAuth token; skipping onboarding bypass")
        return

    claude_json = _config_dir() / ".claude.json"
    try:
        subprocess.run(
            ["claude", "-p", "ok"], capture_output=True, text=True, timeout=30
        )
    except subprocess.TimeoutExpired:
        _log("claude -p timed out (expected on cold start)")
    except (FileNotFoundError, OSError) as exc:
        _log(f"Could not run claude ({exc}); skipping onboarding bypass")
        return

    if not claude_json.exists():
        _log(f"{claude_json} not created by claude -p; skipping onboarding bypass")
        return

    config: dict = {}
    with contextlib.suppress(json.JSONDecodeError):
        config = json.loads(claude_json.read_text())
    config["hasCompletedOnboarding"] = True
    claude_json.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    _log(f"Onboarding bypass written: {claude_json}")


def setup_claude_settings() -> None:
    """Enable ``bypassPermissions`` and deny reads of the devcontainer config."""
    config_dir = _config_dir()
    config_dir.mkdir(parents=True, exist_ok=True)
    settings_file = config_dir / "settings.json"

    settings: dict = {}
    if settings_file.exists():
        with contextlib.suppress(json.JSONDecodeError):
            settings = json.loads(settings_file.read_text())

    permissions = settings.setdefault("permissions", {})
    permissions["defaultMode"] = "bypassPermissions"
    deny = permissions.setdefault("deny", [])
    if "Read(.devcontainer/**)" not in deny:
        deny.append("Read(.devcontainer/**)")

    settings_file.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
    _log(f"Claude settings written: {settings_file}")


def setup_tmux_config() -> None:
    """Write a tmux config with large scrollback, mouse support, and vi keys."""
    tmux_conf = Path.home() / ".tmux.conf"
    if tmux_conf.exists():
        return
    tmux_conf.write_text(
        "set-option -g history-limit 200000\n"
        "set -g mouse on\n"
        "setw -g mode-keys vi\n"
        "set -g base-index 1\n"
        "setw -g pane-base-index 1\n"
        "set -g renumber-windows on\n"
        'set -g default-terminal "tmux-256color"\n',
        encoding="utf-8",
    )
    _log(f"tmux config written: {tmux_conf}")


def setup_local_gitconfig() -> None:
    """Write a container-local git config and a global gitignore.

    The host ``~/.gitconfig`` is mounted read-only (mounted variant), so we never
    write to it. ``GIT_CONFIG_GLOBAL`` points git at this local file, which
    optionally includes the host config and adds delta plus an excludes file.
    """
    home = Path.home()
    gitignore = home / ".gitignore_global"
    gitignore.write_text(
        ".claude/\n.DS_Store\n*.pyc\n__pycache__/\n.venv/\nnode_modules/\n*.log\n.env.local\n",
        encoding="utf-8",
    )

    host_gitconfig = home / ".gitconfig"
    include = (
        f"[include]\n    path = {host_gitconfig}\n\n" if host_gitconfig.exists() else ""
    )
    (home / ".gitconfig.local").write_text(
        f"{include}"
        f"[core]\n    excludesfile = {gitignore}\n    pager = delta\n\n"
        "[interactive]\n    diffFilter = delta --color-only\n\n"
        "[delta]\n    navigate = true\n    line-numbers = true\n\n"
        "[merge]\n    conflictstyle = diff3\n",
        encoding="utf-8",
    )
    _log("Local git config written")


def main() -> None:
    """Run every post-create step."""
    _log("Starting post-create configuration...")
    setup_onboarding_bypass()
    setup_claude_settings()
    setup_tmux_config()
    setup_local_gitconfig()
    _log("Configuration complete")


if __name__ == "__main__":
    main()
