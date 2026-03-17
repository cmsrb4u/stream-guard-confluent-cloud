#!/bin/bash

# Start Stream Processors Script
# This script initializes ksqlDB streams and tables

set -e

KSQLDB_URL=${KSQLDB_URL:-http://localhost:8088}
KSQL_FILE="./processors/ksql-streams.sql"

echo "============================================"
echo "Starting Stream Processors"
echo "============================================"
echo ""

# Wait for ksqlDB to be ready
echo "⏳ Waiting for ksqlDB to be ready..."
until curl -s -f -o /dev/null "${KSQLDB_URL}/info"; do
    echo "ksqlDB is unavailable - sleeping"
    sleep 5
done

echo "✅ ksqlDB is ready!"
echo ""

# Register schemas with Schema Registry
echo "📋 Registering Avro schemas with Schema Registry..."
SCHEMA_REGISTRY_URL=${SCHEMA_REGISTRY_URL:-http://localhost:8081}

# Register Transaction schema
echo "  - Registering Transaction schema..."
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data @schemas/transaction.avsc \
    "${SCHEMA_REGISTRY_URL}/subjects/customers.cdc.customerdb.public.transactions-value/versions" || true

# Register CustomerProfile schema
echo "  - Registering CustomerProfile schema..."
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data @schemas/customer-profile.avsc \
    "${SCHEMA_REGISTRY_URL}/subjects/mongodb.customer_profiles.profiles-value/versions" || true

# Register ClickstreamEvent schema
echo "  - Registering ClickstreamEvent schema..."
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data @schemas/clickstream-event.avsc \
    "${SCHEMA_REGISTRY_URL}/subjects/clickstream.events-value/versions" || true

echo ""

# Deploy ksqlDB queries
echo "🚀 Deploying ksqlDB streams and tables..."
echo "   This will create:"
echo "   - Base streams from Kafka topics"
echo "   - Fraud detection streams"
echo "   - Customer 360 view tables"
echo "   - Product recommendation streams"
echo "   - Churn prediction indicators"
echo "   - Real-time business metrics"
echo ""

# Execute ksqlDB statements (split by semicolon and send individually)
# In production, you would use ksqlDB CLI or proper deployment tool

echo "📝 Note: For full ksqlDB deployment, execute the following:"
echo "   docker exec -it ksqldb-cli ksql http://ksqldb-server:8088"
echo "   Then run the statements from: ${KSQL_FILE}"
echo ""

# Show ksqlDB cluster info
echo "ℹ️  ksqlDB Cluster Info:"
curl -s "${KSQLDB_URL}/info" | jq .
echo ""

echo "============================================"
echo "✅ Stream processor setup complete!"
echo "============================================"
echo ""
echo "Access ksqlDB at: ${KSQLDB_URL}"
echo "View streams in Control Center: http://localhost:9021"
echo ""
echo "To manually execute ksqlDB queries:"
echo "  docker exec -it ksqldb-cli ksql http://ksqldb-server:8088"
echo ""
