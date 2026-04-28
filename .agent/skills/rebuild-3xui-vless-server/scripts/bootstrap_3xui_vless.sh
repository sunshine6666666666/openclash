#!/usr/bin/env bash
set -euo pipefail

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo bash $0" >&2
    exit 1
  fi
}

ask_default() {
  local prompt="$1"
  local default="$2"
  local value
  read -r -p "$prompt [$default]: " value
  printf '%s' "${value:-$default}"
}

yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  local answer
  read -r -p "$prompt [$default]: " answer
  answer="${answer:-$default}"
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_base_packages() {
  if need_cmd apt-get; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl jq openssl python3 iproute2
  elif need_cmd dnf; then
    dnf install -y ca-certificates curl jq openssl python3 iproute
  elif need_cmd yum; then
    yum install -y ca-certificates curl jq openssl python3 iproute
  else
    echo "Unsupported package manager. Install curl, jq, openssl, python3, iproute2, and Docker manually." >&2
    exit 1
  fi
}

install_docker_if_needed() {
  if need_cmd docker; then
    return
  fi
  echo "Docker not found. Installing Docker using the official convenience script."
  curl -fsSL https://get.docker.com | sh
}

start_docker() {
  if need_cmd systemctl; then
    systemctl enable --now docker || true
  fi
  docker info >/dev/null
}

detect_public_ip() {
  curl -fsS4 https://api.ipify.org 2>/dev/null || curl -fsS4 https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'
}

port_is_listening() {
  local port="$1"
  ss -tulpn 2>/dev/null | grep -Eq "[:.]${port}[[:space:]]"
}

random_token() {
  local len="${1:-16}"
  python3 - "$len" <<'PY'
import secrets
import string
import sys

length = int(sys.argv[1])
alphabet = string.ascii_letters + string.digits
print("".join(secrets.choice(alphabet) for _ in range(length)), end="")
PY
}

random_hex() {
  openssl rand -hex "$1"
}

container_xray_bin() {
  docker exec 3x-ui sh -c 'for f in /app/bin/xray-linux-*; do [ -x "$f" ] && printf "%s\n" "$f" && exit 0; done; exit 1'
}

generate_reality_keys() {
  local bin output private public
  bin="$(container_xray_bin)"
  output="$(docker exec 3x-ui "$bin" x25519)"
  private="$(printf '%s\n' "$output" | awk -F': ' '/PrivateKey:/ {print $2; exit}')"
  public="$(printf '%s\n' "$output" | awk -F': ' '/PublicKey:/ {print $2; exit}')"
  if [ -z "$public" ]; then
    public="$(printf '%s\n' "$output" | awk -F': ' '/Password:/ {print $2; exit}')"
  fi
  if [ -z "$private" ] || [ -z "$public" ]; then
    echo "Failed to generate REALITY x25519 keys." >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
  printf '%s\n%s\n' "$private" "$public"
}

deploy_container() {
  mkdir -p /opt/3x-ui/db /opt/3x-ui/cert

  if docker ps -a --format '{{.Names}}' | grep -qx '3x-ui'; then
    if docker ps --format '{{.Names}}' | grep -qx '3x-ui'; then
      echo "Existing running 3x-ui container found; reusing it."
    else
      echo "Existing stopped 3x-ui container found; starting it."
      docker start 3x-ui
    fi
    return
  fi

  docker pull ghcr.io/mhsanaei/3x-ui:latest
  docker run -itd \
    -e XRAY_VMESS_AEAD_FORCED=false \
    -e XUI_ENABLE_FAIL2BAN=true \
    -v /opt/3x-ui/db/:/etc/x-ui/ \
    -v /opt/3x-ui/cert/:/root/cert/ \
    --network=host \
    --restart=unless-stopped \
    --name 3x-ui \
    ghcr.io/mhsanaei/3x-ui:latest
}

wait_for_db() {
  local db="/opt/3x-ui/db/x-ui.db"
  for _ in $(seq 1 30); do
    [ -s "$db" ] && return
    sleep 1
  done
  echo "3x-ui database was not created at $db." >&2
  docker logs --tail 80 3x-ui >&2 || true
  exit 1
}

