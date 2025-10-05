#!/bin/bash

# Script to import the enhanced dashboard to Grafana
# This script assumes Grafana is running on localhost:80

GRAFANA_URL="http://localhost"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"

# Wait for Grafana to be ready
echo "Waiting for Grafana to be ready..."
until curl -s -f "$GRAFANA_URL/api/health" > /dev/null; do
  echo "Waiting for Grafana..."
  sleep 2
done

echo "Grafana is ready!"

# Create datasource if it doesn't exist
echo "Setting up Graphite datasource..."
curl -X POST \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
  -d '{
    "name": "Graphite",
    "type": "graphite",
    "url": "http://graphite:80",
    "access": "proxy",
    "isDefault": true,
    "jsonData": {
      "graphiteVersion": "1.1"
    }
  }' \
  "$GRAFANA_URL/api/datasources" 2>/dev/null || echo "Datasource may already exist"

# Import the enhanced dashboard
echo "Importing enhanced dashboard..."
curl -X POST \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
  -d @enhanced-dashboard.json \
  "$GRAFANA_URL/api/dashboards/db" 2>/dev/null

echo "Dashboard import completed!"
echo "You can access Grafana at: $GRAFANA_URL"
echo "Default credentials: admin/admin"
