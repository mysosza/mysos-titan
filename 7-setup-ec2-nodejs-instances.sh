#!/bin/bash
# EC2 Node.js TCP Server Setup for mysos-titan
set -e

source aws-resources.env

echo "🚀 Creating EC2 Instance for Node.js TCP Servers..."

# Variables
INSTANCE_TYPE="t3.medium"  # 2 vCPU, 4GB RAM (enough for 10 small Node apps)

# Get latest Ubuntu 22.04 AMI
AMI_ID=$(aws ec2 describe-images \
  --region $AWS_REGION \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

# User Data Script for Node.js Server Setup
cat > user-data-nodejs.sh << 'USERDATA'
#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install PM2 for process management
npm install -g pm2

# Install Redis CLI
apt-get install -y redis-tools

# Create app directory
mkdir -p /opt/panicbuttons
chown -R ubuntu:ubuntu /opt/panicbuttons

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# Setup PM2 to start on boot
env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu

echo "✅ Node.js server setup complete!"
USERDATA

# Launch Node.js EC2 Instance
NODEJS_INSTANCE=$(aws ec2 run-instances \
  --region $AWS_REGION \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $NODEJS_SG \
  --subnet-id $PUBLIC_SUBNET_1 \
  --iam-instance-profile Name=$ROLE_NAME \
  --user-data file://user-data-nodejs.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$PROJECT_NAME-nodejs-1},{Key=Type,Value=nodejs}]" \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":30,\"VolumeType\":\"gp3\"}}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ Node.js Instance Launched: $NODEJS_INSTANCE"
echo "⏳ Waiting for instance to be running..."

# Wait for instance to be running
aws ec2 wait instance-running \
  --region $AWS_REGION \
  --instance-ids $NODEJS_INSTANCE

# Get instance details
NODEJS_PUBLIC_IP=$(aws ec2 describe-instances \
  --region $AWS_REGION \
  --instance-ids $NODEJS_INSTANCE \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

NODEJS_PRIVATE_IP=$(aws ec2 describe-instances \
  --region $AWS_REGION \
  --instance-ids $NODEJS_INSTANCE \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

echo "✅ Instance Running!"
echo ""
echo "📝 Node.js Instance Details:"
echo "Instance ID: $NODEJS_INSTANCE"
echo "Public IP: $NODEJS_PUBLIC_IP"
echo "Private IP: $NODEJS_PRIVATE_IP"
echo ""
echo "SSH: ssh -i $KEY_NAME.pem ubuntu@$NODEJS_PUBLIC_IP"
echo ""

# Save to env file
cat >> aws-resources.env << EOF
export NODEJS_INSTANCE=$NODEJS_INSTANCE
export NODEJS_PUBLIC_IP=$NODEJS_PUBLIC_IP
export NODEJS_PRIVATE_IP=$NODEJS_PRIVATE_IP
EOF

# Create deployment instructions
cat > nodejs-deployment-guide.md << 'GUIDE'
# Node.js Panic Button TCP Server Deployment Guide

## 1. Copy Your Apps to the Server

```bash
# From your local machine
scp -i mysos-titan-key.pem -r ./panicbutton-app-* ubuntu@NODEJS_PUBLIC_IP:/opt/panicbuttons/
```

## 2. SSH into the server

```bash
ssh -i mysos-titan-key.pem ubuntu@NODEJS_PUBLIC_IP
```

## 3. Setup Each App with PM2

```bash
cd /opt/panicbuttons

# Install dependencies for each app
for app in panicbutton-app-*; do
  cd /opt/panicbuttons/$app
  npm install --production
done

# Create PM2 ecosystem file
cat > /opt/panicbuttons/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      name: 'panicbutton-1',
      script: './panicbutton-app-1/server.js',
      instances: 1,
      exec_mode: 'fork',
      env: {
        PORT: 4000,
        REDIS_HOST: 'YOUR_REDIS_ENDPOINT',
        REDIS_PORT: 6379,
        NODE_ENV: 'production'
      }
    },
    {
      name: 'panicbutton-2',
      script: './panicbutton-app-2/server.js',
      instances: 1,
      exec_mode: 'fork',
      env: {
        PORT: 4001,
        REDIS_HOST: 'YOUR_REDIS_ENDPOINT',
        REDIS_PORT: 6379,
        NODE_ENV: 'production'
      }
    },
    // Add remaining 8 apps with ports 4002-4009
  ]
};
EOF

# Start all apps
pm2 start ecosystem.config.js

# Save PM2 process list
pm2 save

# View logs
pm2 logs

# Monitor apps
pm2 monit
```

## 4. Verify Apps are Running

```bash
# Check if apps are listening
netstat -tlnp | grep node

# Test connection
telnet localhost 4000
```

## 5. Configure Auto-restart on Reboot

```bash
pm2 startup
# Follow the instructions from the output
pm2 save
```

## PM2 Useful Commands

```bash
pm2 list                    # List all apps
pm2 restart all             # Restart all apps
pm2 stop all                # Stop all apps
pm2 logs                    # View logs
pm2 logs panicbutton-1      # View specific app logs
pm2 monit                   # Monitor CPU/Memory
pm2 describe panicbutton-1  # Detailed info
```
GUIDE

sed -i "s/NODEJS_PUBLIC_IP/$NODEJS_PUBLIC_IP/g" nodejs-deployment-guide.md

echo ""
echo "🎉 Node.js EC2 Setup Complete!"
echo ""
echo "📖 Deployment guide saved to: nodejs-deployment-guide.md"
echo ""
echo "Next steps:"
echo "1. SSH into instance: ssh -i $KEY_NAME.pem ubuntu@$NODEJS_PUBLIC_IP"
echo "2. Deploy your 10 Node.js TCP apps"
echo "3. Configure PM2 ecosystem for all apps"
echo "4. Update apps to use ElastiCache Redis: $REDIS_ENDPOINT:$REDIS_PORT"
