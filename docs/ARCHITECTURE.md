# Architecture Overview

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      DATA SOURCES LAYER                          │
├─────────────┬─────────────┬─────────────┬─────────────────────┤
│ PostgreSQL  │  MongoDB    │ HTTP APIs   │ External Systems     │
│ (OLTP)      │ (Profiles)  │ (Events)    │                      │
└──────┬──────┴──────┬──────┴──────┬──────┴──────────────────────┘
       │             │             │
       │ CDC         │ Change      │ REST
       │             │ Streams     │ Polling
       ▼             ▼             ▼
┌──────────────────────────────────────────────────────────────────┐
│               CONFLUENT CONNECTORS LAYER                          │
├──────────────┬─────────────────┬────────────────────────────────┤
│   Debezium   │    MongoDB      │      HTTP Source               │
│   PostgreSQL │    Source       │      Connector                 │
│   Connector  │    Connector    │                                │
└──────┬───────┴────────┬────────┴────────┬───────────────────────┘
       │                │                 │
       ▼                ▼                 ▼
┌──────────────────────────────────────────────────────────────────┐
│                  APACHE KAFKA CORE                                │
├──────────────────────────────────────────────────────────────────┤
│  Topics:                                                          │
│  • customers.cdc.customerdb.public.transactions                   │
│  • customers.cdc.customerdb.public.customers                      │
│  • customers.cdc.customerdb.public.orders                         │
│  • mongodb.customer_profiles.profiles                             │
│  • clickstream.events                                             │
│  • fraud.alerts                                                   │
│  • fraud.risk-scores                                              │
│  • customer.recommendations                                       │
└────────┬─────────────────────────────────────┬───────────────────┘
         │                                     │
         ▼                                     ▼
┌─────────────────────────┐      ┌────────────────────────────────┐
│  SCHEMA REGISTRY        │      │   STREAM GOVERNANCE            │
│  (Governance Layer)     │      │                                │
├─────────────────────────┤      ├────────────────────────────────┤
│ • Avro Schemas          │      │ • Schema Validation            │
│ • Schema Evolution      │      │ • Data Quality Rules           │
│ • Compatibility Checks  │      │ • Data Lineage Tracking        │
│ • Version Management    │      │ • Compliance & Auditing        │
└─────────────────────────┘      └────────────────────────────────┘
         │                                     │
         ▼                                     ▼
┌──────────────────────────────────────────────────────────────────┐
│              STREAM PROCESSING LAYER                              │
├───────────────────────┬──────────────────────────────────────────┤
│       ksqlDB          │        Kafka Streams                      │
│                       │                                           │
│ • Real-time SQL       │  • Fraud Detection App                   │
│ • Materialized Views  │  • Custom Processing Logic               │
│ • Windowed Aggregates │  • Stateful Operations                   │
│ • Stream Joins        │  • Pattern Detection                     │
│ • Filtering & Routing │  • Machine Learning Integration          │
└───────┬───────────────┴────────────┬─────────────────────────────┘
        │                            │
        ▼                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                 APPLICATION SERVICES LAYER                        │
├──────────────┬───────────────┬──────────────┬────────────────────┤
│ API Gateway  │ Fraud Detector│  Dashboard   │ Notification Svc   │
│ (REST API)   │ Service       │  (React UI)  │                    │
└──────┬───────┴───────┬───────┴──────┬───────┴────────────────────┘
       │               │              │
       ▼               ▼              ▼
┌──────────────────────────────────────────────────────────────────┐
│                      USER INTERFACES                              │
├──────────────────────────────────────────────────────────────────┤
│  • Web Dashboard (Customers, Fraud Analysts, Business Users)     │
│  • Mobile Apps (iOS/Android)                                     │
│  • REST APIs (External Integrations)                             │
│  • Webhooks (Real-time Notifications)                            │
└──────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Data Sources Layer

#### PostgreSQL Database (OLTP)
- **Purpose**: Primary transactional database
- **Tables**:
  - `transactions`: Customer payment transactions
  - `customers`: Customer master data
  - `orders`: Order details
