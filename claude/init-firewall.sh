#!/usr/bin/env bash
# Default-deny egress firewall for the Cyfrin Claude dev container.
# Adapted from Anthropic's reference devcontainer (anthropics/claude-code).
#
# Only HTTP/HTTPS (80/443) to an allowlist is permitted; everything else,
# including SSH (port 22), is dropped. Runs as root at container start via a
# single scoped sudoers rule, so untrusted code in the container can neither
# flush these rules nor edit the (root-owned) allowlist.
set -euo pipefail
IFS=$'\n\t'

if [[ "$(id -u)" -ne 0 ]]; then
  echo "init-firewall: must run as root" >&2
  exit 1
fi

# Default allowlist: Anthropic (API + login), package registries, GitHub.
domains=(
  api.anthropic.com
  claude.ai
  console.anthropic.com
  statsig.anthropic.com
  registry.npmjs.org
  pypi.org
  files.pythonhosted.org
  github.com
  raw.githubusercontent.com
  objects.githubusercontent.com
  codeload.github.com
)

# Opt-in extra hosts, root-owned and written from the host (e.g. `lair allow`).
# It cannot be edited from inside the container, so untrusted code can't widen
# the allowlist itself.
extra_file="/etc/devcontainer/allowed-domains.txt"
if [[ -f "$extra_file" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -n "$line" ]] && domains+=("$line")
  done <"$extra_file"
fi

echo "init-firewall: resetting filter rules"
# Only the filter table is flushed; the nat table is left to Docker so the
# embedded DNS resolver keeps working.
iptables -F
iptables -X
ipset destroy allowed-domains 2>/dev/null || true
ipset create allowed-domains hash:net

# Populate the allowlist while egress is still open (before the DROP policy).
echo "init-firewall: adding GitHub IP ranges"
gh_meta="$(curl -fsSL --max-time 20 https://api.github.com/meta || true)"
if [[ -n "$gh_meta" ]]; then
  while IFS= read -r cidr; do
    [[ -z "$cidr" ]] && continue
    ipset add allowed-domains "$cidr" 2>/dev/null || true
  done < <(echo "$gh_meta" | jq -r '(.web + .api + .git)[]?' 2>/dev/null || true)
fi

echo "init-firewall: resolving ${#domains[@]} allowlisted domains"
for domain in "${domains[@]}"; do
  while IFS= read -r ip; do
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
    ipset add allowed-domains "$ip" 2>/dev/null || true
  done < <(dig +short A "$domain" 2>/dev/null || true)
done

echo "init-firewall: installing rules"
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Local Docker network (VS Code server channel / port forwarding).
host_net="$(ip -o -f inet addr show eth0 2>/dev/null | awk '{print $4}' | head -1 || true)"
[[ -n "$host_net" ]] && iptables -A OUTPUT -d "$host_net" -j ACCEPT

# Allow ONLY web ports to allowlisted hosts. Restricting to 80/443 is what
# blocks outbound SSH (22) and every other port by default.
iptables -A OUTPUT -p tcp -m multiport --dports 80,443 -m set --match-set allowed-domains dst -j ACCEPT

# Default deny.
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

echo "init-firewall: verifying"
if curl -fsS --max-time 5 https://example.com -o /dev/null 2>/dev/null; then
  echo "init-firewall: FAIL - example.com reachable; aborting" >&2
  exit 1
fi
echo "init-firewall: ok - off-allowlist egress is blocked"
if curl -fsS --max-time 5 https://api.github.com/zen -o /dev/null 2>/dev/null; then
  echo "init-firewall: ok - github reachable"
else
  echo "init-firewall: warning - github unreachable; check DNS/allowlist" >&2
fi
echo "init-firewall: active"
