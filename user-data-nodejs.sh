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
