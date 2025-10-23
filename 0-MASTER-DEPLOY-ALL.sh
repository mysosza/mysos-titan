#!/bin/bash
# Master Deployment Script for Mysos Titan AWS Infrastructure
# This script runs all setup scripts in the correct order

set -e  # Exit on any error

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Mysos Titan AWS Infrastructure Setup                ║"
echo "║                                                              ║"
echo "║  This will create:                                           ║"
echo "║  - VPC and networking                                        ║"
echo "║  - Security groups                                           ║"
echo "║  - RDS MySQL database                                        ║"
echo "║  - ElastiCache Redis                                         ║"
echo "║  - Application Load Balancer                                 ║"
echo "║  - EC2 instances (Laravel + Node.js)                         ║"
echo "║  - CloudWatch monitoring and alarms                          ║"
echo "║                                                              ║"
echo "║  Estimated cost: ~$245/month                                 ║"
echo "║  Deployment time: ~20-30 minutes                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Confirm with user
read -p "Do you want to proceed with the deployment? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Deployment cancelled."
  exit 0
fi

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
  echo "❌ AWS CLI is not installed. Please install it first."
  exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
  echo "❌ AWS CLI is not configured. Please run 'aws configure' first."
  exit 1
fi

echo "✅ AWS CLI is configured"
echo ""

# Create logs directory
mkdir -p deployment-logs

# Function to run a script and log output
run_script() {
  local script=$1
  local description=$2
  local log_file="deployment-logs/$(basename $script .sh)-$(date +%Y%m%d-%H%M%S).log"
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⏳ Step: $description"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  if [ ! -f "$script" ]; then
    echo "❌ Script not found: $script"
    exit 1
  fi
  
  chmod +x "$script"
  
  if bash "$script" 2>&1 | tee "$log_file"; then
    echo "✅ $description completed successfully"
    echo "📝 Log saved to: $log_file"
  else
    echo "❌ $description failed"
    echo "📝 Check log: $log_file"
    exit 1
  fi
}

START_TIME=$(date +%s)

# Run all setup scripts in order
run_script "1-setup-vpc-and-networking.sh" "VPC and Networking Setup"
run_script "2-setup-security-groups.sh" "Security Groups Setup"
run_script "3-setup-rds-database.sh" "RDS Database Setup (5-10 min)"
run_script "4-setup-elasticache-redis.sh" "ElastiCache Redis Setup (3-5 min)"
run_script "5-setup-load-balancer.sh" "Application Load Balancer Setup"
run_script "6-setup-ec2-laravel-instances.sh" "Laravel EC2 Instance Setup"
run_script "7-setup-ec2-nodejs-instances.sh" "Node.js EC2 Instance Setup"
run_script "8-setup-cloudwatch-monitoring.sh" "CloudWatch Monitoring Setup"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  🎉 DEPLOYMENT COMPLETE! 🎉                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Total deployment time: ${MINUTES}m ${SECONDS}s"
echo ""

# Load the environment variables
source aws-resources.env

