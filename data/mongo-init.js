// MongoDB Initialization Script for Customer Profiles

// Switch to customer_profiles database
db = db.getSiblingDB('customer_profiles');

// Create profiles collection with validation
db.createCollection('profiles', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['customer_id', 'email', 'name', 'address', 'preferences'],
      properties: {
        customer_id: {
          bsonType: 'string',
          description: 'Customer unique identifier'
        },
        email: {
          bsonType: 'string',
          pattern: '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$',
          description: 'Valid email address'
        },
        phone: {
          bsonType: ['string', 'null'],
          description: 'Customer phone number'
        },
        name: {
          bsonType: 'object',
          required: ['first_name', 'last_name'],
          properties: {
            first_name: { bsonType: 'string' },
            last_name: { bsonType: 'string' }
          }
        },
        address: {
          bsonType: 'object',
          required: ['street', 'city', 'state', 'zip_code', 'country'],
          properties: {
            street: { bsonType: 'string' },
            city: { bsonType: 'string' },
            state: { bsonType: 'string' },
            zip_code: { bsonType: 'string' },
            country: { bsonType: 'string' }
          }
        },
        preferences: {
          bsonType: 'object',
          properties: {
            communication_channel: { bsonType: 'array' },
            product_categories: { bsonType: 'array' },
            notification_enabled: { bsonType: 'bool' }
          }
        },
        segments: {
          bsonType: 'array',
          items: { bsonType: 'string' }
        },
        lifetime_value: {
          bsonType: 'double',
          minimum: 0
        },
        account_created_at: {
          bsonType: 'date'
        },
        last_activity_at: {
          bsonType: 'date'
        },
        churn_risk_score: {
          bsonType: ['double', 'null'],
          minimum: 0,
          maximum: 100
        }
      }
    }
  }
});

// Create indexes
db.profiles.createIndex({ customer_id: 1 }, { unique: true });
db.profiles.createIndex({ email: 1 }, { unique: true });
db.profiles.createIndex({ segments: 1 });
db.profiles.createIndex({ last_activity_at: -1 });

