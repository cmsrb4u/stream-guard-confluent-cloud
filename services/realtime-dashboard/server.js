const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const { Kafka } = require('kafkajs');
const path = require('path');
require('dotenv').config({ path: '/workshop/.env' });

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

const PORT = 3000; // Changed to 3000

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// In-memory storage for dashboard
const dashboardData = {
  transactions: [],
  fraudAlerts: [],
  clickstreamEvents: [],
  customerMetrics: {},
  stats: {
    totalTransactions: 0,
    totalFraudAlerts: 0,
    totalRevenue: 0,
    avgTransactionAmount: 0,
    fraudRate: 0
  }
};

// Keep only last 50 items
const MAX_ITEMS = 50;

// Kafka Configuration
const kafka = new Kafka({
  clientId: 'realtime-dashboard',
  brokers: [process.env.KAFKA_BOOTSTRAP_SERVERS || 'pkc-619z3.us-east1.gcp.confluent.cloud:9092'],
  ssl: true,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_SASL_USERNAME || '5JR4MWVSUDAMUUDD',
    password: process.env.KAFKA_SASL_PASSWORD || 'cfltJECbrAWagtOZ0EMFWE/i0w9q5OyEW822CBdMnCxj7oKMyT+werUWXagehDTQ'
  }
});

// Create consumers
const transactionConsumer = kafka.consumer({ groupId: 'dashboard-transactions-v2' });
const clickstreamConsumer = kafka.consumer({ groupId: 'dashboard-clickstream-v2' });

// Fraud detection logic
function detectFraud(transaction) {
  const alerts = [];
  let riskScore = 0;

  // Check 1: High value transaction (>$5000)
  if (transaction.amount > 5000) {
    alerts.push('High value transaction');
    riskScore += 40;
  }

  // Check 2: Suspicious location
  if (transaction.location && ['Russia', 'China', 'Nigeria'].includes(transaction.location.country)) {
    alerts.push('Suspicious location');
    riskScore += 30;
  }

  // Check 3: Online merchant with high value
  if (transaction.merchant_category === 'ONLINE' && transaction.amount > 1000) {
    alerts.push('High value online purchase');
    riskScore += 20;
  }

  // Check 4: Quick succession (velocity check - simplified)
  const recentTransactions = dashboardData.transactions.filter(t =>
    t.customer_id === transaction.customer_id &&
    Date.now() - t.timestamp < 3600000 // Last hour
  );

  if (recentTransactions.length > 5) {
    alerts.push('Velocity attack detected');
    riskScore += 50;
  }

  return {
    isFraud: riskScore >= 50,
    riskScore,
    alerts
  };
}

// Process transaction
function processTransaction(transaction) {
  // Add to transactions list
  dashboardData.transactions.unshift(transaction);
  if (dashboardData.transactions.length > MAX_ITEMS) {
    dashboardData.transactions.pop();
  }

  // Update stats
  dashboardData.stats.totalTransactions++;
  dashboardData.stats.totalRevenue += transaction.amount || 0;
  dashboardData.stats.avgTransactionAmount =
    dashboardData.stats.totalRevenue / dashboardData.stats.totalTransactions;

  // Check for fraud
  const fraudCheck = detectFraud(transaction);

  if (fraudCheck.isFraud) {
    const fraudAlert = {
      alert_id: `ALERT-${Date.now()}`,
      transaction_id: transaction.transaction_id,
      customer_id: transaction.customer_id,
      amount: transaction.amount,
      risk_score: fraudCheck.riskScore,
      alerts: fraudCheck.alerts,
      timestamp: Date.now(),
      status: 'CRITICAL'
    };

    dashboardData.fraudAlerts.unshift(fraudAlert);
    if (dashboardData.fraudAlerts.length > MAX_ITEMS) {
      dashboardData.fraudAlerts.pop();
    }

    dashboardData.stats.totalFraudAlerts++;
    dashboardData.stats.fraudRate =
      (dashboardData.stats.totalFraudAlerts / dashboardData.stats.totalTransactions * 100).toFixed(2);

    // Emit fraud alert
    io.emit('fraudAlert', fraudAlert);
    console.log(`🚨 FRAUD ALERT: ${fraudAlert.transaction_id} - Risk: ${fraudAlert.risk_score}`);
  }

  // Update customer metrics
  if (transaction.customer_id) {
    if (!dashboardData.customerMetrics[transaction.customer_id]) {
      dashboardData.customerMetrics[transaction.customer_id] = {
        customer_id: transaction.customer_id,
        total_transactions: 0,
        total_spent: 0,
        avg_transaction: 0,
        last_transaction: null
      };
    }

    const metrics = dashboardData.customerMetrics[transaction.customer_id];
    metrics.total_transactions++;
    metrics.total_spent += transaction.amount || 0;
    metrics.avg_transaction = metrics.total_spent / metrics.total_transactions;
    metrics.last_transaction = transaction.timestamp;
  }

  // Emit to connected clients
  io.emit('transaction', transaction);
  io.emit('stats', dashboardData.stats);
}