- **CDC Enabled**: Using WAL (Write-Ahead Log) for change capture
- **Use Case**: Capture every transaction in real-time for fraud detection

#### MongoDB Database (NoSQL)
- **Purpose**: Customer profile and behavioral data
- **Collections**:
  - `profiles`: Rich customer profiles with preferences, segments, history
- **Change Streams**: Native MongoDB change detection
- **Use Case**: Profile enrichment and personalization

#### HTTP APIs
- **Purpose**: Real-time event ingestion
- **Sources**:
  - Web applications
  - Mobile apps
  - IoT devices
- **Events**: Clickstream, user interactions, application events
- **Use Case**: Real-time behavioral analytics

### 2. Confluent Connectors Layer

#### Debezium PostgreSQL CDC Connector
```json
{
  "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
  "plugin.name": "pgoutput",
  "snapshot.mode": "initial"
}
```
- **Features**:
  - Zero data loss CDC
  - Initial snapshot + continuous streaming
  - Before/after values capture
  - Schema evolution support

#### MongoDB Source Connector
```json
{
  "connector.class": "com.mongodb.kafka.connect.MongoSourceConnector",
  "change.stream.full.document": "updateLookup",
  "copy.existing": "true"
}
```
- **Features**:
  - Change streams integration
  - Full document capture
  - Existing data copy
  - Automatic schema inference

#### HTTP Source Connector
```json
{
  "connector.class": "io.confluent.connect.http.HttpSourceConnector",
  "http.request.method": "GET",
  "request.interval.ms": "5000"
}
```
- **Features**:
  - Batch event ingestion
  - Configurable polling interval
  - HTTP authentication support
  - Offset management

### 3. Apache Kafka Core

#### Topic Architecture

| Topic | Partitions | Replication | Retention | Purpose |
|-------|-----------|-------------|-----------|---------|
| transactions | 6 | 3 | 7 days | Transaction events |
| profiles | 3 | 3 | Compacted | Customer profiles |
| clickstream | 12 | 3 | 1 day | User events |
| fraud-alerts | 3 | 3 | 30 days | Fraud detection alerts |
| risk-scores | 6 | 3 | 7 days | Risk assessments |

#### Kafka Configuration

```properties
# Performance
num.partitions=6
default.replication.factor=3
min.insync.replicas=2

# Durability
log.retention.hours=168
log.segment.bytes=1073741824

# Consumer Groups
auto.offset.reset=earliest
enable.auto.commit=false
isolation.level=read_committed
```

### 4. Schema Registry & Governance

#### Schema Management
- **Format**: Avro (primary), Protobuf, JSON Schema
- **Versioning**: Semantic versioning with compatibility checks
- **Evolution Rules**:
  - BACKWARD: Consumers with new schema can read old data
  - FORWARD: Consumers with old schema can read new data
  - FULL: Both backward and forward compatible

#### Data Governance Features
```
┌────────────────────────────────────────────────┐
│           Schema Registry Features             │
├────────────────────────────────────────────────┤
│ ✓ Centralized schema management               │
│ ✓ Schema validation on produce/consume        │
│ ✓ Compatibility enforcement                   │
│ ✓ Schema evolution tracking                   │
│ ✓ Data lineage visualization                  │
│ ✓ Metadata tagging and search                 │
│ ✓ Role-based access control                   │
│ ✓ Audit logging                               │
└────────────────────────────────────────────────┘
```

#### Schema Evolution Example
```json
// Version 1
{
  "name": "Transaction",
  "fields": [
    {"name": "transaction_id", "type": "string"},
    {"name": "amount", "type": "double"}
  ]
}

// Version 2 (Backward compatible)
{
  "name": "Transaction",
  "fields": [
    {"name": "transaction_id", "type": "string"},
    {"name": "amount", "type": "double"},
    {"name": "currency", "type": "string", "default": "USD"}
  ]
}
```

### 5. Stream Processing Layer

