#!/bin/bash

set -e

echo "============================================"
echo "Creating Topics on Confluent Cloud"
echo "============================================"
echo ""

API_KEY="5JR4MWVSUDAMUUDD"
API_SECRET="cfltJECbrAWagtOZ0EMFWE/i0w9q5OyEW822CBdMnCxj7oKMyT+werUWXagehDTQ"
CLUSTER_ID="lkc-73355p"
KAFKA_REST_URL="https://pkc-619z3.us-east1.gcp.confluent.cloud"

echo "Cluster: $CLUSTER_ID"
echo ""

# Function to create topic
create_topic() {
    local topic_name=$1
    local partitions=$2
    local retention_ms=$3
    local cleanup_policy=${4:-delete}
    
    echo "Creating topic: $topic_name (${partitions} partitions, cleanup: ${cleanup_policy})"
    
    RESPONSE=$(curl -s -X POST \
        -u "${API_KEY}:${API_SECRET}" \
        -H "Content-Type: application/json" \
        "${KAFKA_REST_URL}/kafka/v3/clusters/${CLUSTER_ID}/topics" \
        -d "{
            \"topic_name\": \"${topic_name}\",
            \"partitions_count\": ${partitions},
            \"configs\": [
                {\"name\": \"retention.ms\", \"value\": \"${retention_ms}\"},
                {\"name\": \"cleanup.policy\", \"value\": \"${cleanup_policy}\"}
            ]
        }")
    
    if echo "$RESPONSE" | grep -q "topic_name"; then
        echo "  ✅ Created successfully"
    else
        echo "  ⚠️  Response: $RESPONSE"
    fi
    echo ""
}

# Create topics
echo "Creating topics..."
echo ""

create_topic "customers.transactions" 6 604800000 delete  # 7 days
create_topic "customer.profiles" 3 -1 compact  # forever, compacted
create_topic "clickstream.events" 12 86400000 delete  # 1 day
create_topic "fraud.alerts" 3 2592000000 delete  # 30 days
create_topic "fraud.risk-scores" 6 604800000 delete  # 7 days

echo "============================================"
echo "✅ Topics creation completed!"
echo "============================================"
echo ""
echo "Verify in Confluent Cloud:"
echo "https://confluent.cloud"
echo ""