write_inbound() {
  local db="$1"
  local address="$2"
  local remark="$3"
  local node_port="$4"
  local uuid="$5"
  local private_key="$6"
  local public_key="$7"
  local short_id="$8"
  local sni="$9"
  local target="${10}"
  local fingerprint="${11}"
  local flow="${12}"
  local sub_id="${13}"
  local client_email="${14}"
  local panel_port="${15}"
  local panel_path="${16}"
  local sub_port="${17}"
  local sub_path="${18}"

  python3 - "$db" "$address" "$remark" "$node_port" "$uuid" "$private_key" "$public_key" "$short_id" "$sni" "$target" "$fingerprint" "$flow" "$sub_id" "$client_email" "$panel_port" "$panel_path" "$sub_port" "$sub_path" <<'PY'
import json
import sqlite3
import sys
import time
from pathlib import Path

(
    db_path,
    address,
    remark,
    node_port,
    uuid,
    private_key,
    public_key,
    short_id,
    sni,
    target,
    fingerprint,
    flow,
    sub_id,
    client_email,
    panel_port,
    panel_path,
    sub_port,
    sub_path,
) = sys.argv[1:]

node_port = int(node_port)
panel_port = int(panel_port)
sub_port = int(sub_port)
now_ms = int(time.time() * 1000)
tag = f"inbound-{node_port}"

db = Path(db_path)
con = sqlite3.connect(str(db))
cur = con.cursor()

existing = cur.execute("select id from inbounds where port = ? or tag = ?", (node_port, tag)).fetchone()
if existing:
    raise SystemExit(f"inbound already exists for port/tag {node_port}/{tag}; remove it in the panel or choose another port")

settings = {
    "clients": [
        {
            "id": uuid,
            "security": "",
            "password": uuid,
            "flow": flow,
            "email": client_email,
            "limitIp": 0,
            "totalGB": 0,
            "expiryTime": 0,
            "enable": True,
            "tgId": "",
            "subId": sub_id,
            "comment": "",
            "reset": 0,
            "created_at": now_ms,
            "updated_at": now_ms,
        }
    ],
    "decryption": "none",
    "encryption": "none",
}

stream_settings = {
    "network": "tcp",
    "security": "reality",
    "externalProxy": [],
    "realitySettings": {
        "show": False,
        "xver": 0,
        "target": target,
        "serverNames": [sni],
        "privateKey": private_key,
        "minClientVer": "",
        "maxClientVer": "",
        "maxTimediff": 0,
        "shortIds": [short_id],
        "settings": {
            "publicKey": public_key,
            "fingerprint": fingerprint,
            "serverName": "",
            "spiderX": "/",
        },
    },
    "tcpSettings": {
        "acceptProxyProtocol": False,
        "header": {"type": "none"},
    },
}

sniffing = {
    "enabled": True,
    "destOverride": ["http", "tls", "quic", "fakedns"],
    "metadataOnly": False,
    "routeOnly": False,
}

cur.execute(
    """
    insert into inbounds
      (user_id, up, down, total, all_time, remark, enable, expiry_time, traffic_reset,
       last_traffic_reset_time, listen, port, protocol, settings, stream_settings, tag, sniffing)
    values
      (1, 0, 0, 0, 0, ?, 1, 0, 'never', 0, '', ?, 'vless', ?, ?, ?, ?)
    """,
    (
        remark,
        node_port,
        json.dumps(settings, separators=(",", ":")),
        json.dumps(stream_settings, separators=(",", ":")),
        tag,
        json.dumps(sniffing, separators=(",", ":")),
    ),
)
inbound_id = cur.lastrowid

cur.execute(
    """
    insert or ignore into client_traffics
      (inbound_id, enable, email, up, down, all_time, expiry_time, total, reset, last_online)
    values (?, 1, ?, 0, 0, 0, 0, 0, 0, 0)
    """,
    (inbound_id, client_email),
)

def setting(key, value):
    row = cur.execute("select id from settings where key = ?", (key,)).fetchone()
    if row:
        cur.execute("update settings set value = ? where key = ?", (value, key))
    else:
        cur.execute("insert into settings (key, value) values (?, ?)", (key, value))

setting("webListen", "127.0.0.1")
setting("webPort", str(panel_port))
setting("webBasePath", panel_path)
setting("subEnable", "true")
setting("subListen", "")
setting("subPort", str(sub_port))
setting("subPath", sub_path)
setting("subJsonPath", sub_path.rstrip("/") + "json/")
setting("subEncrypt", "false")
setting("subShowInfo", "true")

con.commit()
con.close()
PY
}