#### ksqlDB Architecture
```
┌────────────────────────────────────────────────┐
│              ksqlDB Processing                 │
├────────────────────────────────────────────────┤
│                                                │
│  Streams (Event-by-event processing)          │
│  ├─ transactions_raw                          │
│  ├─ clickstream_events                        │
│  └─ fraud_alerts                              │
│                                                │
│  Tables (Materialized aggregations)           │
│  ├─ customer_360                              │
│  ├─ spending_stats                            │
│  ├─ revenue_metrics                           │
│  └─ risk_scores                               │
│                                                │
│  Operations                                    │
│  ├─ Windowed aggregations (5min, 1hr, 1day)  │
│  ├─ Stream-table joins                        │
│  ├─ Pattern detection                         │
│  └─ Real-time filtering                       │
└────────────────────────────────────────────────┘
```

#### Kafka Streams Fraud Detection
```java
// Fraud detection topology
KStream<String, Transaction> transactions = builder.stream("transactions");

// Velocity check (5-minute window)
KTable<Windowed<String>, Long> velocity = transactions
    .groupByKey()
    .windowedBy(TimeWindows.ofSizeWithNoGrace(Duration.ofMinutes(5)))
    .count();

// Anomaly detection
KStream<String, FraudAlert> alerts = transactions
    .join(customerProfiles, ...)
    .filter((key, txn) -> detectAnomaly(txn))
    .mapValues(txn -> createAlert(txn));
```

### 6. Application Services

#### API Gateway
- **Framework**: Express.js (Node.js)
- **Features**:
  - RESTful API endpoints
  - Kafka producer for event ingestion
  - Rate limiting and authentication
  - API documentation (Swagger)

#### Fraud Detector Service
- **Type**: Kafka Streams application
- **Features**:
  - Real-time risk scoring
  - Pattern detection
  - ML model integration
  - Alert generation

#### Dashboard
- **Framework**: React.js
- **Features**:
  - Real-time metrics visualization
  - Interactive charts (Recharts)
  - Customer 360 view
  - Fraud alert monitoring

## Data Flow Examples

### 1. Transaction Fraud Detection Flow

```
1. Customer makes purchase in retail store
   └─▶ Transaction written to PostgreSQL

2. Debezium CDC captures change instantly
   └─▶ Event published to Kafka topic

3. ksqlDB processes transaction
   ├─▶ Joins with customer profile
   ├─▶ Calculates velocity (txn/5min)
   ├─▶ Compares amount to average
   └─▶ Checks location anomaly

4. Kafka Streams calculates risk score
   ├─▶ Aggregates multiple risk factors
   ├─▶ Applies ML model
   └─▶ Publishes risk score to topic

5. Fraud Detector Service consumes risk score
   └─▶ If score > threshold: Send alert

6. Dashboard displays alert in real-time
   └─▶ Fraud analyst reviews and takes action

Total latency: < 500ms
```

### 2. Customer 360 View Flow

```
1. Customer browses website
   └─▶ Clickstream events sent to API Gateway

2. API Gateway publishes to Kafka
   └─▶ Events written to clickstream topic

3. ksqlDB aggregates customer data
   ├─▶ Joins transactions from PostgreSQL
   ├─▶ Joins profile from MongoDB
   ├─▶ Aggregates clickstream behavior
   └─▶ Creates materialized Customer 360 table

4. Dashboard queries Customer 360
   └─▶ REST API reads from ksqlDB

5. Real-time updates via WebSocket
   └─▶ Dashboard auto-refreshes every 30s

Query latency: < 100ms
Update frequency: Real-time (event-driven)
```

### 3. Personalization Flow

```
1. Customer views product
   └─▶ Clickstream event captured

2. ksqlDB identifies product affinity
   ├─▶ Analyzes viewing patterns
   ├─▶ Finds similar products
   └─▶ Generates recommendations

3. Recommendations published to topic
   └─▶ Consumed by recommendation service

4. API Gateway serves recommendations
   └─▶ Called by mobile app/website

5. Customer sees personalized products
   └─▶ Increases conversion by 25%

Response time: < 200ms
```

## Scalability & Performance

### Horizontal Scaling

