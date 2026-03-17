#!/bin/bash

# Simple AWS EC2 Deployment - Upload after launch

set -e

echo "=========================================="
echo "🚀 AWS EC2 Dashboard Deployment"
echo "=========================================="
echo ""

REGION="us-east-1"
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-0c7217cdde317cfec"
KEY_NAME="confluent-dash-$(date +%s)"
SG_NAME="confluent-dash-sg-$(date +%s)"

# Step 1: Create Security Group
echo "1️⃣  Creating Security Group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name $SG_NAME \
  --description "Confluent Dashboard" \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 3000 \
  --cidr 0.0.0.0/0 \
  --region $REGION > /dev/null

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  --region $REGION > /dev/null

echo "   ✅ Security Group: $SG_ID"

# Step 2: Create Key Pair
echo ""
echo "2️⃣  Creating SSH Key..."
aws ec2 create-key-pair \
  --key-name $KEY_NAME \
  --region $REGION \
  --query 'KeyMaterial' \
  --output text > /tmp/${KEY_NAME}.pem

chmod 400 /tmp/${KEY_NAME}.pem
echo "   ✅ Key: /tmp/${KEY_NAME}.pem"

# Step 3: Create minimal startup script
cat > /tmp/user-data-simple.sh << 'USERDATA'
#!/bin/bash
apt-get update -y
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
npm install -g pm2
mkdir -p /home/ubuntu/dashboard
chown ubuntu:ubuntu /home/ubuntu/dashboard
USERDATA

# Step 4: Launch Instance
echo ""
echo "3️⃣  Launching EC2 Instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --user-data file:///tmp/user-data-simple.sh \
  --region $REGION \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ConfluentDashboard}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "   ✅ Instance: $INSTANCE_ID"

# Step 5: Wait for running
echo ""
echo "4️⃣  Waiting for instance to start (60s)..."
aws ec2 wait instance-running \
  --instance-ids $INSTANCE_ID \
  --region $REGION

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "   ✅ Public IP: $PUBLIC_IP"

# Step 6: Wait for SSH and system init
echo ""
echo "5️⃣  Waiting for system initialization (90s)..."
sleep 90

# Step 7: Upload dashboard
echo ""
echo "6️⃣  Uploading dashboard code..."
cd /workshop/services/realtime-dashboard
tar czf /tmp/dashboard.tar.gz .

scp -i /tmp/${KEY_NAME}.pem \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  /tmp/dashboard.tar.gz ubuntu@$PUBLIC_IP:/home/ubuntu/ 2>&1 | grep -v "Warning"

echo "   ✅ Code uploaded"

# Step 8: Install and start
echo ""
echo "7️⃣  Installing and starting dashboard..."
ssh -i /tmp/${KEY_NAME}.pem \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  ubuntu@$PUBLIC_IP << 'REMOTE' 2>&1 | grep -v "Warning"
cd /home/ubuntu/dashboard
tar xzf ../dashboard.tar.gz
npm install
cat > .env << 'EOF'
KAFKA_BOOTSTRAP_SERVERS=pkc-619z3.us-east1.gcp.confluent.cloud:9092
KAFKA_SASL_USERNAME=5JR4MWVSUDAMUUDD
KAFKA_SASL_PASSWORD=cfltJECbrAWagtOZ0EMFWE/i0w9q5OyEW822CBdMnCxj7oKMyT+werUWXagehDTQ
KAFKA_SASL_MECHANISM=PLAIN
KAFKA_SECURITY_PROTOCOL=SASL_SSL
EOF
pm2 start server.js --name dashboard
pm2 save
REMOTE

echo "   ✅ Dashboard started"

# Save details
cat > /tmp/dashboard-aws-info.txt << INFO
==========================================
Confluent Dashboard - AWS Deployment
==========================================

Deployed: $(date)

🌐 PUBLIC DASHBOARD URL:
   http://$PUBLIC_IP:3000

Instance Details:
- Instance ID: $INSTANCE_ID
- Public IP: $PUBLIC_IP
- Region: $REGION

SSH Access:
  ssh -i /tmp/${KEY_NAME}.pem ubuntu@$PUBLIC_IP

Management:
- Status: ssh -i /tmp/${KEY_NAME}.pem ubuntu@$PUBLIC_IP 'pm2 status'
- Logs: ssh -i /tmp/${KEY_NAME}.pem ubuntu@$PUBLIC_IP 'pm2 logs dashboard'
- Restart: ssh -i /tmp/${KEY_NAME}.pem ubuntu@$PUBLIC_IP 'pm2 restart dashboard'

To Delete:
  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION

Cost: ~\$0.01/hour (Free tier: 750 hours/month free)
==========================================
INFO

echo ""
echo "=========================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "🌐 Your dashboard is publicly accessible at:"
echo ""
echo "   http://$PUBLIC_IP:3000"
echo ""
echo "Share this URL with anyone!"
echo ""
echo "📄 Details saved to: /tmp/dashboard-aws-info.txt"
echo ""
echo "=========================================="

# Test if dashboard is up
sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$PUBLIC_IP:3000 || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  echo ""
  echo "🎉 Dashboard is LIVE and responding!"
  echo ""
else
  echo ""
  echo "⏳ Dashboard is starting up (give it 30 seconds)"
  echo "   Check: http://$PUBLIC_IP:3000"
  echo ""
fi

cat /tmp/dashboard-aws-info.txt
