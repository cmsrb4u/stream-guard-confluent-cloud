-- Customer Experience Intelligence Platform
-- PostgreSQL Initialization Script

-- Create customers table
CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    address_street VARCHAR(255),
    address_city VARCHAR(100),
    address_state VARCHAR(50),
    address_zip VARCHAR(20),
    address_country VARCHAR(50),
    account_created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) REFERENCES customers(customer_id),
    amount DECIMAL(12, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    merchant_id VARCHAR(50) NOT NULL,
    merchant_category VARCHAR(50) NOT NULL,
    location_country VARCHAR(50) NOT NULL,
    location_city VARCHAR(100) NOT NULL,
    location_latitude DECIMAL(10, 8),
    location_longitude DECIMAL(11, 8),
    payment_method VARCHAR(50) NOT NULL,
    device_id VARCHAR(100),
    device_type VARCHAR(50),
    ip_address VARCHAR(45),
    user_agent TEXT,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'PENDING',
    risk_score DECIMAL(5, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) REFERENCES customers(customer_id),
    transaction_id VARCHAR(50) REFERENCES transactions(transaction_id),
    order_status VARCHAR(50) DEFAULT 'PENDING',
    total_amount DECIMAL(12, 2) NOT NULL,
    items_count INT NOT NULL,
    shipping_address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX idx_transactions_customer_id ON transactions(customer_id);
CREATE INDEX idx_transactions_timestamp ON transactions(timestamp);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);

-- Insert sample customers
INSERT INTO customers (customer_id, email, phone, first_name, last_name, address_street, address_city, address_state, address_zip, address_country) VALUES
('CUST001', 'john.doe@email.com', '+1-555-0101', 'John', 'Doe', '123 Main St', 'San Francisco', 'CA', '94102', 'USA'),
('CUST002', 'jane.smith@email.com', '+1-555-0102', 'Jane', 'Smith', '456 Oak Ave', 'New York', 'NY', '10001', 'USA'),
('CUST003', 'bob.johnson@email.com', '+1-555-0103', 'Bob', 'Johnson', '789 Pine Rd', 'Chicago', 'IL', '60601', 'USA'),
('CUST004', 'alice.williams@email.com', '+44-20-1234-5678', 'Alice', 'Williams', '10 Downing St', 'London', 'England', 'SW1A', 'UK'),
('CUST005', 'charlie.brown@email.com', '+1-555-0105', 'Charlie', 'Brown', '321 Elm St', 'Austin', 'TX', '78701', 'USA'),
('CUST006', 'diana.prince@email.com', '+33-1-2345-6789', 'Diana', 'Prince', '25 Champs-Élysées', 'Paris', 'Île-de-France', '75008', 'France'),
('CUST007', 'ethan.hunt@email.com', '+1-555-0107', 'Ethan', 'Hunt', '999 Mission St', 'Los Angeles', 'CA', '90001', 'USA'),
('CUST008', 'fiona.gallagher@email.com', '+1-555-0108', 'Fiona', 'Gallagher', '555 Lake Shore Dr', 'Chicago', 'IL', '60611', 'USA'),
('CUST009', 'george.lucas@email.com', '+49-30-1234-5678', 'George', 'Lucas', 'Unter den Linden 77', 'Berlin', 'Berlin', '10117', 'Germany'),
('CUST010', 'hannah.montana@email.com', '+1-555-0110', 'Hannah', 'Montana', '888 Music Row', 'Nashville', 'TN', '37203', 'USA')
ON CONFLICT (customer_id) DO NOTHING;