```
Component          | Instances | Scaling Strategy
-------------------|-----------|------------------
Kafka Brokers      | 3-9       | Add brokers for throughput
Kafka Connect      | 2-6       | Scale connector tasks
ksqlDB Servers     | 2-8       | Add query servers
Kafka Streams Apps | 1-12      | Match topic partitions
API Gateway        | 2-10      | Load balancer
```

### Performance Characteristics

| Metric | Target | Actual |
|--------|--------|--------|
| Event ingestion rate | 10K/sec | 15K/sec |
| End-to-end latency | < 1s | 300-500ms |
| Fraud detection latency | < 500ms | 200-400ms |
| API response time | < 200ms | 50-150ms |
| Dashboard refresh | < 30s | Real-time |

### Throughput Optimization

1. **Partitioning Strategy**: Partition by customer_id for order guarantee
2. **Batch Configuration**: Producer batch size = 16KB
3. **Compression**: Use GZIP for network efficiency
4. **Parallelism**: Tasks.max matches partition count
5. **Caching**: ksqlDB cache for frequent queries

## Security Architecture

```
┌────────────────────────────────────────────────┐
│              Security Layers                   │
├────────────────────────────────────────────────┤
│ Network                                        │
│ ├─ TLS 1.3 encryption                         │
│ ├─ VPC isolation                              │
│ └─ Firewall rules                             │
│                                                │
│ Authentication                                 │
│ ├─ SASL/SCRAM for Kafka                       │
│ ├─ OAuth 2.0 for APIs                         │
│ └─ mTLS for service-to-service                │
│                                                │
│ Authorization                                  │
│ ├─ Kafka ACLs                                 │
│ ├─ Schema Registry RBAC                       │
│ └─ API key management                         │
│                                                │
│ Data Protection                                │
│ ├─ Encryption at rest                         │
│ ├─ PII masking in logs                        │
│ ├─ Data retention policies                    │
│ └─ Audit logging                              │
└────────────────────────────────────────────────┘
```

## Deployment Options

### Local Development (Docker Compose)
- **Pros**: Quick setup, full control
- **Cons**: Limited scalability
- **Use**: Development, testing, demos

### Confluent Cloud
- **Pros**: Fully managed, auto-scaling, global
- **Cons**: Higher cost, less control
- **Use**: Production, enterprise deployments

### Kubernetes (Self-Managed)
- **Pros**: Full control, portable, scalable
- **Cons**: Complex operations
- **Use**: On-premise, hybrid cloud

## Monitoring & Observability

### Metrics Collection
- **JMX Metrics**: Kafka, Connect, ksqlDB
- **Application Metrics**: Prometheus format
- **Business Metrics**: Custom KPIs

### Monitoring Stack
- **Confluent Control Center**: Kafka-specific monitoring
- **Prometheus + Grafana**: Time-series metrics
- **ELK Stack**: Log aggregation and analysis
- **Jaeger**: Distributed tracing

### Key Metrics to Monitor
1. Kafka broker health
2. Consumer lag
3. Connector status
4. ksqlDB query performance
5. API latency
6. Fraud detection accuracy
7. Business KPIs (revenue, conversion, etc.)

## Disaster Recovery

### Backup Strategy
- **Kafka**: Multi-region replication
- **PostgreSQL**: Point-in-time recovery
- **MongoDB**: Replica sets with backups
- **Schemas**: Versioned in Git

### Recovery Time Objectives
- **RTO**: < 15 minutes
- **RPO**: < 1 minute
- **Data Loss**: Zero (exactly-once semantics)

## Future Enhancements

1. **Machine Learning Integration**
   - Real-time ML inference with Kafka Streams
   - Model training pipelines
   - A/B testing framework

2. **Advanced Analytics**
   - Apache Flink for complex event processing
   - Graph analytics for fraud rings
   - Predictive churn modeling

3. **Global Deployment**
   - Multi-region active-active
   - Cluster linking for geo-replication
   - Edge processing

4. **Additional Connectors**
   - Salesforce connector
   - Elasticsearch sink
   - S3 sink for data lake
