#!/bin/bash

set -e

GRAFANA_URL=${GRAFANA_URL:-"http://localhost:80"}
GRAFANA_USER=${GRAFANA_USER:-"admin"}
GRAFANA_PASS=${GRAFANA_PASS:-"admin"}
DASHBOARD_FILE="perf/dashboard.json"

echo "Importing dashboard to Grafana."

echo "Waiting for Grafana to be available..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" "${GRAFANA_URL}/api/health" > /dev/null 2>&1; then
        echo "Grafana is available"
        break
    fi
    attempt=$((attempt + 1))
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "Error: Grafana is not available after ${max_attempts} attempts"
    exit 1
fi

if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "Error: Dashboard not found at ${DASHBOARD_FILE}"
    exit 1
fi

# Removemos los campos que puedan causar conflictos en la importación
DASHBOARD_JSON=$(cat "$DASHBOARD_FILE" | jq 'del(.id, .uid, .version)')

IMPORT_PAYLOAD=$(jq -n \
  --argjson dashboard "$DASHBOARD_JSON" \
  '{
    dashboard: $dashboard,
    overwrite: true,
    inputs: []
  }')

echo "$IMPORT_PAYLOAD" > /tmp/grafana_import.json

RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
  -d @/tmp/grafana_import.json \
  "${GRAFANA_URL}/api/dashboards/import")

if echo "$RESPONSE" | grep -q '"imported":true'; then
    DASHBOARD_UID=$(echo "$RESPONSE" | jq -r '.uid')
    DASHBOARD_URL="${GRAFANA_URL}/d/${DASHBOARD_UID}"
elif echo "$RESPONSE" | grep -q '"uid"'; then
    DASHBOARD_UID=$(echo "$RESPONSE" | jq -r '.uid')
    DASHBOARD_URL="${GRAFANA_URL}/d/${DASHBOARD_UID}"
else
    echo "Error importing dashboard:"
    echo "$RESPONSE"
    exit 1
fi

rm -f /tmp/grafana_import.json

echo "Dashboard imported successfully."
