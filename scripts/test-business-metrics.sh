#!/bin/bash

# ArVault Business Metrics Test Script
# Generates realistic exchange requests to populate the business dashboard

set -e

API_URL="http://localhost:5555"
LOG_FILE="business_test_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +%T)]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if API is available
check_api() {
    log "Checking API availability..."
    if curl -s "$API_URL/health" > /dev/null 2>&1; then
        success "API is available"
        return 0
    else
        error "API is not available at $API_URL"
        return 1
    fi
}

# Generate random exchange request
generate_exchange() {
    local currencies=("USD" "EUR" "ARS" "BRL")
    local base_currency=${currencies[$RANDOM % ${#currencies[@]}]}
    local counter_currency=${currencies[$RANDOM % ${#currencies[@]}]}
    
    # Ensure different currencies
    while [ "$base_currency" = "$counter_currency" ]; do
        counter_currency=${currencies[$RANDOM % ${#currencies[@]}]}
    done
    
    # Generate realistic amounts based on currency
    local base_amount
    case $base_currency in
        "USD") base_amount=$(($RANDOM % 1000 + 10)) ;;
        "EUR") base_amount=$(($RANDOM % 1000 + 10)) ;;
        "ARS") base_amount=$(($RANDOM % 100000 + 1000)) ;;
        "BRL") base_amount=$(($RANDOM % 5000 + 50)) ;;
    esac
    
    # Random account IDs (1-4)
    local base_account_id=$(($RANDOM % 4 + 1))
    local counter_account_id=$(($RANDOM % 4 + 1))
    
    echo "{
        \"baseCurrency\": \"$base_currency\",
        \"counterCurrency\": \"$counter_currency\",
        \"baseAccountId\": \"$base_account_id\",
        \"counterAccountId\": \"$counter_account_id\",
        \"baseAmount\": $base_amount
    }"
}

# Execute exchange request
execute_exchange() {
    local request_data="$1"
    local response=$(curl -s -X POST "$API_URL/exchange" \
        -H "Content-Type: application/json" \
        -d "$request_data")
    
    if echo "$response" | grep -q '"ok":true'; then
        echo "SUCCESS"
    else
        echo "FAILED"
    fi
}

# Run burst test
run_burst_test() {
    local duration=$1
    local rate=$2
    
    log "Starting burst test: $rate requests/second for $duration seconds"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    local request_count=0
    local success_count=0
    local failed_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        # Generate and execute requests at specified rate
        for ((i=0; i<rate; i++)); do
            if [ $(date +%s) -ge $end_time ]; then
                break
            fi
            
            local request=$(generate_exchange)
            local result=$(execute_exchange "$request")
            
            request_count=$((request_count + 1))
            
            if [ "$result" = "SUCCESS" ]; then
                success_count=$((success_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
            
            # Small delay to prevent overwhelming the API
            sleep 0.1
        done
        
        # Show progress every 10 seconds
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        if [ $((elapsed % 10)) -eq 0 ] && [ $elapsed -gt 0 ]; then
            log "Progress: ${elapsed}s elapsed, ${request_count} requests sent (${success_count} success, ${failed_count} failed)"
        fi
    done
    
    log "Burst test completed: ${request_count} total requests (${success_count} success, ${failed_count} failed)"
    echo "burst,$request_count,$success_count,$failed_count" >> "$LOG_FILE"
}

# Run sustained load test
run_sustained_test() {
    local duration=$1
    local rate=$2
    
    log "Starting sustained test: $rate requests/second for $duration seconds"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    local request_count=0
    local success_count=0
    local failed_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        local request=$(generate_exchange)
        local result=$(execute_exchange "$request")
        
        request_count=$((request_count + 1))
        
        if [ "$result" = "SUCCESS" ]; then
            success_count=$((success_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
        
        # Control rate
        sleep $(echo "scale=2; 1.0 / $rate" | bc)
        
        # Show progress every 30 seconds
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        if [ $((elapsed % 30)) -eq 0 ] && [ $elapsed -gt 0 ]; then
            log "Progress: ${elapsed}s elapsed, ${request_count} requests sent (${success_count} success, ${failed_count} failed)"
        fi
    done
    
    log "Sustained test completed: ${request_count} total requests (${success_count} success, ${failed_count} failed)"
    echo "sustained,$request_count,$success_count,$failed_count" >> "$LOG_FILE"
}

# Run mixed workload test
run_mixed_test() {
    local duration=$1
    
    log "Starting mixed workload test for $duration seconds"
    
    # Phase 1: Warm-up (20% of duration)
    local warmup_duration=$((duration / 5))
    log "Phase 1: Warm-up (${warmup_duration}s at 2 req/s)"
    run_sustained_test $warmup_duration 2
    
    # Phase 2: Normal load (40% of duration)
    local normal_duration=$((duration * 2 / 5))
    log "Phase 2: Normal load (${normal_duration}s at 5 req/s)"
    run_sustained_test $normal_duration 5
    
    # Phase 3: High load (30% of duration)
    local high_duration=$((duration * 3 / 10))
    log "Phase 3: High load (${high_duration}s at 10 req/s)"
    run_sustained_test $high_duration 10
    
    # Phase 4: Burst (10% of duration)
    local burst_duration=$((duration / 10))
    log "Phase 4: Burst (${burst_duration}s at 20 req/s)"
    run_burst_test $burst_duration 20
    
    log "Mixed workload test completed"
}

# Generate specific currency pair tests
run_currency_tests() {
    log "Running currency-specific tests..."
    
    # USD -> ARS (most common pair)
    log "Testing USD -> ARS exchanges..."
    for i in {1..10}; do
        local request='{
            "baseCurrency": "USD",
            "counterCurrency": "ARS",
            "baseAccountId": "1",
            "counterAccountId": "2",
            "baseAmount": '$((100 + i * 50))'
        }'
        execute_exchange "$request" > /dev/null
        sleep 0.5
    done
    
    # EUR -> USD
    log "Testing EUR -> USD exchanges..."
    for i in {1..8}; do
        local request='{
            "baseCurrency": "EUR",
            "counterCurrency": "USD",
            "baseAccountId": "3",
            "counterAccountId": "2",
            "baseAmount": '$((50 + i * 25))'
        }'
        execute_exchange "$request" > /dev/null
        sleep 0.5
    done
    
    # BRL -> ARS
    log "Testing BRL -> ARS exchanges..."
    for i in {1..6}; do
        local request='{
            "baseCurrency": "BRL",
            "counterCurrency": "ARS",
            "baseAccountId": "4",
            "counterAccountId": "1",
            "baseAmount": '$((200 + i * 100))'
        }'
        execute_exchange "$request" > /dev/null
        sleep 0.5
    done
    
    success "Currency-specific tests completed"
}

# Main test execution
main() {
    log "Starting ArVault Business Metrics Test"
    log "Log file: $LOG_FILE"
    
    # Check API availability
    if ! check_api; then
        error "Cannot proceed without API. Please ensure the system is running."
        exit 1
    fi
    
    # Show current rates
    log "Current exchange rates:"
    curl -s "$API_URL/rates" | jq '.' | tee -a "$LOG_FILE"
    
    # Show current account balances
    log "Current account balances:"
    curl -s "$API_URL/accounts" | jq '.' | tee -a "$LOG_FILE"
    
    echo ""
    log "Starting test phases..."
    
    # Phase 1: Currency-specific tests
    run_currency_tests
    sleep 5
    
    # Phase 2: Mixed workload test (2 minutes)
    run_mixed_test 120
    sleep 10
    
    # Phase 3: Additional burst tests
    log "Running additional burst tests..."
    run_burst_test 30 15  # 30 seconds at 15 req/s
    sleep 5
    run_burst_test 20 25  # 20 seconds at 25 req/s
    
    # Final summary
    log "Test completed! Check your Grafana dashboard for business metrics."
    log "Dashboard URL: http://localhost:80/d/bf0hu5uvgxk3ke"
    
    # Show final account balances
    log "Final account balances:"
    curl -s "$API_URL/accounts" | jq '.' | tee -a "$LOG_FILE"
    
    success "Business metrics test completed successfully!"
    log "Log saved to: $LOG_FILE"
}

# Help function
show_help() {
    echo "ArVault Business Metrics Test Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -d, --duration Duration in seconds for mixed test (default: 120)"
    echo "  -r, --rate     Request rate per second (default: varies by phase)"
    echo "  -u, --url      API URL (default: http://localhost:5555)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run full test suite"
    echo "  $0 -d 60             # Run mixed test for 60 seconds"
    echo "  $0 -u http://localhost:8080  # Use different API URL"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--duration)
            MIXED_DURATION="$2"
            shift 2
            ;;
        -r|--rate)
            DEFAULT_RATE="$2"
            shift 2
            ;;
        -u|--url)
            API_URL="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main
