# Security model — Cyfrin Claude dev container

This container runs Claude Code with `bypassPermissions` (no per-command prompts)
against code you don't fully trust, while keeping the blast radius inside a
disposable container. Inspired by
[The Red Guild](https://blog.theredguild.org/where-do-you-run-your-code/); hardening
patterns adapted from
[Trail of Bits](https://github.com/trailofbits/claude-code-devcontainer) (MIT) and
[Anthropic's reference devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer).

> It is **not** an airtight jail. A container shares the host kernel, and — as
> Anthropic states for their own devcontainer — with `bypassPermissions` a malicious
> project can still misuse anything the container can reach. This *limits* damage; it
> does not eliminate it. For a harder boundary, use a VM.

## Two variants

- **`unmounted`** — workspace is an in-memory `tmpfs`. Nothing persists; destroy the
  container and it's gone. Strongest isolation; use it for reviewing untrusted code.
- **`mounted`** — your project folder is bind-mounted read-write so work persists.
  `.git/hooks`, `.git/config`, and `.devcontainer/` are re-mounted **read-only** so
  code in the container can't plant a host-side git hook or rewrite the container
  config.

## Default posture: nothing you didn't ask for

Both variants start with **zero host credentials, no sudo, and a default-deny
network**:

- **No credentials** — no Claude token, no git identity, no GitHub auth, no SSH.
- **No sudo** — `vscode` may run *only* the firewall script as root (see below).
- **Default-deny egress** — only an allowlist of hosts is reachable, on 80/443 only.

You opt into exactly what you need. The rule: **the config (or the CLI flag) is the
contract — you can always tell your posture.**

## What's sandboxed, what isn't

| Sandboxed | Not sandboxed |
|-----------|---------------|
| Host filesystem (only the mounted project — nothing else) | Kernel (shared; container-escape 0-days possible) |
| Processes / PID namespace | Egress to allowlisted hosts (each is a deliberate hole) |
| Package installs (stay in the container) | Anything you explicitly opt into (below) |

## CLI vs. the VS Code / Cursor app

**How you open the container changes what your host forwards into it.**

| | `lair` / `devcontainer` CLI (headless) | VS Code / Cursor app |
|---|---|---|
| SSH agent | not forwarded | **auto-forwarded** unless disabled |
| Git credentials | not shared | **auto-shared** unless disabled |
| Posture | exactly your flags — provable | baseline + whatever the editor forwards |
| Use for | **untrusted / malicious code** | your own, trusted projects |

To make the app match the CLI's isolation, set in your **host** VS Code settings:

```jsonc
"remote.containers.copyGitConfig": false,
"remote.containers.gitCredentialHelperConfigLocation": "none"
```

…and verify by attempting a private `git clone` inside the container (there's a
history of these leaking even when set). Bottom line: **for untrusted code, use the
headless CLI with no flags.**

## Credentials (opt-in)

Everything below is **off by default**. The `lair` CLI exposes these as flags
(`--ssh`/`--sudo` are still manual — Phase 3.1); the manual equivalent is shown too.

| Opt-in | Grants | Risk | Manual equivalent today |
|--------|--------|------|-------------------------|
| `--auth` | Claude auth (forwards host token) | API usage billed to your token | run `claude login` inside |
| `--git-identity` | `~/.gitconfig` (read-only) | identity / signing-key exposure | add a read-only bind mount |
| `--gh` | `gh` CLI + its auth volume | a GitHub token lives in the container | install `gh`; `gh auth login` |
| `--ssh` | host SSH agent + opens port 22 | code can act as you over SSH (highest) | forward `SSH_AUTH_SOCK`; allow 22 |
| `--allow <host>` / `--rpc <url>` | firewall allowlist entry | an egress hole (+ API key if RPC) | edit the allowlist file (below) |
| `--sudo` | blanket passwordless sudo | **voids the firewall** — trusted code only | edit sudoers |
| `--mount <src> <dst>` | bind mount | host data access | add a bind mount |

### Claude auth — review before you authenticate

The container boots **logged out**. Do your cursory review first (read the code,
`rg`, `ast-grep`) while nothing can touch your account, then `claude login` once
you're satisfied. On `mounted`, the per-project `~/.claude` volume persists the
login across rebuilds (log in once); on `unmounted` you log in each session. The
firewall allowlists `api.anthropic.com`, `claude.ai`, and `console.anthropic.com`
so `claude login` works.

## Network firewall

`init-firewall.sh` runs at container start (via the scoped sudoers rule) and sets a
default-deny egress policy. Allowed by default:

- **Anthropic:** `api.anthropic.com`, `claude.ai`, `console.anthropic.com`, `statsig.anthropic.com`
- **Registries:** `registry.npmjs.org`, `pypi.org`, `files.pythonhosted.org`
- **GitHub:** `github.com`, `raw.githubusercontent.com`, `objects.githubusercontent.com`, `codeload.github.com`, plus GitHub's published IP ranges
- DNS (53) and loopback

Only **ports 80 and 443** are allowed to allowlisted hosts — which is what blocks
outbound **SSH (port 22)** and everything else by default.

### Blockchain RPC (Alchemy, Infura, your own node)

RPC providers are **blocked by default** — `forge test --fork-url`, deploy scripts,
etc. will fail until you allowlist the provider's host. Two things to know:

1. **RPC URLs embed your API key** (`…/v2/<KEY>`). The URL itself is a credential —
   keep it in a gitignored `.env`, never commit it. The firewall only needs the
   *host*.
2. **Each allowlist entry is a deliberate egress hole.** A malicious repo could abuse
   an allowlisted host as an exfiltration channel, so allowlist only what a given
   project needs.

### Adding domains — host-side by design

Change the allowlist from the **host** (trusted), then restart the container:

```bash
lair allow eth-mainnet.g.alchemy.com    # appends to .devcontainer/allowed-domains.txt
lair rebuild                            # apply it
```

The allowlist file is **root-owned and not writable by `vscode`**, and the scoped
sudoers rule lets you *run* the firewall but not *edit* the list — so untrusted code
inside can't allowlist its own exfil server. If you trust the code itself (and only
distrust its dependencies), `--sudo` lets you change it from inside.

## Sudo

The base image's blanket passwordless sudo is removed; `vscode` may run only
`/usr/local/bin/init-firewall.sh` as root. This is what stops in-container code from
running `iptables -F` to flush the firewall. `--sudo` restores general sudo for
trusted work — but understand it **voids the egress guarantee**.

## Residual risks (the honest list)

- **Kernel escape** — shared kernel; a VM is the only real fix.
- **SSH agent (app path)** — VS Code forwards it unless disabled; the CLI does not.
- **Exfil to allowlisted hosts** — the firewall can't tell good GitHub traffic from
  bad. Fewer allowlist entries = smaller surface.
- **Claude token once authed** — after `claude login` / `--auth` the token is in the
  container; the firewall keeps it from leaving to non-Anthropic hosts.
- **Not a guarantee** — per Anthropic, devcontainers don't stop a determined
  malicious project from misusing what the container can reach. Treat the container
  as compromisable; keep nothing sensitive in it.

## Strongest posture

Reviewing genuinely untrusted code: **`unmounted` + the headless CLI with no
credential flags + the default firewall + review-before-`claude login`.**
