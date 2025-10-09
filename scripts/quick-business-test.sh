#!/bin/bash

# Quick Business Metrics Test Script
# Generates a burst of exchange requests quickly

set -e

API_URL="http://localhost:5555"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +%T)]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check API
if ! curl -s "$API_URL/health" > /dev/null 2>&1; then
    echo "API not available. Please start the system first."
    exit 1
fi

log "Generating business metrics data..."

# Generate exchanges for all currency pairs
currencies=("USD" "EUR" "ARS" "BRL")
count=0
success_count=0

for base in "${currencies[@]}"; do
    for counter in "${currencies[@]}"; do
        if [ "$base" != "$counter" ]; then
            for amount in 100 250 500 1000; do
                request='{
                    "baseCurrency": "'$base'",
                    "counterCurrency": "'$counter'",
                    "baseAccountId": "1",
                    "counterAccountId": "2",
                    "baseAmount": '$amount'
                }'
                
                response=$(curl -s -X POST "$API_URL/exchange" \
                    -H "Content-Type: application/json" \
                    -d "$request")
                
                count=$((count + 1))
                
                if echo "$response" | grep -q '"ok":true'; then
                    success_count=$((success_count + 1))
                    echo "✓ $base -> $counter ($amount)"
                else
                    echo "✗ $base -> $counter ($amount) - FAILED"
                fi
                
                sleep 0.2
            done
        fi
    done
done

log "Generated $count requests ($success_count successful)"
success "Business metrics data generated! Check your dashboard at http://localhost:80/d/bf0hu5uvgxk3ke"
