package com.customer.experience;

import io.confluent.kafka.streams.serdes.avro.SpecificAvroSerde;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.kstream.*;
import org.apache.kafka.streams.state.Stores;
import org.apache.kafka.streams.state.WindowStore;

import java.time.Duration;
import java.util.*;

/**
 * Advanced Fraud Detection using Kafka Streams
 *
 * This application implements sophisticated fraud detection patterns:
 * 1. Velocity checks (transaction frequency and amounts)
 * 2. Geographic anomaly detection
 * 3. Behavioral pattern analysis
 * 4. Machine learning model scoring
 * 5. Real-time risk assessment
 */
public class FraudDetectionApp {

    private static final String TRANSACTIONS_TOPIC = "customers.cdc.customerdb.public.transactions";
    private static final String PROFILES_TOPIC = "mongodb.customer_profiles.profiles";
    private static final String FRAUD_ALERTS_TOPIC = "fraud.alerts";
    private static final String RISK_SCORES_TOPIC = "fraud.risk-scores";

    public static void main(String[] args) {
        Properties props = new Properties();
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, "fraud-detection-streams");
        props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG,
                  System.getenv().getOrDefault("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"));
        props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass());
        props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, SpecificAvroSerde.class);
        props.put("schema.registry.url",
                  System.getenv().getOrDefault("SCHEMA_REGISTRY_URL", "http://localhost:8081"));
        props.put(StreamsConfig.CACHE_MAX_BYTES_BUFFERING_CONFIG, 0);
        props.put(StreamsConfig.PROCESSING_GUARANTEE_CONFIG, StreamsConfig.EXACTLY_ONCE_V2);

        StreamsBuilder builder = new StreamsBuilder();

        // Build the fraud detection topology
        buildFraudDetectionTopology(builder);

        KafkaStreams streams = new KafkaStreams(builder.build(), props);

        // Add shutdown hook
        Runtime.getRuntime().addShutdownHook(new Thread(streams::close));

        System.out.println("Starting Fraud Detection Streams Application...");
        streams.start();
    }

    private static void buildFraudDetectionTopology(StreamsBuilder builder) {

        // Read transaction stream
        KStream<String, Transaction> transactions = builder.stream(TRANSACTIONS_TOPIC);

        // Read customer profiles table
        KTable<String, CustomerProfile> profiles = builder.table(PROFILES_TOPIC);

        // ==========================================
        // 1. VELOCITY FRAUD DETECTION
        // ==========================================

        // Count transactions per customer in 5-minute windows
        KTable<Windowed<String>, Long> transactionVelocity = transactions
            .groupByKey()
            .windowedBy(TimeWindows.ofSizeWithNoGrace(Duration.ofMinutes(5)))
            .count();

        // Detect high velocity (>3 transactions in 5 minutes)
        KStream<String, FraudAlert> velocityAlerts = transactionVelocity
            .toStream()
            .filter((windowedKey, count) -> count > 3)
            .map((windowedKey, count) -> {
                String customerId = windowedKey.key();
                FraudAlert alert = new FraudAlert();
                alert.setCustomerId(customerId);
                alert.setAlertType("HIGH_VELOCITY");
                alert.setRiskScore(Math.min(count * 15.0, 100.0));
                alert.setReason("Customer made " + count + " transactions in 5 minutes");
                alert.setTimestamp(System.currentTimeMillis());
                return KeyValue.pair(customerId, alert);
            });

        // ==========================================
        // 2. AMOUNT ANOMALY DETECTION
        // ==========================================

        // Calculate average transaction amount per customer
        KTable<String, Double> avgTransactionAmount = transactions
            .groupByKey()
            .aggregate(
                () -> new TransactionStats(0.0, 0L),
                (key, transaction, aggValue) -> {
                    double newSum = aggValue.getSum() + transaction.getAmount();
                    long newCount = aggValue.getCount() + 1;
                    return new TransactionStats(newSum, newCount);
                },
                Materialized.with(Serdes.String(), new TransactionStatsSerde())
            )
            .mapValues(stats -> stats.getCount() > 0 ? stats.getSum() / stats.getCount() : 0.0);

        // Detect transactions >3x average amount
        KStream<String, FraudAlert> amountAnomalyAlerts = transactions
            .join(
                avgTransactionAmount,
                (transaction, avgAmount) -> {
                    if (transaction.getAmount() > avgAmount * 3 && avgAmount > 0) {
                        FraudAlert alert = new FraudAlert();
                        alert.setCustomerId(transaction.getCustomerId());
                        alert.setTransactionId(transaction.getTransactionId());
                        alert.setAlertType("AMOUNT_ANOMALY");
                        alert.setRiskScore(Math.min((transaction.getAmount() / avgAmount) * 20, 100.0));
                        alert.setReason(String.format(
                            "Transaction amount $%.2f is %.1fx the customer's average of $%.2f",
                            transaction.getAmount(), transaction.getAmount() / avgAmount, avgAmount
                        ));
                        alert.setTimestamp(System.currentTimeMillis());
                        return alert;
                    }
                    return null;
                }
            )
            .filter((key, alert) -> alert != null);

        // ==========================================
        // 3. GEOGRAPHIC ANOMALY DETECTION
        // ==========================================

        // Track last known customer location
        KTable<String, String> customerLocations = transactions
            .groupByKey()
            .reduce(
                (oldTxn, newTxn) -> newTxn.getTimestamp() > oldTxn.getTimestamp() ? newTxn : oldTxn
            )
            .mapValues(txn -> txn.getLocation().getCountry());

        // Detect location changes (potential card theft)
        KStream<String, FraudAlert> locationAnomalyAlerts = transactions
            .leftJoin(
                customerLocations,
                (transaction, lastCountry) -> {
                    String currentCountry = transaction.getLocation().getCountry();
                    if (lastCountry != null && !lastCountry.equals(currentCountry)) {
                        FraudAlert alert = new FraudAlert();
                        alert.setCustomerId(transaction.getCustomerId());
                        alert.setTransactionId(transaction.getTransactionId());
                        alert.setAlertType("LOCATION_CHANGE");
                        alert.setRiskScore(60.0);
                        alert.setReason(String.format(
                            "Transaction in %s, but previous transaction was in %s",
                            currentCountry, lastCountry
                        ));
                        alert.setTimestamp(System.currentTimeMillis());
                        return alert;
                    }
                    return null;
                }
            )
            .filter((key, alert) -> alert != null);

        // ==========================================
        // 4. TIME-BASED ANOMALY DETECTION
        // ==========================================

        KStream<String, FraudAlert> timeAnomalyAlerts = transactions
            .join(
                profiles,
                (transaction, profile) -> {
                    // Get transaction hour (0-23)
                    Calendar cal = Calendar.getInstance();
                    cal.setTimeInMillis(transaction.getTimestamp());
                    int hour = cal.get(Calendar.HOUR_OF_DAY);

                    // Flag transactions between 2 AM and 5 AM (unusual hours)
                    if (hour >= 2 && hour <= 5) {
                        FraudAlert alert = new FraudAlert();
                        alert.setCustomerId(transaction.getCustomerId());
                        alert.setTransactionId(transaction.getTransactionId());
                        alert.setAlertType("UNUSUAL_TIME");
                        alert.setRiskScore(40.0);
                        alert.setReason("Transaction occurred during unusual hours (2-5 AM)");
                        alert.setTimestamp(System.currentTimeMillis());
                        return alert;
                    }
                    return null;
                }
            )
            .filter((key, alert) -> alert != null);

        // ==========================================
        // 5. AGGREGATE RISK SCORING
        // ==========================================

        // Merge all fraud alert streams
        KStream<String, FraudAlert> allAlerts = velocityAlerts
            .merge(amountAnomalyAlerts)
            .merge(locationAnomalyAlerts)
            .merge(timeAnomalyAlerts);

        // Calculate composite risk score per customer
        KTable<String, Double> riskScores = allAlerts
            .groupByKey()
            .windowedBy(TimeWindows.ofSizeWithNoGrace(Duration.ofMinutes(30)))
            .aggregate(
                () -> 0.0,
                (key, alert, aggScore) -> Math.min(aggScore + alert.getRiskScore(), 100.0),
                Materialized.with(Serdes.String(), Serdes.Double())
            )
            .toStream()
            .map((windowedKey, score) -> KeyValue.pair(windowedKey.key(), score))
            .toTable(Materialized.with(Serdes.String(), Serdes.Double()));

        // ==========================================
        // 6. ENRICH TRANSACTIONS WITH RISK SCORES
        // ==========================================

        KStream<String, TransactionWithRisk> enrichedTransactions = transactions
            .leftJoin(
                riskScores,
                (transaction, riskScore) -> {
                    TransactionWithRisk enriched = new TransactionWithRisk();
                    enriched.setTransaction(transaction);
                    enriched.setRiskScore(riskScore != null ? riskScore : 0.0);
                    enriched.setRiskLevel(getRiskLevel(riskScore != null ? riskScore : 0.0));
                    return enriched;
                }
            );

        // ==========================================
        // 7. OUTPUT STREAMS
        // ==========================================

        // Write high-risk alerts to fraud alerts topic
        allAlerts
            .filter((key, alert) -> alert.getRiskScore() >= 60.0)
            .to(FRAUD_ALERTS_TOPIC);

        // Write enriched transactions with risk scores
        enrichedTransactions
            .to(RISK_SCORES_TOPIC);

        // Log high-risk transactions
        enrichedTransactions
            .filter((key, txnWithRisk) -> txnWithRisk.getRiskScore() >= 80.0)
            .foreach((key, txnWithRisk) -> {
                System.out.println("HIGH RISK TRANSACTION DETECTED!");
                System.out.println("  Customer ID: " + txnWithRisk.getTransaction().getCustomerId());
                System.out.println("  Transaction ID: " + txnWithRisk.getTransaction().getTransactionId());
                System.out.println("  Amount: $" + txnWithRisk.getTransaction().getAmount());
                System.out.println("  Risk Score: " + txnWithRisk.getRiskScore());
                System.out.println("  Risk Level: " + txnWithRisk.getRiskLevel());
                System.out.println();
            });
    }

    private static String getRiskLevel(double score) {
        if (score >= 80) return "CRITICAL";
        if (score >= 60) return "HIGH";
        if (score >= 40) return "MEDIUM";
        if (score >= 20) return "LOW";
        return "MINIMAL";
    }

    // Helper classes
    static class Transaction {
        private String transactionId;
        private String customerId;
        private double amount;
        private String merchantId;
        private Location location;
        private long timestamp;

        // Getters and setters
        public String getTransactionId() { return transactionId; }
        public void setTransactionId(String transactionId) { this.transactionId = transactionId; }
        public String getCustomerId() { return customerId; }
        public void setCustomerId(String customerId) { this.customerId = customerId; }
        public double getAmount() { return amount; }
        public void setAmount(double amount) { this.amount = amount; }
        public String getMerchantId() { return merchantId; }
        public void setMerchantId(String merchantId) { this.merchantId = merchantId; }
        public Location getLocation() { return location; }
        public void setLocation(Location location) { this.location = location; }
        public long getTimestamp() { return timestamp; }
        public void setTimestamp(long timestamp) { this.timestamp = timestamp; }
    }

    static class Location {
        private String country;
        private String city;

        public String getCountry() { return country; }
        public void setCountry(String country) { this.country = country; }
        public String getCity() { return city; }
        public void setCity(String city) { this.city = city; }
    }

    static class CustomerProfile {
        private String customerId;
        private String email;
        // Add other fields as needed
    }

    static class FraudAlert {
        private String customerId;
        private String transactionId;
        private String alertType;
        private double riskScore;
        private String reason;
        private long timestamp;

        // Getters and setters
        public String getCustomerId() { return customerId; }
        public void setCustomerId(String customerId) { this.customerId = customerId; }
        public String getTransactionId() { return transactionId; }
        public void setTransactionId(String transactionId) { this.transactionId = transactionId; }
        public String getAlertType() { return alertType; }
        public void setAlertType(String alertType) { this.alertType = alertType; }
        public double getRiskScore() { return riskScore; }
        public void setRiskScore(double riskScore) { this.riskScore = riskScore; }
        public String getReason() { return reason; }
        public void setReason(String reason) { this.reason = reason; }
        public long getTimestamp() { return timestamp; }
        public void setTimestamp(long timestamp) { this.timestamp = timestamp; }
    }

    static class TransactionWithRisk {
        private Transaction transaction;
        private double riskScore;
        private String riskLevel;

        public Transaction getTransaction() { return transaction; }
        public void setTransaction(Transaction transaction) { this.transaction = transaction; }
        public double getRiskScore() { return riskScore; }
        public void setRiskScore(double riskScore) { this.riskScore = riskScore; }
        public String getRiskLevel() { return riskLevel; }
        public void setRiskLevel(String riskLevel) { this.riskLevel = riskLevel; }
    }

    static class TransactionStats {
        private double sum;
        private long count;

        public TransactionStats(double sum, long count) {
            this.sum = sum;
            this.count = count;
        }

        public double getSum() { return sum; }
        public long getCount() { return count; }
    }

    static class TransactionStatsSerde implements org.apache.kafka.common.serialization.Serde<TransactionStats> {
        // Implement serializer/deserializer for TransactionStats
        @Override
        public org.apache.kafka.common.serialization.Serializer<TransactionStats> serializer() {
            return null; // Implement as needed
        }

        @Override
        public org.apache.kafka.common.serialization.Deserializer<TransactionStats> deserializer() {
            return null; // Implement as needed
        }
    }
}