-- Insert sample transactions
INSERT INTO transactions (transaction_id, customer_id, amount, merchant_id, merchant_category, location_country, location_city, payment_method, device_id, device_type, ip_address, timestamp, status) VALUES
('TXN001', 'CUST001', 49.99, 'MERCH_RETAIL_001', 'RETAIL', 'USA', 'San Francisco', 'CREDIT_CARD', 'DEV001', 'mobile', '192.168.1.1', NOW() - INTERVAL '1 hour', 'APPROVED'),
('TXN002', 'CUST001', 125.50, 'MERCH_FOOD_001', 'FOOD', 'USA', 'San Francisco', 'CREDIT_CARD', 'DEV001', 'mobile', '192.168.1.1', NOW() - INTERVAL '45 minutes', 'APPROVED'),
('TXN003', 'CUST002', 299.99, 'MERCH_ONLINE_001', 'ONLINE', 'USA', 'New York', 'DIGITAL_WALLET', 'DEV002', 'desktop', '10.0.0.1', NOW() - INTERVAL '30 minutes', 'APPROVED'),
('TXN004', 'CUST003', 1599.00, 'MERCH_RETAIL_002', 'RETAIL', 'USA', 'Chicago', 'CREDIT_CARD', 'DEV003', 'mobile', '172.16.0.1', NOW() - INTERVAL '20 minutes', 'APPROVED'),
('TXN005', 'CUST004', 75.20, 'MERCH_FOOD_002', 'FOOD', 'UK', 'London', 'DEBIT_CARD', 'DEV004', 'mobile', '192.168.2.1', NOW() - INTERVAL '15 minutes', 'APPROVED'),
('TXN006', 'CUST001', 5500.00, 'MERCH_ONLINE_002', 'ONLINE', 'USA', 'San Francisco', 'CREDIT_CARD', 'DEV001', 'mobile', '192.168.1.1', NOW() - INTERVAL '10 minutes', 'FLAGGED'),
('TXN007', 'CUST005', 89.99, 'MERCH_ENTERTAINMENT_001', 'ENTERTAINMENT', 'USA', 'Austin', 'DIGITAL_WALLET', 'DEV005', 'mobile', '192.168.3.1', NOW() - INTERVAL '8 minutes', 'APPROVED'),
('TXN008', 'CUST006', 450.00, 'MERCH_TRAVEL_001', 'TRAVEL', 'France', 'Paris', 'CREDIT_CARD', 'DEV006', 'desktop', '192.168.4.1', NOW() - INTERVAL '5 minutes', 'APPROVED'),
('TXN009', 'CUST007', 199.99, 'MERCH_RETAIL_003', 'RETAIL', 'USA', 'Los Angeles', 'CREDIT_CARD', 'DEV007', 'mobile', '192.168.5.1', NOW() - INTERVAL '3 minutes', 'APPROVED'),
('TXN010', 'CUST008', 32.50, 'MERCH_FOOD_003', 'FOOD', 'USA', 'Chicago', 'DEBIT_CARD', 'DEV008', 'mobile', '192.168.6.1', NOW() - INTERVAL '1 minute', 'APPROVED')
ON CONFLICT (transaction_id) DO NOTHING;

-- Insert sample orders
INSERT INTO orders (order_id, customer_id, transaction_id, order_status, total_amount, items_count, shipping_address) VALUES
('ORD001', 'CUST001', 'TXN001', 'SHIPPED', 49.99, 2, '123 Main St, San Francisco, CA 94102'),
('ORD002', 'CUST002', 'TXN003', 'PROCESSING', 299.99, 1, '456 Oak Ave, New York, NY 10001'),
('ORD003', 'CUST003', 'TXN004', 'DELIVERED', 1599.00, 1, '789 Pine Rd, Chicago, IL 60601'),
('ORD004', 'CUST007', 'TXN009', 'PENDING', 199.99, 3, '999 Mission St, Los Angeles, CA 90001')
ON CONFLICT (order_id) DO NOTHING;

-- Enable logical replication for CDC
ALTER SYSTEM SET wal_level = logical;

-- Create publication for Debezium
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'dbz_publication') THEN
        CREATE PUBLICATION dbz_publication FOR ALL TABLES;
    END IF;
END $$;

-- Grant necessary permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO postgres;

-- Create a function to update last_updated_at
CREATE OR REPLACE FUNCTION update_last_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic timestamp updates
CREATE TRIGGER update_customers_timestamp
    BEFORE UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION update_last_updated_at();

CREATE TRIGGER update_orders_timestamp
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_last_updated_at();
