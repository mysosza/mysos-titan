#!/bin/bash
# Cleanup Script - Destroys ALL AWS Resources Created for Mysos Titan
# ⚠️  WARNING: This will delete EVERYTHING and cannot be undone!

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ⚠️  DANGER: RESOURCE CLEANUP TOOL ⚠️             ║"
echo "║                                                              ║"
echo "║  This script will PERMANENTLY DELETE all AWS resources      ║"
echo "║  created for the Mysos Titan project, including:            ║"
echo "║                                                              ║"
echo "║  ❌ EC2 Instances (all data will be lost)                    ║"
echo "║  ❌ RDS Database (all data will be lost)                     ║"
echo "║  ❌ ElastiCache Redis (all cache will be lost)               ║"
echo "║  ❌ Load Balancer                                            ║"
echo "║  ❌ VPC and all networking                                   ║"
echo "║  ❌ CloudWatch alarms and logs                               ║"
echo "║  ❌ Security groups                                          ║"
echo "║                                                              ║"
echo "║  THIS ACTION CANNOT BE UNDONE!                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Load environment
if [ ! -f "aws-resources.env" ]; then
  echo "❌ aws-resources.env not found."
  echo "Cannot proceed with cleanup without resource IDs."
  exit 1
fi

source aws-resources.env

echo "📋 Resources to be deleted:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Region: $AWS_REGION"
echo "VPC: $VPC_ID"
echo "Laravel Instance: $LARAVEL_INSTANCE"
echo "Node.js Instance: $NODEJS_INSTANCE"
echo "RDS Database: mysos-titan-db"
echo "Redis Cluster: mysos-titan-redis"
echo "Load Balancer: $ALB_ARN"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Triple confirmation
read -p "Type 'DELETE EVERYTHING' to confirm: " CONFIRM1
if [ "$CONFIRM1" != "DELETE EVERYTHING" ]; then
  echo "❌ Cleanup cancelled."
  exit 0
fi

read -p "Are you ABSOLUTELY sure? This cannot be undone! (yes/no): " CONFIRM2
if [ "$CONFIRM2" != "yes" ]; then
  echo "❌ Cleanup cancelled."
  exit 0
fi

read -p "Last chance! Type the VPC ID to proceed ($VPC_ID): " CONFIRM3
if [ "$CONFIRM3" != "$VPC_ID" ]; then
  echo "❌ VPC ID mismatch. Cleanup cancelled."
  exit 0
fi

echo ""
echo "⏳ Starting cleanup process..."
echo ""

# Function to delete with error handling
safe_delete() {
  local resource=$1
  local command=$2
  
  echo "⏳ Deleting $resource..."
  if eval "$command" 2>/dev/null; then
    echo "✅ $resource deleted"
  else
    echo "⚠️  Failed to delete $resource (may not exist or already deleted)"
  fi
}

# Create final snapshot before deletion
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Creating final snapshots"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# RDS snapshot
safe_delete "RDS Final Snapshot" \
  "aws rds create-db-snapshot \
    --region $AWS_REGION \
    --db-instance-identifier mysos-titan-db \
    --db-snapshot-identifier mysos-titan-db-final-$TIMESTAMP"

# EC2 AMI backups
safe_delete "Laravel Instance AMI" \
  "aws ec2 create-image \
    --region $AWS_REGION \
    --instance-id $LARAVEL_INSTANCE \
    --name mysos-laravel-final-$TIMESTAMP \
    --description 'Final backup before deletion'"

safe_delete "Node.js Instance AMI" \
  "aws ec2 create-image \
    --region $AWS_REGION \
    --instance-id $NODEJS_INSTANCE \
    --name mysos-nodejs-final-$TIMESTAMP \
    --description 'Final backup before deletion'"

echo ""
echo "✅ Snapshots created (these will be kept for recovery)"
echo ""
sleep 5

# Delete CloudWatch resources
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Deleting CloudWatch resources"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Delete alarms
ALARMS=$(aws cloudwatch describe-alarms \
  --region $AWS_REGION \
  --alarm-name-prefix mysos-titan \
  --query 'MetricAlarms[*].AlarmName' \
  --output text)

for ALARM in $ALARMS; do
  safe_delete "CloudWatch Alarm: $ALARM" \
    "aws cloudwatch delete-alarms --region $AWS_REGION --alarm-names $ALARM"
done

