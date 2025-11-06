#!/usr/bin/env bash
# Quick checklist runner for SOC/SIEM lab (vítima)

set -u
set -o pipefail

TIMEOUT="${TIMEOUT:-5}"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$LAB_DIR" 2>/dev/null || true

# Prepare output file and capture everything (stdout/stderr)
TS="$(date +%F-%H%M%S)"
OUTFILE="$LAB_DIR/retomada_check-$TS.txt"
exec > >(tee -a "$OUTFILE") 2>&1

echo "=== [vítima] SOC/SIEM Lab quick check @ $(date -Iseconds)"
echo "Output file: $OUTFILE"

cd "$LAB_DIR" || { echo "Lab dir not found at $LAB_DIR"; exit 1; }

echo "==> docker compose up -d"
docker compose up -d >/dev/null 2>&1 || true

echo "==> docker compose ps"
docker compose ps || true

echo "==> services (docker compose config --services)"
docker compose config --services || true

echo "==> SURICATA_IFACE from .env"
IFACE="$(awk -F= '/^SURICATA_IFACE=/{print $2}' .env 2>/dev/null || true)"
echo "SURICATA_IFACE=${IFACE:-<unset>}"
if [ -n "${IFACE:-}" ]; then
  if ip -o link show >/dev/null 2>&1; then
    if ip -o link show | awk -F': ' '{print $2}' | grep -x "$IFACE" >/dev/null; then
      echo "iface $IFACE present (ip link)"
    else
      echo "iface $IFACE NOT found (ip link)"
    fi
  else
    if [ -e "/sys/class/net/$IFACE" ]; then
      echo "iface $IFACE present (sysfs)"
    else
      echo "iface $IFACE NOT found (sysfs)"
    fi
  fi
fi

echo "==> Elasticsearch version"
ES_VER="$(curl -sS --max-time "$TIMEOUT" http://localhost:9200 | jq -r '.version.number' 2>/dev/null || true)"
if [ -n "$ES_VER" ] && [ "$ES_VER" != "null" ]; then
  echo "$ES_VER"
else
  curl -sS --max-time "$TIMEOUT" http://localhost:9200 || echo "ES: unreachable"
fi

echo "==> Kibana version"
KBN_VER="$(curl -sS --max-time "$TIMEOUT" http://localhost:5601/api/status | jq -r '.version.number' 2>/dev/null || true)"
if [ -n "$KBN_VER" ] && [ "$KBN_VER" != "null" ]; then
  echo "$KBN_VER"
else
  curl -sS --max-time "$TIMEOUT" http://localhost:5601/api/status || echo "Kibana: unreachable"
fi

echo "==> Filebeat test config"
if docker ps -a --format '{{.Names}}' | grep -qx 'suricata-lab-filebeat'; then
  docker exec suricata-lab-filebeat filebeat -e -strict.perms=false test config 2>&1 || echo "filebeat test config: failed"
else
  echo "filebeat container not found"
fi

echo "==> Filebeat test output"
if docker ps -a --format '{{.Names}}' | grep -qx 'suricata-lab-filebeat'; then
  docker exec suricata-lab-filebeat filebeat -e -strict.perms=false test output 2>&1 || echo "filebeat test output: failed"
else
  echo "filebeat container not found"
fi

echo "==> Suricata EVE.json (size + head/tail)"
if docker ps -a --format '{{.Names}}' | grep -qx 'suricata-lab-suricata'; then
  docker exec suricata-lab-suricata sh -lc 'ls -lh /var/log/suricata/eve.json && echo "-- HEAD --" && head -n 3 /var/log/suricata/eve.json && echo "-- TAIL --" && tail -n 3 /var/log/suricata/eve.json' 2>&1 || echo "suricata eve.json: not available"
else
  echo "suricata container not found"
fi

echo "==> ES _count event.module=suricata"
COUNT_RESP="$(curl -sS --max-time "$TIMEOUT" "http://localhost:9200/.ds-filebeat-*/_count" -H 'Content-Type: application/json' -d '{"query":{"term":{"event.module":"suricata"}}}' 2>/dev/null || true)"
if command -v jq >/dev/null 2>&1; then
  echo "$COUNT_RESP" | jq -r '.count // "count: unavailable"'
else
  echo "$COUNT_RESP"
fi

echo "=== done"

# Maintain a convenience symlink to the latest report
ln -sf "$OUTFILE" "$LAB_DIR/retomada_check-latest.txt" 2>/dev/null || true
echo "Saved report: $OUTFILE"
echo "Symlink updated: $LAB_DIR/retomada_check-latest.txt"
