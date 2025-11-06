#!/usr/bin/env bash
set -euo pipefail

# Export a Kibana Dashboard (and related objects) to kibana_exports/*.ndjson
# Usage: ./scripts/kibana_export_dashboard.sh [Dashboard Title]
# Defaults to title: "SIEM LAB NOVO"

TITLE="${1:-SIEM LAB NOVO}"
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$LAB_DIR/kibana_exports"
mkdir -p "$OUT_DIR"

echo "[1/3] Locating dashboard by title: $TITLE"
ID=$(curl -s -H 'kbn-xsrf: true' \
  "http://localhost:5601/api/saved_objects/_find?type=dashboard&search_fields=title&search=$(printf '%s' "$TITLE" | sed 's/ /%20/g')" \
  | jq -r --arg T "$TITLE" '.saved_objects[] | select(.attributes.title==$T) | .id' | head -n1)

if [ -z "${ID:-}" ]; then
  echo "Dashboard not found: $TITLE"
  echo "Available dashboards (titles):"
  curl -s -H 'kbn-xsrf: true' 'http://localhost:5601/api/saved_objects/_find?type=dashboard&per_page=10000' \
    | jq -r '.saved_objects[].attributes.title' | sed 's/^/ - /'
  exit 1
fi
echo "Found id: $ID"

TS=$(date +%F)
SLUG=$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' /' '--' | tr -cd 'a-z0-9-')
OUTFILE="$OUT_DIR/export-$TS-$SLUG.ndjson"

echo "[2/3] Exporting to $OUTFILE"
curl -s -H 'kbn-xsrf: true' -H 'Content-Type: application/json' \
  -X POST 'http://localhost:5601/api/saved_objects/_export' \
  -d "{\"objects\":[{\"type\":\"dashboard\",\"id\":\"$ID\"}],\"includeReferencesDeep\":true}" \
  > "$OUTFILE"

echo "[3/3] Done: $OUTFILE"