echo "📋 Deployment Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Network:"
echo "   VPC ID: $VPC_ID"
echo "   Region: $AWS_REGION"
echo ""
echo "🖥️  EC2 Instances:"
echo "   Laravel Server:"
echo "     - Instance ID: $LARAVEL_INSTANCE"
echo "     - Public IP: $LARAVEL_PUBLIC_IP"
echo "     - SSH: ssh -i $KEY_NAME.pem ubuntu@$LARAVEL_PUBLIC_IP"
echo ""
echo "   Node.js Server:"
echo "     - Instance ID: $NODEJS_INSTANCE"
echo "     - Public IP: $NODEJS_PUBLIC_IP"
echo "     - SSH: ssh -i $KEY_NAME.pem ubuntu@$NODEJS_PUBLIC_IP"
echo ""
echo "🗄️  Database:"
echo "   Endpoint: $DB_ENDPOINT"
echo "   Database: $DB_NAME"
echo "   Username: $DB_USERNAME"
echo "   Password: $DB_PASSWORD"
echo "   Connect: mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME"
echo ""
echo "💾 Redis:"
echo "   Endpoint: $REDIS_ENDPOINT:$REDIS_PORT"
echo "   Connect: redis-cli -h $REDIS_ENDPOINT -p $REDIS_PORT"
echo ""
echo "⚖️  Load Balancer:"
echo "   DNS: $ALB_DNS"
echo "   HTTPS Listener: (needs SSL certificate - see next steps)"
echo ""
echo "📊 Monitoring:"
echo "   Dashboard: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=$PROJECT_NAME-dashboard"
echo "   Alerts: $ALERT_EMAIL"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  IMPORTANT: Save these files securely!"
echo "   📄 $KEY_NAME.pem - SSH private key"
echo "   📄 aws-resources.env - All resource IDs and connection info"
echo "   📄 laravel-db-config.txt - Laravel database config"
echo "   📄 laravel-redis-config.txt - Laravel Redis config"
echo ""
echo "📖 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣  Setup SSL Certificates"
echo "   - Request certificate in AWS Certificate Manager for *.mysos.co.za"
echo "   - Add DNS validation records"
echo "   - Create HTTPS listener on ALB"
echo "   See: COMPLETE-DEPLOYMENT-GUIDE.md (Phase 2)"
echo ""
echo "2️⃣  Update DNS Records"
echo "   Point all your domains to: $ALB_DNS"
echo "   - cortex.mysos.co.za -> CNAME -> $ALB_DNS"
echo "   - neo.mysos.co.za -> CNAME -> $ALB_DNS"
echo "   - console.mysos.co.za -> CNAME -> $ALB_DNS"
echo "   - mobile.mysos.co.za -> CNAME -> $ALB_DNS"
echo "   - web.mysos.co.za -> CNAME -> $ALB_DNS"
echo "   - sockets.mysos.co.za -> CNAME -> $ALB_DNS"
echo ""
echo "3️⃣  Migrate Database"
echo "   - Export from current MySQL"
echo "   - Import to: $DB_ENDPOINT"
echo "   Command: mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME < backup.sql"
echo ""
echo "4️⃣  Setup Laravel Apps"
echo "   Option A: Use Forge (Recommended - $19/month)"
echo "     - Add server to Forge: $LARAVEL_PUBLIC_IP"
echo "     - Create sites for each Laravel app"
echo "     - Deploy via Git"
echo "   Option B: Manual deployment"
echo "     - SSH to server and setup Nginx manually"
echo ""
echo "5️⃣  Deploy Node.js Apps"
echo "   - SSH to: $NODEJS_PUBLIC_IP"
echo "   - Copy apps to /opt/panicbuttons/"
echo "   - Configure PM2 ecosystem"
echo "   - Update Redis endpoint to: $REDIS_ENDPOINT:$REDIS_PORT"
echo "   See: nodejs-deployment-guide.md"
echo ""
echo "6️⃣  Setup WordPress on Lightsail"
echo "   - Create Lightsail instance for mysos.co.za"
echo "   - Migrate WordPress site"
echo "   See: 9-wordpress-lightsail-setup-guide.md"
echo ""
echo "7️⃣  Confirm Email for Alerts"
echo "   - Check your email: $ALERT_EMAIL"
echo "   - Confirm SNS subscription"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 Documentation:"
echo "   - COMPLETE-DEPLOYMENT-GUIDE.md - Full deployment walkthrough"
echo "   - AWS-COMMAND-REFERENCE.md - Quick command reference"
echo "   - nodejs-deployment-guide.md - Node.js deployment guide"
echo "   - 9-wordpress-lightsail-setup-guide.md - WordPress setup"
echo ""
echo "💰 Estimated Monthly Cost: ~$245"
echo "   (Well under your $380 budget!)"
echo ""
echo "🎯 Ready to deploy your applications!"
echo ""
echo "Need help? Check COMPLETE-DEPLOYMENT-GUIDE.md for detailed instructions."
echo ""
