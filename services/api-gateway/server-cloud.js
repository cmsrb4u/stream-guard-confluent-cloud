const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const { Kafka } = require('kafkajs');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

// Kafka Configuration for Confluent Cloud
const kafka = new Kafka({
  clientId: 'api-gateway',
  brokers: [process.env.KAFKA_BOOTSTRAP_SERVERS || 'pkc-619z3.us-east1.gcp.confluent.cloud:9092'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_SASL_USERNAME || '5JR4MWVSUDAMUUDD',
    password: process.env.KAFKA_SASL_PASSWORD || 'cfltJECbrAWagtOZ0EMFWE/i0w9q5OyEW822CBdMnCxj7oKMyT+werUWXagehDTQ'
  }
});

const producer = kafka.producer();
let producerReady = false;

// Initialize Kafka Producer
async function initKafka() {
  try {
    await producer.connect();
    producerReady = true;
    console.log('✅ Kafka producer connected to Confluent Cloud');
  } catch (error) {
    console.error('❌ Failed to connect Kafka producer:', error);
  }
}

// In-memory storage for demo
let clickstreamBuffer = [];
let lastBatchTimestamp = Date.now();

// Health Check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'api-gateway',
    kafka: producerReady ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString(),
    confluent_cloud: true
  });
});

// Track clickstream event
app.post('/api/clickstream/track', async (req, res) => {
  try {
    const event = {
      event_id: uuidv4(),
      session_id: req.body.session_id,
      customer_id: req.body.customer_id || null,
      event_type: req.body.event_type,
      page_url: req.body.page_url,
      referrer: req.body.referrer || null,
      product_id: req.body.product_id || null,
      search_query: req.body.search_query || null,
      timestamp: Date.now(),
      metadata: req.body.metadata || {}
    };

    clickstreamBuffer.push(event);

    if (producerReady) {
      await producer.send({
        topic: 'clickstream.events',
        messages: [{
          key: event.event_id,
          value: JSON.stringify(event)
        }]
      });
      console.log(`📊 Clickstream event tracked: ${event.event_type}`);
    }

    res.status(201).json({
      success: true,
      event_id: event.event_id
    });
  } catch (error) {
    console.error('Error tracking event:', error);
    res.status(500).json({ error: error.message });
  }
});

// Batch endpoint for HTTP connector
app.get('/api/clickstream/batch', (req, res) => {
  const currentTime = Date.now();
  const events = clickstreamBuffer
    .filter(e => e.timestamp > lastBatchTimestamp)
    .slice(0, 100);

  if (events.length > 0) {
    lastBatchTimestamp = currentTime;
  }

  res.json({
    events,
    batch_size: events.length,
    timestamp: currentTime
  });
});

// Create transaction
app.post('/api/transactions', async (req, res) => {
  try {
    const transaction = {
      transaction_id: uuidv4(),
      customer_id: req.body.customer_id,
      amount: req.body.amount,
      currency: req.body.currency || 'USD',
      merchant_id: req.body.merchant_id,
      merchant_category: req.body.merchant_category,
      location: req.body.location,
      payment_method: req.body.payment_method,
      device_info: req.body.device_info,
      timestamp: Date.now(),
      status: 'PENDING'
    };

    if (producerReady) {
      await producer.send({
        topic: 'customers.transactions',
        messages: [{
          key: transaction.transaction_id,
          value: JSON.stringify(transaction)
        }]
      });
      console.log(`💳 Transaction created: ${transaction.transaction_id} - $${transaction.amount}`);
    }

    res.status(201).json({ success: true, transaction });
  } catch (error) {
    console.error('Error creating transaction:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get customer 360
app.get('/api/customers/:customerId/360', (req, res) => {
  res.json({
    customer_id: req.params.customerId,
    profile: {
      email: 'customer@email.com',
      name: 'John Doe',
      segments: ['VIP', 'ACTIVE']
    },
    spending: {
      total_transactions: 45,
      total_spent: 5420.50,
      avg_transaction: 120.45
    },
    engagement: {
      total_sessions: 128,
      page_views: 450,
      conversion_rate: 3.8
    },
    risk: {
      fraud_score: 12.5,
      churn_score: 15.2,
      status: 'LOW_RISK'
    }
  });
});

// Get fraud alerts
app.get('/api/fraud/alerts', (req, res) => {
  res.json({
    alerts: [
      {
        alert_id: uuidv4(),
        customer_id: 'CUST001',
        alert_type: 'HIGH_VALUE',
        risk_score: 85.0,
        reason: 'Transaction exceeds $5000',
        timestamp: new Date().toISOString()
      }
    ]
  });
});

// Get recommendations
app.get('/api/customers/:customerId/recommendations', (req, res) => {
  res.json({
    customer_id: req.params.customerId,
    recommendations: [
      { product_id: 'PROD123', name: 'Wireless Headphones', score: 0.92 },
      { product_id: 'PROD456', name: 'Smart Watch', score: 0.87 }
    ]
  });
});

// Get metrics
app.get('/api/analytics/metrics', (req, res) => {
  res.json({
    realtime: {
      active_sessions: 247,
      transactions_per_minute: 45,
      revenue_per_hour: 12500.00
    },
    conversion: {
      page_views: 5420,
      purchases: 128,
      conversion_rate: 2.36
    },
    fraud: {
      total_alerts: 15,
      high_risk: 3
    }
  });
});

// Generate demo events
app.post('/api/demo/generate-events', async (req, res) => {
  const count = req.body.count || 10;
  const generatedEvents = [];

  for (let i = 0; i < count; i++) {
    const event = {
      event_id: uuidv4(),
      session_id: `session_${Math.floor(Math.random() * 100)}`,
      customer_id: `CUST00${Math.floor(Math.random() * 5) + 1}`,
      event_type: ['PAGE_VIEW', 'CLICK', 'ADD_TO_CART'][Math.floor(Math.random() * 3)],
      page_url: `https://example.com/page${Math.floor(Math.random() * 10)}`,
      timestamp: Date.now(),
      metadata: { demo: 'true' }
    };

    clickstreamBuffer.push(event);
    generatedEvents.push(event);

    if (producerReady) {
      await producer.send({
        topic: 'clickstream.events',
        messages: [{ key: event.event_id, value: JSON.stringify(event) }]
      });
    }
  }

  res.json({ success: true, generated_count: count, events: generatedEvents });
});

// Initialize and start
initKafka().then(() => {
  app.listen(PORT, () => {
    console.log(`\n🚀 API Gateway running on port ${PORT}`);
    console.log(`☁️  Connected to Confluent Cloud`);
    console.log(`📊 Health: http://localhost:${PORT}/health\n`);
  });
});

process.on('SIGTERM', async () => {
  await producer.disconnect();
  process.exit(0);
});
