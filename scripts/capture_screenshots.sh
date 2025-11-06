#!/usr/bin/env bash
set -euo pipefail

# Capture Kibana Dashboard screenshots via headless Chrome with robust waits.
# Requires: google-chrome (headless)

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$LAB_DIR/docs/screenshots"
mkdir -p "$OUT_DIR"

DASH_ID="9f4b2337-ab9c-4229-a5c7-ae72c82bbfbf"  # Port Scan Detection (Suricata)
BASE_URL="http://localhost:5601/app/dashboards#/view/$DASH_ID"

CHROME_BIN="${CHROME_BIN:-google-chrome}"
CHROME_ARGS=(
  --headless=new
  --disable-gpu
  --no-sandbox
  --disable-dev-shm-usage
  --hide-scrollbars
  --window-size=1920,1080
  --force-device-scale-factor=1.25
  --enable-features=NetworkService,NetworkServiceInProcess
  --no-first-run
  --no-default-browser-check
  --virtual-time-budget=60000
)

echo "Using Chrome: $CHROME_BIN"

capture() {
  local url="$1" out="$2" label="$3"
  echo "[*] Warm-up load for $label"
  "$CHROME_BIN" "${CHROME_ARGS[@]}" "$url" >/dev/null 2>&1 || true
  sleep 3
  echo "[+] Capturing: $out"
  "$CHROME_BIN" "${CHROME_ARGS[@]}" --screenshot="$out" "$url" >/dev/null 2>&1 || {
    echo "Failed to capture $out"; return 1;
  }
}

# 1) Overview last 1 hour (higher chance of populated panels)
URL1="$BASE_URL?_g=(time:(from:now-1h,to:now))&kiosk=true&embed=true"
OUT1="$OUT_DIR/dashboard_overview.png"
capture "$URL1" "$OUT1" "last 1h overview"

# 2) Overview last 10 minutes (recent activity)
URL2="$BASE_URL?_g=(time:(from:now-10m,to:now))&kiosk=true&embed=true"
OUT2="$OUT_DIR/dashboard_overview_last5.png"
capture "$URL2" "$OUT2" "last 10m overview"

echo "Done. Screenshots saved under $OUT_DIR"