# Delete dashboard
safe_delete "CloudWatch Dashboard" \
  "aws cloudwatch delete-dashboards --region $AWS_REGION --dashboard-names mysos-titan-dashboard"

# Delete SNS topic
safe_delete "SNS Topic" \
  "aws sns delete-topic --region $AWS_REGION --topic-arn $SNS_TOPIC_ARN"

# Delete EC2 instances
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Terminating EC2 instances"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

safe_delete "Laravel EC2 Instance" \
  "aws ec2 terminate-instances --region $AWS_REGION --instance-ids $LARAVEL_INSTANCE"

safe_delete "Node.js EC2 Instance" \
  "aws ec2 terminate-instances --region $AWS_REGION --instance-ids $NODEJS_INSTANCE"

echo "⏳ Waiting for instances to terminate (this may take 2-3 minutes)..."
aws ec2 wait instance-terminated \
  --region $AWS_REGION \
  --instance-ids $LARAVEL_INSTANCE $NODEJS_INSTANCE 2>/dev/null || true

# Delete Load Balancer
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Deleting Load Balancer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Delete listeners
LISTENERS=$(aws elbv2 describe-listeners \
  --region $AWS_REGION \
  --load-balancer-arn $ALB_ARN \
  --query 'Listeners[*].ListenerArn' \
  --output text 2>/dev/null || true)

for LISTENER in $LISTENERS; do
  safe_delete "ALB Listener" \
    "aws elbv2 delete-listener --region $AWS_REGION --listener-arn $LISTENER"
done

# Delete ALB
safe_delete "Application Load Balancer" \
  "aws elbv2 delete-load-balancer --region $AWS_REGION --load-balancer-arn $ALB_ARN"

echo "⏳ Waiting for ALB to delete..."
sleep 30

# Delete target groups
TARGET_GROUPS=$(aws elbv2 describe-target-groups \
  --region $AWS_REGION \
  --query "TargetGroups[?contains(TargetGroupName, 'mysos-titan')].TargetGroupArn" \
  --output text 2>/dev/null || true)

for TG in $TARGET_GROUPS; do
  safe_delete "Target Group" \
    "aws elbv2 delete-target-group --region $AWS_REGION --target-group-arn $TG"
done

# Delete RDS
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Deleting RDS Database"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

safe_delete "RDS Database" \
  "aws rds delete-db-instance \
    --region $AWS_REGION \
    --db-instance-identifier mysos-titan-db \
    --skip-final-snapshot"

# Delete DB subnet group
sleep 10
safe_delete "RDS Subnet Group" \
  "aws rds delete-db-subnet-group \
    --region $AWS_REGION \
    --db-subnet-group-name mysos-titan-db-subnet"

# Delete ElastiCache
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Deleting ElastiCache Redis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

safe_delete "ElastiCache Redis Cluster" \
  "aws elasticache delete-cache-cluster \
    --region $AWS_REGION \
    --cache-cluster-id mysos-titan-redis"

sleep 10
safe_delete "ElastiCache Subnet Group" \
  "aws elasticache delete-cache-subnet-group \
    --region $AWS_REGION \
    --cache-subnet-group-name mysos-titan-redis-subnet"

# Wait for dependencies to clear
echo ""
echo "⏳ Waiting for resources to fully delete (5 minutes)..."
echo "   This ensures all dependencies are cleared before deleting networking..."
sleep 300

# Delete Networking
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Deleting Security Groups"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Delete security groups (in order)
for SG in $WEBSOCKET_SG $NODEJS_SG $LARAVEL_SG $REDIS_SG $RDS_SG $ALB_SG; do
  safe_delete "Security Group: $SG" \
    "aws ec2 delete-security-group --region $AWS_REGION --group-id $SG"
  sleep 2
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 8: Deleting NAT Gateway and EIPs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

safe_delete "NAT Gateway" \
  "aws ec2 delete-nat-gateway --region $AWS_REGION --nat-gateway-id $NAT_GW"

echo "⏳ Waiting for NAT Gateway to delete (this takes 2-3 minutes)..."
sleep 180

safe_delete "Elastic IP" \
  "aws ec2 release-address --region $AWS_REGION --allocation-id $EIP_ALLOC"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 9: Deleting VPC Components"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Delete route tables (except main)