// Insert sample customer profiles
db.profiles.insertMany([
  {
    customer_id: 'CUST001',
    email: 'john.doe@email.com',
    phone: '+1-555-0101',
    name: {
      first_name: 'John',
      last_name: 'Doe'
    },
    address: {
      street: '123 Main St',
      city: 'San Francisco',
      state: 'CA',
      zip_code: '94102',
      country: 'USA'
    },
    preferences: {
      communication_channel: ['email', 'sms'],
      product_categories: ['electronics', 'books', 'sports'],
      notification_enabled: true
    },
    segments: ['VIP', 'ACTIVE', 'TECH_ENTHUSIAST'],
    lifetime_value: 5420.50,
    account_created_at: new Date('2023-01-15'),
    last_activity_at: new Date(),
    churn_risk_score: 15.5
  },
  {
    customer_id: 'CUST002',
    email: 'jane.smith@email.com',
    phone: '+1-555-0102',
    name: {
      first_name: 'Jane',
      last_name: 'Smith'
    },
    address: {
      street: '456 Oak Ave',
      city: 'New York',
      state: 'NY',
      zip_code: '10001',
      country: 'USA'
    },
    preferences: {
      communication_channel: ['email', 'push'],
      product_categories: ['fashion', 'beauty', 'home'],
      notification_enabled: true
    },
    segments: ['HIGH_VALUE', 'FASHION_LOVER'],
    lifetime_value: 3250.75,
    account_created_at: new Date('2023-03-20'),
    last_activity_at: new Date(),
    churn_risk_score: 22.3
  },
  {
    customer_id: 'CUST003',
    email: 'bob.johnson@email.com',
    phone: '+1-555-0103',
    name: {
      first_name: 'Bob',
      last_name: 'Johnson'
    },
    address: {
      street: '789 Pine Rd',
      city: 'Chicago',
      state: 'IL',
      zip_code: '60601',
      country: 'USA'
    },
    preferences: {
      communication_channel: ['email'],
      product_categories: ['electronics', 'automotive', 'tools'],
      notification_enabled: false
    },
    segments: ['ACTIVE', 'DIY_ENTHUSIAST'],
    lifetime_value: 1890.25,
    account_created_at: new Date('2023-06-10'),
    last_activity_at: new Date(),
    churn_risk_score: 35.8
  },
  {
    customer_id: 'CUST004',
    email: 'alice.williams@email.com',
    phone: '+44-20-1234-5678',
    name: {
      first_name: 'Alice',
      last_name: 'Williams'
    },
    address: {
      street: '10 Downing St',
      city: 'London',
      state: 'England',
      zip_code: 'SW1A',
      country: 'UK'
    },
    preferences: {
      communication_channel: ['email', 'sms', 'push'],
      product_categories: ['books', 'food', 'travel'],
      notification_enabled: true
    },
    segments: ['VIP', 'INTERNATIONAL', 'FREQUENT_BUYER'],
    lifetime_value: 7820.00,
    account_created_at: new Date('2022-11-05'),
    last_activity_at: new Date(),
    churn_risk_score: 8.2
  },
  {
    customer_id: 'CUST005',
    email: 'charlie.brown@email.com',
    phone: '+1-555-0105',
    name: {
      first_name: 'Charlie',
      last_name: 'Brown'
    },
    address: {
      street: '321 Elm St',
      city: 'Austin',
      state: 'TX',
      zip_code: '78701',
      country: 'USA'
    },
    preferences: {
      communication_channel: ['push'],
      product_categories: ['entertainment', 'games', 'music'],
      notification_enabled: true
    },
    segments: ['ACTIVE', 'ENTERTAINMENT_FAN'],
    lifetime_value: 950.40,
    account_created_at: new Date('2023-08-22'),
    last_activity_at: new Date(),
    churn_risk_score: 42.1
  },
  {
    customer_id: 'CUST006',
    email: 'diana.prince@email.com',
    phone: '+33-1-2345-6789',
    name: {
      first_name: 'Diana',
      last_name: 'Prince'
    },
    address: {
      street: '25 Champs-Élysées',
      city: 'Paris',
      state: 'Île-de-France',
      zip_code: '75008',
      country: 'France'
    },
    preferences: {
      communication_channel: ['email', 'sms'],
      product_categories: ['fashion', 'luxury', 'travel'],
      notification_enabled: true
    },
    segments: ['VIP', 'LUXURY_SHOPPER', 'INTERNATIONAL'],
    lifetime_value: 12500.00,
    account_created_at: new Date('2022-05-18'),
    last_activity_at: new Date(),
    churn_risk_score: 5.0
  },
  {
    customer_id: 'CUST007',
    email: 'ethan.hunt@email.com',
    phone: '+1-555-0107',
    name: {
      first_name: 'Ethan',
      last_name: 'Hunt'
    },
    address: {
      street: '999 Mission St',
      city: 'Los Angeles',
      state: 'CA',
      zip_code: '90001',
      country: 'USA'
    },
    preferences: {
      communication_channel: ['sms', 'push'],
      product_categories: ['sports', 'outdoor', 'fitness'],
      notification_enabled: true
    },
    segments: ['ACTIVE', 'FITNESS_ENTHUSIAST'],
    lifetime_value: 2100.80,
    account_created_at: new Date('2023-02-28'),
    last_activity_at: new Date(),
    churn_risk_score: 18.7
  },
  {
    customer_id: 'CUST008',
    email: 'fiona.gallagher@email.com',
    phone: '+1-555-0108',
    name: {
      first_name: 'Fiona',
      last_name: 'Gallagher'
    },
    address: {
      street: '555 Lake Shore Dr',
      city: 'Chicago',
      state: 'IL',
      zip_code: '60611',
      country: 'USA'
    },
    preferences: {
      communication_channel: ['email'],
      product_categories: ['home', 'grocery', 'kids'],
      notification_enabled: true
    },
    segments: ['FAMILY_ORIENTED', 'FREQUENT_BUYER'],
    lifetime_value: 4350.60,
    account_created_at: new Date('2022-09-12'),
    last_activity_at: new Date(),
    churn_risk_score: 12.4
  },
  {
    customer_id: 'CUST009',
    email: 'george.lucas@email.com',
    phone: '+49-30-1234-5678',
    name: {
      first_name: 'George',
      last_name: 'Lucas'
    },
    address: {
      street: 'Unter den Linden 77',
      city: 'Berlin',
      state: 'Berlin',
      zip_code: '10117',
      country: 'Germany'
    },
    preferences: {
      communication_channel: ['email', 'push'],
      product_categories: ['movies', 'collectibles', 'tech'],
      notification_enabled: true
    },
    segments: ['VIP', 'COLLECTOR', 'INTERNATIONAL'],
    lifetime_value: 8900.00,
    account_created_at: new Date('2022-07-04'),
    last_activity_at: new Date(),
    churn_risk_score: 9.5
  },
  {
    customer_id: 'CUST010',
    email: 'hannah.montana@email.com',
    phone: '+1-555-0110',
    name: {
      first_name: 'Hannah',
      last_name: 'Montana'
    },
    address: {
      street: '888 Music Row',
      city: 'Nashville',
      state: 'TN',
      zip_code: '37203',
      country: 'USA'
    },
    preferences: {
      communication_channel: ['email', 'sms', 'push'],
      product_categories: ['music', 'entertainment', 'fashion'],
      notification_enabled: true
    },
    segments: ['CELEBRITY', 'HIGH_VALUE', 'INFLUENCER'],
    lifetime_value: 15200.00,
    account_created_at: new Date('2022-01-01'),
    last_activity_at: new Date(),
    churn_risk_score: 3.2
  }
]);

print('Customer profiles initialized successfully!');
print('Total profiles created: ' + db.profiles.countDocuments());

// Initialize replica set for change streams
rs.initiate({
  _id: 'rs0',
  members: [
    { _id: 0, host: 'mongodb:27017' }
  ]
});