write_document() {
  local doc="$1"
  local address="$2"
  local remark="$3"
  local node_port="$4"
  local uuid="$5"
  local public_key="$6"
  local short_id="$7"
  local sni="$8"
  local target="$9"
  local fingerprint="${10}"
  local flow="${11}"
  local panel_port="${12}"
  local panel_path="${13}"
  local sub_port="${14}"
  local sub_path="${15}"
  local sub_id="${16}"
  local vless_uri="${17}"
  local created_at
  created_at="$(date -Is)"

  umask 077
  {
    printf '# VLESS REALITY Node Info\n\n'
    printf 'Created: `%s`\n\n' "$created_at"
    printf '## Client Import URI\n\n'
    printf '```text\n%s\n```\n\n' "$vless_uri"
    printf '## Client Fields\n\n'
    printf '| Field | Value |\n'
    printf '| --- | --- |\n'
    printf '| Protocol | `vless` |\n'
    printf '| Address | `%s` |\n' "$address"
    printf '| Port | `%s` |\n' "$node_port"
    printf '| UUID | `%s` |\n' "$uuid"
    printf '| Encryption | `none` |\n'
    printf '| Transport | `tcp` |\n'
    printf '| Security | `reality` |\n'
    printf '| Flow | `%s` |\n' "$flow"
    printf '| REALITY public key | `%s` |\n' "$public_key"
    printf '| REALITY short ID | `%s` |\n' "$short_id"
    printf '| REALITY SNI | `%s` |\n' "$sni"
    printf '| REALITY target | `%s` |\n' "$target"
    printf '| Fingerprint | `%s` |\n' "$fingerprint"
    printf '| SpiderX | `/` |\n'
    printf '| Remark | `%s` |\n\n' "$remark"
    printf '## Optional 3x-ui Access\n\n'
    printf 'The panel is bound to localhost for safety. Use an SSH tunnel from your computer:\n\n'
    printf '```bash\nssh -L %s:127.0.0.1:%s root@%s\n```\n\n' "$panel_port" "$panel_port" "$address"
    printf 'Then open:\n\n'
    printf '```text\nhttp://127.0.0.1:%s%s\n```\n\n' "$panel_port" "$panel_path"
    printf 'Default 3x-ui credentials may be `admin` / `admin` on a fresh install. Change them immediately in the panel.\n\n'
    printf '## Subscription Hint\n\n'
    printf 'If 3x-ui subscription output is enabled for this version, try:\n\n'
    printf '```text\nhttp://%s:%s%s%s\n```\n\n' "$address" "$sub_port" "$sub_path" "$sub_id"
    printf 'If the subscription endpoint is unavailable, use the direct VLESS URI above.\n\n'
    printf '## Server Checks\n\n'
    printf '```bash\n'
    printf 'docker ps --filter name=3x-ui\n'
    printf 'ss -tulpn | grep -E ":(%s|%s) "\n' "$node_port" "$sub_port"
    printf 'docker logs --tail 80 3x-ui\n'
    printf '```\n'
  } > "$doc"
  chmod 600 "$doc"
}

main() {
  require_root
  install_base_packages
  install_docker_if_needed
  start_docker

  local detected_ip default_remark address remark node_port sni target fingerprint flow panel_port panel_path sub_port sub_path db keys private_key public_key short_id uuid sub_id client_email doc encoded_remark vless_uri

  detected_ip="$(detect_public_ip || true)"
  detected_ip="${detected_ip:-}"
  address="$(ask_default "Public address for clients" "$detected_ip")"
  if [ -z "$address" ]; then
    echo "Public address is required." >&2
    exit 1
  fi

  default_remark="vless-reality-$(hostname | tr -cd 'A-Za-z0-9._-')"
  default_remark="${default_remark:0:48}"
  remark="$(ask_default "Node remark" "$default_remark")"
  node_port="$(ask_default "VLESS REALITY port" "443")"
  sni="$(ask_default "REALITY SNI" "www.microsoft.com")"
  target="$(ask_default "REALITY target host:port" "${sni}:443")"
  fingerprint="$(ask_default "REALITY fingerprint" "chrome")"
  flow="$(ask_default "VLESS flow" "xtls-rprx-vision")"
  panel_port="$(ask_default "Local 3x-ui panel port" "36532")"
  panel_path="$(ask_default "3x-ui panel path" "/$(random_token 24)/")"
  sub_port="$(ask_default "3x-ui subscription port" "2096")"
  sub_path="$(ask_default "3x-ui subscription path" "/trade/")"

  if port_is_listening "$node_port"; then
    if ! yes_no "Port $node_port is already listening. Continue only if this is the existing 3x-ui/xray service?" "n"; then
      exit 1
    fi
  fi

  if [ -f /root/vless-reality-node-info.md ]; then
    if ! yes_no "/root/vless-reality-node-info.md exists. Overwrite it?" "n"; then
      exit 1
    fi
  fi

  deploy_container
  wait_for_db

  keys="$(generate_reality_keys)"
  private_key="$(printf '%s\n' "$keys" | sed -n '1p')"
  public_key="$(printf '%s\n' "$keys" | sed -n '2p')"
  short_id="$(random_hex 8)"
  uuid="$(cat /proc/sys/kernel/random/uuid)"
  sub_id="$(random_token 16)"
  client_email="$(random_token 8)"
  db="/opt/3x-ui/db/x-ui.db"

  write_inbound "$db" "$address" "$remark" "$node_port" "$uuid" "$private_key" "$public_key" "$short_id" "$sni" "$target" "$fingerprint" "$flow" "$sub_id" "$client_email" "$panel_port" "$panel_path" "$sub_port" "$sub_path"

  docker restart 3x-ui >/dev/null
  sleep 3

  encoded_remark="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$remark")"
  vless_uri="vless://${uuid}@${address}:${node_port}?type=tcp&security=reality&encryption=none&flow=${flow}&fp=${fingerprint}&sni=${sni}&pbk=${public_key}&sid=${short_id}&spx=%2F#${encoded_remark}"
  doc="/root/vless-reality-node-info.md"
  write_document "$doc" "$address" "$remark" "$node_port" "$uuid" "$public_key" "$short_id" "$sni" "$target" "$fingerprint" "$flow" "$panel_port" "$panel_path" "$sub_port" "$sub_path" "$sub_id" "$vless_uri"

  echo
  echo "Deployment complete."
  echo "Node document: $doc"
  echo "Direct VLESS URI:"
  echo "$vless_uri"
}

main "$@"