// Process clickstream event
function processClickstreamEvent(event) {
  dashboardData.clickstreamEvents.unshift(event);
  if (dashboardData.clickstreamEvents.length > MAX_ITEMS) {
    dashboardData.clickstreamEvents.pop();
  }

  io.emit('clickstream', event);
}

// Start Kafka consumers
async function startConsumers() {
  try {
    // Transaction consumer - ONLY JSON topics
    await transactionConsumer.connect();
    await transactionConsumer.subscribe({
      topics: ['customers.transactions'], // Only JSON topic
      fromBeginning: false
    });

    await transactionConsumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          const transaction = JSON.parse(message.value.toString());
          console.log(`📊 Transaction: ${transaction.transaction_id} - $${transaction.amount}`);

          processTransaction(transaction);
        } catch (error) {
          console.error('Error processing transaction:', error.message);
        }
      }
    });

    // Clickstream consumer
    await clickstreamConsumer.connect();
    await clickstreamConsumer.subscribe({
      topics: ['clickstream.events'],
      fromBeginning: false
    });

    await clickstreamConsumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          const event = JSON.parse(message.value.toString());
          console.log(`👆 Event: ${event.event_type} - ${event.customer_id}`);
          processClickstreamEvent(event);
        } catch (error) {
          console.error('Error processing clickstream:', error.message);
        }
      }
    });

    console.log('✅ Kafka consumers started successfully');
    console.log('📊 Consuming from: customers.transactions, clickstream.events');
  } catch (error) {
    console.error('❌ Failed to start Kafka consumers:', error);
  }
}

// API endpoints
app.get('/api/dashboard/data', (req, res) => {
  res.json({
    transactions: dashboardData.transactions.slice(0, 20),
    fraudAlerts: dashboardData.fraudAlerts.slice(0, 10),
    clickstreamEvents: dashboardData.clickstreamEvents.slice(0, 20),
    stats: dashboardData.stats,
    topCustomers: Object.values(dashboardData.customerMetrics)
      .sort((a, b) => b.total_spent - a.total_spent)
      .slice(0, 5)
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'realtime-dashboard',
    kafka_connected: true,
    timestamp: new Date().toISOString()
  });
});

// WebSocket connection
io.on('connection', (socket) => {
  console.log('🔌 Client connected to dashboard');

  // Send initial data
  socket.emit('initialData', {
    transactions: dashboardData.transactions.slice(0, 20),
    fraudAlerts: dashboardData.fraudAlerts.slice(0, 10),
    clickstreamEvents: dashboardData.clickstreamEvents.slice(0, 20),
    stats: dashboardData.stats
  });

  socket.on('disconnect', () => {
    console.log('🔌 Client disconnected from dashboard');
  });
});

// Start server
server.listen(PORT, () => {
  console.log(`\n========================================`);
  console.log(`🚀 Real-time Dashboard LIVE`);
  console.log(`========================================`);
  console.log(`📊 Dashboard URL: http://localhost:${PORT}`);
  console.log(`🔌 WebSocket: Ready`);
  console.log(`☁️  Confluent Cloud: Connected`);
  console.log(`========================================\n`);

  // Start consuming from Kafka
  startConsumers();
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('Shutting down...');
  await transactionConsumer.disconnect();
  await clickstreamConsumer.disconnect();
  process.exit(0);
});
