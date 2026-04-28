#!/usr/bin/env bash
set -u

section() {
  printf '\n## %s\n' "$1"
}

run() {
  printf '\n$ %s\n' "$*"
  "$@" 2>&1 || true
}

section "Identity"
run hostnamectl
run uname -a

section "Load And Memory"
run uptime
run free -h

section "Disk"
run df -h

section "Network"
run ip -brief address
if command -v curl >/dev/null 2>&1; then
  printf '\n$ public IPv4 probe\n'
  curl -fsS4 https://api.ipify.org 2>/dev/null || curl -fsS4 https://ifconfig.me 2>/dev/null || true
  printf '\n'
fi

section "Listening Ports"
if command -v ss >/dev/null 2>&1; then
  run ss -tulpn
else
  printf 'ss not found\n'
fi

section "Docker"
if command -v docker >/dev/null 2>&1; then
  run docker ps
  run docker ps -a
else
  printf 'docker not found\n'
fi

section "Systemd"
if command -v systemctl >/dev/null 2>&1; then
  run systemctl --failed
  run systemctl --type=service --state=running
else
  printf 'systemctl not found\n'
fi

section "Firewall Hints"
run sh -c 'command -v ufw >/dev/null 2>&1 && ufw status verbose || true'
run sh -c 'command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --list-all || true'

section "3x-ui Hints"
run sh -c 'docker inspect 3x-ui --format "{{.Name}} {{.State.Status}} {{.Config.Image}} {{range .Mounts}}{{.Source}} -> {{.Destination}} {{end}}" 2>/dev/null || true'
run sh -c 'find /opt/3x-ui -maxdepth 3 -type f 2>/dev/null | sort || true'
