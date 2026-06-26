#!/usr/bin/env bash
# Default-deny egress firewall for the Cyfrin Claude dev container.
# Adapted from Anthropic's reference devcontainer (anthropics/claude-code).
#
# Only HTTP/HTTPS (80/443) to an allowlist is permitted over IPv4; IPv6 is
# sealed entirely, DNS is restricted to the container's resolver, and any error
# during setup fails CLOSED (no egress) rather than open. Runs as root at
# container start via a single scoped sudoers rule, so untrusted code in the
# container can neither flush these rules nor edit the (root-owned) allowlist.
set -euo pipefail
IFS=$'\n\t'

if [[ "$(id -u)" -ne 0 ]]; then
  echo "init-firewall: must run as root" >&2
  exit 1
fi

# Fail closed: on ANY unexpected error, drop all egress rather than leave a
# half-configured (possibly wide-open) state in place.
seal() {
  trap - ERR
  echo "init-firewall: error - sealing (dropping all egress)" >&2
  iptables -F 2>/dev/null || true
  iptables -P INPUT DROP 2>/dev/null || true
  iptables -P FORWARD DROP 2>/dev/null || true
  iptables -P OUTPUT DROP 2>/dev/null || true
  ip6tables -F 2>/dev/null || true
  ip6tables -P INPUT DROP 2>/dev/null || true
  ip6tables -P FORWARD DROP 2>/dev/null || true
  ip6tables -P OUTPUT DROP 2>/dev/null || true
  exit 1
}
trap seal ERR

# IPv6: we never allowlist over v6, so seal it entirely (an IPv4-only firewall
# is bypassable by connecting over IPv6). Skip only if ip6tables is unavailable.
if command -v ip6tables >/dev/null 2>&1 && ip6tables -L >/dev/null 2>&1; then
  ip6tables -F
  ip6tables -A INPUT -i lo -j ACCEPT
  ip6tables -A OUTPUT -o lo -j ACCEPT
  ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  ip6tables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  ip6tables -P INPUT DROP
  ip6tables -P FORWARD DROP
  ip6tables -P OUTPUT DROP
else
  echo "init-firewall: warning - ip6tables unavailable; ensure the Docker network has IPv6 disabled" >&2
fi

# --- Build the IPv4 allowlist ------------------------------------------------
domains=(
  api.anthropic.com claude.ai console.anthropic.com statsig.anthropic.com
  registry.npmjs.org pypi.org files.pythonhosted.org
  sh.rustup.rs static.rust-lang.org crates.io static.crates.io index.crates.io
  binaries.soliditylang.org
  github.com raw.githubusercontent.com objects.githubusercontent.com codeload.github.com
)
# Opt-in extra hosts, root-owned, written from the host (e.g. `lair allow`).
extra_file="/etc/devcontainer/allowed-domains.txt"
if [[ -f "$extra_file" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -n "$line" ]] && domains+=("$line")
  done <"$extra_file"
fi

# Start from a clean, OPEN v4 chain so we can resolve/fetch the allowlist. No
# untrusted code runs during setup (the container is not ready until this
# finishes, via waitFor), and the ERR trap seals on any failure.
echo "init-firewall: building allowlist"
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
ipset destroy allowed-domains 2>/dev/null || true
ipset create allowed-domains hash:net

# GitHub IP ranges - api + git only (not the .web/Pages range, which would
# allowlist attacker-hostable github.io content as an exfil target).
gh_meta="$(curl -fsSL --max-time 20 https://api.github.com/meta || true)"
if [[ -n "$gh_meta" ]]; then
  while IFS= read -r cidr; do
    [[ -z "$cidr" ]] && continue
    ipset add allowed-domains "$cidr" 2>/dev/null || true
  done < <(echo "$gh_meta" | jq -r '(.api + .git)[]?' 2>/dev/null || true)
fi

for domain in "${domains[@]}"; do
  while IFS= read -r ip; do
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
    ipset add allowed-domains "$ip" 2>/dev/null || true
  done < <(dig +short A "$domain" 2>/dev/null || true)
done

# --- Install the IPv4 rules --------------------------------------------------
echo "init-firewall: installing rules"
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# DNS only to the configured resolver(s) - not arbitrary hosts (blocks DNS
# tunneling). A loopback resolver (127.0.0.11) is already covered by lo above.
while IFS= read -r ns; do
  [[ "$ns" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
  iptables -A OUTPUT -p udp -d "$ns" --dport 53 -j ACCEPT
  iptables -A OUTPUT -p tcp -d "$ns" --dport 53 -j ACCEPT
done < <(awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null)

# Docker default gateway only (VS Code server channel / port forwarding) - not
# the whole bridge subnet.
gw="$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')"
[[ -n "$gw" ]] && iptables -A OUTPUT -d "$gw" -j ACCEPT

# Allow ONLY web ports to allowlisted hosts. Restricting to 80/443 is what
# blocks outbound SSH (22) and every other port by default.
iptables -A OUTPUT -p tcp -m multiport --dports 80,443 -m set --match-set allowed-domains dst -j ACCEPT

# Optional: allow SSH (22) to allowlisted hosts (e.g. git push to github) when the
# host opted in via `lair --ssh`. The marker is a root-owned, read-only bind mount.
if [[ -f /etc/devcontainer/allow-ssh ]]; then
  iptables -A OUTPUT -p tcp --dport 22 -m set --match-set allowed-domains dst -j ACCEPT
  echo "init-firewall: SSH (22) to allowlisted hosts enabled"
fi

# Lock down.
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# --- Verify ------------------------------------------------------------------
echo "init-firewall: verifying"
if curl -fsS --max-time 5 https://example.com -o /dev/null 2>/dev/null; then
  echo "init-firewall: FAIL - example.com reachable" >&2
  seal
fi
echo "init-firewall: ok - off-allowlist egress is blocked"
if curl -fsS --max-time 5 https://api.github.com/zen -o /dev/null 2>/dev/null; then
  echo "init-firewall: ok - github reachable"
else
  echo "init-firewall: warning - github unreachable; check DNS/allowlist" >&2
fi
trap - ERR
echo "init-firewall: active"
