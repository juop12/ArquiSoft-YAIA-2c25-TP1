#!/bin/bash

set -e

GRAFANA_URL=${GRAFANA_URL:-"http://localhost:80"}
GRAFANA_USER=${GRAFANA_USER:-"admin"}
GRAFANA_PASS=${GRAFANA_PASS:-"admin"}
DASHBOARD_FILE="perf/dashboards/dashboard.json"
BACKUP_FILE="perf/dashboards/dashboard.json.backup"

echo "Updating datasource UID in dashboard."

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

# Obtenemos el UID del datasource Graphite
echo "🔍 Getting UID of Graphite datasource."
GRAPHITE_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" "${GRAFANA_URL}/api/datasources" | \
    jq -r '.[] | select(.type == "graphite") | .uid')

if [ -z "$GRAPHITE_UID" ] || [ "$GRAPHITE_UID" = "null" ]; then
    echo "Error: Could not obtain UID of Graphite datasource"
    exit 1
fi

cp "$DASHBOARD_FILE" "$BACKUP_FILE"

# Actualizamos el dashboard con el nuevo UID (en caso de que haya cambiado)
OLD_UID=$(grep -o '"uid": "[^"]*"' "$DASHBOARD_FILE" | grep -v '"grafana"' | head -1 | grep -o '[a-zA-Z0-9]\{10,\}')

if [ -n "$OLD_UID" ]; then
    echo "   Replacing old UID: ${OLD_UID}"
    echo "   With new UID: ${GRAPHITE_UID}"

    sed -i.tmp "s/\"uid\": \"${OLD_UID}\"/\"uid\": \"${GRAPHITE_UID}\"/g" "$DASHBOARD_FILE"
    rm "${DASHBOARD_FILE}.tmp"
    
    UPDATED_COUNT=$(grep -c "\"uid\": \"${GRAPHITE_UID}\"" "$DASHBOARD_FILE")
    echo "   ${UPDATED_COUNT} references updated"
else
    echo "No valid UID found to update in dashboard"
    exit 1
fi

rm -f "$BACKUP_FILE"

echo "Dashboard updated successfully"