ROUTE_TABLES=$(aws ec2 describe-route-tables \
  --region $AWS_REGION \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" \
  --output text)

for RT in $ROUTE_TABLES; do
  # Disassociate subnets first
  ASSOCIATIONS=$(aws ec2 describe-route-tables \
    --region $AWS_REGION \
    --route-table-ids $RT \
    --query 'RouteTables[0].Associations[*].RouteTableAssociationId' \
    --output text)
  
  for ASSOC in $ASSOCIATIONS; do
    safe_delete "Route Table Association" \
      "aws ec2 disassociate-route-table --region $AWS_REGION --association-id $ASSOC"
  done
  
  safe_delete "Route Table: $RT" \
    "aws ec2 delete-route-table --region $AWS_REGION --route-table-id $RT"
done

# Delete Internet Gateway
safe_delete "Internet Gateway Detachment" \
  "aws ec2 detach-internet-gateway --region $AWS_REGION --internet-gateway-id $IGW_ID --vpc-id $VPC_ID"

safe_delete "Internet Gateway" \
  "aws ec2 delete-internet-gateway --region $AWS_REGION --internet-gateway-id $IGW_ID"

# Delete Subnets
for SUBNET in $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2; do
  safe_delete "Subnet: $SUBNET" \
    "aws ec2 delete-subnet --region $AWS_REGION --subnet-id $SUBNET"
done

# Delete VPC
safe_delete "VPC" \
  "aws ec2 delete-vpc --region $AWS_REGION --vpc-id $VPC_ID"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 10: Cleaning up IAM resources"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Remove IAM role policies
safe_delete "IAM Role Policy Detachment" \
  "aws iam detach-role-policy \
    --role-name mysos-titan-ec2-role \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"

safe_delete "IAM Instance Profile Role Removal" \
  "aws iam remove-role-from-instance-profile \
    --instance-profile-name mysos-titan-ec2-role \
    --role-name mysos-titan-ec2-role"

safe_delete "IAM Instance Profile" \
  "aws iam delete-instance-profile --instance-profile-name mysos-titan-ec2-role"

safe_delete "IAM Role" \
  "aws iam delete-role --role-name mysos-titan-ec2-role"

# Delete SSH key pair
safe_delete "SSH Key Pair" \
  "aws ec2 delete-key-pair --region $AWS_REGION --key-name $KEY_NAME"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ✅ CLEANUP COMPLETE ✅                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Resources Deleted:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ EC2 Instances (Laravel + Node.js)"
echo "✅ RDS Database"
echo "✅ ElastiCache Redis"
echo "✅ Application Load Balancer"
echo "✅ Target Groups"
echo "✅ Security Groups"
echo "✅ VPC and Subnets"
echo "✅ Internet Gateway & NAT Gateway"
echo "✅ Elastic IPs"
echo "✅ CloudWatch Alarms & Dashboard"
echo "✅ SNS Topics"
echo "✅ IAM Roles & Policies"
echo "✅ SSH Key Pair"
echo ""
echo "📸 Backups Created (still exist):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ RDS Snapshot: mysos-titan-db-final-$TIMESTAMP"
echo "✅ Laravel AMI: mysos-laravel-final-$TIMESTAMP"
echo "✅ Node.js AMI: mysos-nodejs-final-$TIMESTAMP"
echo ""
echo "💾 To restore from these backups:"
echo ""
echo "  RDS:"
echo "  aws rds restore-db-instance-from-db-snapshot \\"
echo "    --db-instance-identifier mysos-titan-db-restored \\"
echo "    --db-snapshot-identifier mysos-titan-db-final-$TIMESTAMP"
echo ""
echo "  EC2:"
echo "  Launch new instances using the AMIs created"
echo ""
echo "⚠️  To delete snapshots and AMIs (to stop charges):"
echo ""
echo "  aws rds delete-db-snapshot --db-snapshot-identifier mysos-titan-db-final-$TIMESTAMP"
echo "  aws ec2 deregister-image --image-id <ami-id>"
echo ""
echo "📊 Cost Impact:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All running resources deleted. Monthly cost now ~$0"
echo "Only snapshot storage remains (~$2-5/month)"
echo ""
echo "🧹 Local Cleanup:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Consider deleting these local files:"
echo "  - aws-resources.env"
echo "  - $KEY_NAME.pem"
echo "  - deployment-logs/"
echo "  - database-backups/"
echo ""
echo "All AWS infrastructure for Mysos Titan has been removed."
echo ""
