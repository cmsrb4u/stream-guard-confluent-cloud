# 🌐 Public Dashboard URLs

## Access Your Dashboard

### DNS Name (Recommended):
```
http://ec2-3-85-51-5.compute-1.amazonaws.com:3000
```

### IP Address (Also works):
```
http://3.85.51.5:3000
```

**Both URLs point to the same dashboard!**

---

## 📊 What You Should See Now

I just generated:
- **45 transactions** (35 normal + 10 fraud)
- **8 FRAUD ALERTS** worth ~$60,000
- **150+ clickstream events**

### Refresh the page and you should see:

**1. Statistics Panel**
- Total Transactions: 45+
- Fraud Alerts: 8+
- Fraud Rate: ~18%
- Total Revenue: $15,000+

**2. Transaction Stream**
- Recent transactions scrolling
- Mix of normal and fraud

**3. Fraud Alerts Panel** (RED PULSING)
- 8+ high-risk transactions
- Risk scores: 90
- Countries: Russia, China, Nigeria
- Amounts: $5,500 - $9,200 each

**4. Customer Behavior**
- 150+ clickstream events
- Page views, clicks, add to cart

**5. Charts**
- Transaction volume graph
- Fraud detection pie chart

---

## 🎬 For Live Demo

### Keep This URL Open:
```
http://ec2-3-85-51-5.compute-1.amazonaws.com:3000
```

### Generate Fraud During Demo:

**From your terminal, run**:
```bash
curl -X POST http://localhost:3001/api/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "DEMO_USER",
    "amount": 9999.00,
    "merchant_category": "ONLINE",
    "location": {"country": "Russia", "city": "Moscow"}
  }'
```

**Then tell audience**: "Watch the dashboard - that fraud just got detected!"

They'll see the RED ALERT appear in real-time on the public dashboard!

---

## 🔄 If Dashboard Looks Empty

Run this command to populate it:
```bash
# Generate 10 transactions + 3 frauds
for i in {1..10}; do
  curl -s -X POST http://localhost:3001/api/transactions \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\":\"CUST00$i\",\"amount\":$((RANDOM % 500 + 100)).00,\"merchant_category\":\"RETAIL\",\"location\":{\"country\":\"USA\"}}" > /dev/null
done

# Generate fraud
for country in "Russia" "China" "Nigeria"; do
  curl -s -X POST http://localhost:3001/api/transactions \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\":\"CUST999\",\"amount\":$((RANDOM % 3000 + 6000)).00,\"merchant_category\":\"ONLINE\",\"location\":{\"country\":\"$country\"}}" > /dev/null
  sleep 1
done

# Generate clickstream
curl -s -X POST http://localhost:3001/api/demo/generate-events -d '{"count":50}' > /dev/null

echo "Done! Refresh dashboard in 5 seconds"
```

---

## 📱 Share These URLs

**For judges/audience**:
- DNS: http://ec2-3-85-51-5.compute-1.amazonaws.com:3000
- IP: http://3.85.51.5:3000

**For documentation**:
```markdown
Live Demo: http://ec2-3-85-51-5.compute-1.amazonaws.com:3000
```

---

## 🛠️ Troubleshooting

**If you see only 4 transactions**:
- Dashboard consumers start from "latest" offset
- Only new data after dashboard started appears
- Solution: Generate more transactions (see command above)

**If fraud alerts show 0**:
- Need to generate high-value transactions from suspicious locations
- Solution: Run fraud generation commands above

**To check dashboard is running**:
```bash
ssh -i /tmp/confluent-dash-1773786566.pem ubuntu@3.85.51.5 'pm2 status'
```

**To see live logs**:
```bash
ssh -i /tmp/confluent-dash-1773786566.pem ubuntu@3.85.51.5 'pm2 logs dashboard'
```

---

## ✨ Summary

**Your Dashboard**:
- ✅ Deployed on AWS EC2
- ✅ Publicly accessible (no VPN needed)
- ✅ Connected to Confluent Cloud
- ✅ Real-time fraud detection active
- ✅ WebSocket live updates working

**URLs to use**:
- **Primary**: http://ec2-3-85-51-5.compute-1.amazonaws.com:3000
- **Backup**: http://3.85.51.5:3000

**Current Data**:
- 45+ transactions
- 8+ fraud alerts detected
- 150+ clickstream events
- ~$60,000 fraud prevented

**Refresh the page now to see all the activity!** 🎉
