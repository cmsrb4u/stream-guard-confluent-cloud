#!/bin/bash

# Deploy Confluent Connectors Script
# This script deploys all Kafka Connect connectors

set -e

CONNECT_URL=${CONNECT_URL:-http://localhost:8083}
CONNECTOR_DIR="./connectors"

echo "============================================"
echo "Deploying Confluent Connectors"
echo "============================================"
echo ""

# Wait for Kafka Connect to be ready
echo "⏳ Waiting for Kafka Connect to be ready..."
until curl -s -f -o /dev/null "${CONNECT_URL}"; do
    echo "Kafka Connect is unavailable - sleeping"
    sleep 5
done

echo "✅ Kafka Connect is ready!"
echo ""

# Check available connector plugins
echo "📦 Available connector plugins:"
curl -s "${CONNECT_URL}/connector-plugins" | jq -r '.[].class' | head -10
echo ""

# Deploy PostgreSQL CDC Connector
echo "🔌 Deploying PostgreSQL CDC Connector..."
if curl -s -X POST -H "Content-Type: application/json" \
    --data @"${CONNECTOR_DIR}/postgres-cdc-connector.json" \
    "${CONNECT_URL}/connectors" | jq .; then
    echo "✅ PostgreSQL CDC Connector deployed successfully"
else
    echo "⚠️  PostgreSQL CDC Connector deployment failed or already exists"
fi
echo ""

# Deploy MongoDB Source Connector
echo "🔌 Deploying MongoDB Source Connector..."
if curl -s -X POST -H "Content-Type: application/json" \
    --data @"${CONNECTOR_DIR}/mongodb-profiles-connector.json" \
    "${CONNECT_URL}/connectors" | jq .; then
    echo "✅ MongoDB Source Connector deployed successfully"
else
    echo "⚠️  MongoDB Source Connector deployment failed or already exists"
fi
echo ""

# Deploy HTTP Source Connector
echo "🔌 Deploying HTTP Source Connector..."
if curl -s -X POST -H "Content-Type: application/json" \
    --data @"${CONNECTOR_DIR}/http-clickstream-connector.json" \
    "${CONNECT_URL}/connectors" | jq .; then
    echo "✅ HTTP Source Connector deployed successfully"
else
    echo "⚠️  HTTP Source Connector deployment failed or already exists"
fi
echo ""

# List all connectors
echo "📋 Active connectors:"
curl -s "${CONNECT_URL}/connectors" | jq .
echo ""

# Check connector status
echo "🔍 Connector status:"
for connector in $(curl -s "${CONNECT_URL}/connectors" | jq -r '.[]'); do
    echo "  - ${connector}:"
    curl -s "${CONNECT_URL}/connectors/${connector}/status" | jq -r '.connector.state'
done
echo ""

echo "============================================"
echo "✅ Connector deployment complete!"
echo "============================================"
echo ""
echo "Monitor connectors at: http://localhost:9021"
echo "Kafka Connect REST API: ${CONNECT_URL}"
echo ""
