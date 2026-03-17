#!/bin/bash

# Generate Demo Data Script
# This script generates sample transactions and clickstream events

set -e

API_URL=${API_URL:-http://localhost:3001}

echo "============================================"
echo "Generating Demo Data"
echo "============================================"
echo ""

# Wait for API Gateway to be ready
echo "⏳ Waiting for API Gateway to be ready..."
until curl -s -f -o /dev/null "${API_URL}/health"; do
    echo "API Gateway is unavailable - sleeping"
    sleep 2
done

echo "✅ API Gateway is ready!"
echo ""

# Generate clickstream events
echo "📊 Generating clickstream events..."
curl -s -X POST "${API_URL}/api/demo/generate-events" \
    -H "Content-Type: application/json" \
    -d '{"count": 50}' | jq .

echo ""

# Generate sample transactions
echo "💳 Generating sample transactions..."

CUSTOMERS=("CUST001" "CUST002" "CUST003" "CUST004" "CUST005")
MERCHANTS=("MERCH_RETAIL_001" "MERCH_FOOD_001" "MERCH_ONLINE_001" "MERCH_TRAVEL_001")
CATEGORIES=("RETAIL" "FOOD" "ONLINE" "TRAVEL" "ENTERTAINMENT")
COUNTRIES=("USA" "UK" "France" "Germany" "Canada")
CITIES=("New York" "London" "Paris" "Berlin" "Toronto")

for i in {1..20}; do
    CUSTOMER=${CUSTOMERS[$RANDOM % ${#CUSTOMERS[@]}]}
    MERCHANT=${MERCHANTS[$RANDOM % ${#MERCHANTS[@]}]}
    CATEGORY=${CATEGORIES[$RANDOM % ${#CATEGORIES[@]}]}
    COUNTRY=${COUNTRIES[$RANDOM % ${#COUNTRIES[@]}]}
    CITY=${CITIES[$RANDOM % ${#CITIES[@]}]}
    AMOUNT=$(awk -v min=10 -v max=2000 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')

    curl -s -X POST "${API_URL}/api/transactions" \
        -H "Content-Type: application/json" \
        -d "{
            \"customer_id\": \"${CUSTOMER}\",
            \"amount\": ${AMOUNT},
            \"merchant_id\": \"${MERCHANT}\",
            \"merchant_category\": \"${CATEGORY}\",
            \"location\": {
                \"country\": \"${COUNTRY}\",
                \"city\": \"${CITY}\"
            },
            \"payment_method\": \"CREDIT_CARD\",
            \"device_info\": {
                \"device_id\": \"DEV${i}\",
                \"device_type\": \"mobile\",
                \"ip_address\": \"192.168.1.${i}\"
            }
        }" > /dev/null

    echo "  ✓ Generated transaction #${i} for ${CUSTOMER}: \$${AMOUNT}"
    sleep 0.5
done

echo ""

# Generate some high-value transactions (potential fraud)
echo "🚨 Generating high-value transactions (potential fraud)..."
for i in {1..5}; do
    CUSTOMER=${CUSTOMERS[$RANDOM % ${#CUSTOMERS[@]}]}
    AMOUNT=$(awk -v min=5000 -v max=10000 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')

    curl -s -X POST "${API_URL}/api/transactions" \
        -H "Content-Type: application/json" \
        -d "{
            \"customer_id\": \"${CUSTOMER}\",
            \"amount\": ${AMOUNT},
            \"merchant_id\": \"MERCH_ONLINE_002\",
            \"merchant_category\": \"ONLINE\",
            \"location\": {
                \"country\": \"USA\",
                \"city\": \"New York\"
            },
            \"payment_method\": \"CREDIT_CARD\",
            \"device_info\": {
                \"device_id\": \"DEV999\",
                \"device_type\": \"desktop\",
                \"ip_address\": \"10.0.0.1\"
            }
        }" > /dev/null

    echo "  ⚠️  Generated high-value transaction for ${CUSTOMER}: \$${AMOUNT}"
    sleep 0.5
done

echo ""
echo "============================================"
echo "✅ Demo data generation complete!"
echo "============================================"
echo ""
echo "Generated:"
echo "  - 50 clickstream events"
echo "  - 20 normal transactions"
echo "  - 5 high-value transactions (fraud candidates)"
echo ""
echo "View data in:"
echo "  - Dashboard: http://localhost:3000"
echo "  - Control Center: http://localhost:9021"
echo "  - API: ${API_URL}/api/analytics/metrics"
echo ""
