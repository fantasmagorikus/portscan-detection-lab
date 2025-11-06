#!/usr/bin/env bash
set -euo pipefail

# Rename a Kibana dashboard by title.
# Usage: ./scripts/kibana_rename_dashboard.sh "Old Title" "New Title"

OLD_TITLE="${1:-SIEM LAB NOVO}"
NEW_TITLE="${2:-Port Scan Detection (Suricata)}"

echo "[1/3] Find dashboard id for: $OLD_TITLE"
ID=$(curl -s -H 'kbn-xsrf: true' \
  "http://localhost:5601/api/saved_objects/_find?type=dashboard&search_fields=title&search=$(printf '%s' "$OLD_TITLE" | sed 's/ /%20/g')" \
  | jq -r --arg T "$OLD_TITLE" '.saved_objects[] | select(.attributes.title==$T) | .id' | head -n1)

if [ -z "${ID:-}" ]; then
  echo "Dashboard not found: $OLD_TITLE"; exit 1
fi
echo "Found id: $ID"

echo "[2/3] Update title to: $NEW_TITLE"
curl -s -X PUT -H 'kbn-xsrf: true' -H 'Content-Type: application/json' \
  "http://localhost:5601/api/saved_objects/dashboard/$ID" \
  -d "{\"attributes\":{\"title\":\"$NEW_TITLE\"}}" >/dev/null

echo "[3/3] Done. New title set."

