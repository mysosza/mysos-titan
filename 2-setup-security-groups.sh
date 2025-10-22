#!/bin/bash
# Security Groups Setup for mysos-titan
set -e

source aws-resources.env

echo "🔒 Creating Security Groups..."

# ALB Security Group
ALB_SG=$(aws ec2 create-security-group \
  --region $AWS_REGION \
  --group-name "$PROJECT_NAME-alb-sg" \
  --description "Security group for Application Load Balancer" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$PROJECT_NAME-alb-sg}]" \
  --query 'GroupId' \
  --output text)

# Allow HTTP and HTTPS from anywhere
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $ALB_SG \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $ALB_SG \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

echo "✅ ALB Security Group Created: $ALB_SG"

# Laravel EC2 Security Group
LARAVEL_SG=$(aws ec2 create-security-group \
  --region $AWS_REGION \
  --group-name "$PROJECT_NAME-laravel-sg" \
  --description "Security group for Laravel EC2 instances" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$PROJECT_NAME-laravel-sg}]" \
  --query 'GroupId' \
  --output text)

# Allow HTTP from ALB
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $LARAVEL_SG \
  --protocol tcp \
  --port 80 \
  --source-group $ALB_SG

# Allow SSH (we can restrict this to our IP later)
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $LARAVEL_SG \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

echo "✅ Laravel Security Group Created: $LARAVEL_SG"

# Node.js TCP Security Group
NODEJS_SG=$(aws ec2 create-security-group \
  --region $AWS_REGION \
  --group-name "$PROJECT_NAME-nodejs-sg" \
  --description "Security group for Node.js TCP servers" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$PROJECT_NAME-nodejs-sg}]" \
  --query 'GroupId' \
  --output text)

# Allow TCP connections on panic button ports (let's say 4000-4010)
for PORT in {4000..4010}; do
  aws ec2 authorize-security-group-ingress \
    --region $AWS_REGION \
    --group-id $NODEJS_SG \
    --protocol tcp \
    --port $PORT \
    --cidr 0.0.0.0/0 2>/dev/null || true
done

# Allow from Laravel instances
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $NODEJS_SG \
  --protocol tcp \
  --port 4000-4010 \
  --source-group $LARAVEL_SG

# Allow SSH
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $NODEJS_SG \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

echo "✅ Node.js Security Group Created: $NODEJS_SG"

# RDS Security Group
RDS_SG=$(aws ec2 create-security-group \
  --region $AWS_REGION \
  --group-name "$PROJECT_NAME-rds-sg" \
  --description "Security group for RDS MySQL" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$PROJECT_NAME-rds-sg}]" \
  --query 'GroupId' \
  --output text)

# Allow MySQL from Laravel instances
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 3306 \
  --source-group $LARAVEL_SG

# Allow MySQL from Node.js instances
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 3306 \
  --source-group $NODEJS_SG

echo "✅ RDS Security Group Created: $RDS_SG"

# Redis Security Group
REDIS_SG=$(aws ec2 create-security-group \
  --region $AWS_REGION \
  --group-name "$PROJECT_NAME-redis-sg" \
  --description "Security group for ElastiCache Redis" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$PROJECT_NAME-redis-sg}]" \
  --query 'GroupId' \
  --output text)

# Allow Redis from Laravel instances
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $REDIS_SG \
  --protocol tcp \
  --port 6379 \
  --source-group $LARAVEL_SG

# Allow Redis from Node.js instances
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $REDIS_SG \
  --protocol tcp \
  --port 6379 \
  --source-group $NODEJS_SG

echo "✅ Redis Security Group Created: $REDIS_SG"

# WebSocket Security Group
WEBSOCKET_SG=$(aws ec2 create-security-group \
  --region $AWS_REGION \
  --group-name "$PROJECT_NAME-websocket-sg" \
  --description "Security group for WebSocket server" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$PROJECT_NAME-websocket-sg}]" \
  --query 'GroupId' \
  --output text)

# Allow WebSocket from ALB
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $WEBSOCKET_SG \
  --protocol tcp \
  --port 6001 \
  --source-group $ALB_SG

# Allow direct WebSocket connections (if needed)
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $WEBSOCKET_SG \
  --protocol tcp \
  --port 6001 \
  --cidr 0.0.0.0/0

# Allow SSH
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $WEBSOCKET_SG \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

echo "✅ WebSocket Security Group Created: $WEBSOCKET_SG"

# Append to env file
cat >> aws-resources.env << EOF
export ALB_SG=$ALB_SG
export LARAVEL_SG=$LARAVEL_SG
export NODEJS_SG=$NODEJS_SG
export RDS_SG=$RDS_SG
export REDIS_SG=$REDIS_SG
export WEBSOCKET_SG=$WEBSOCKET_SG
export PROJECT_NAME=mysos-titan
EOF

echo ""
echo "🎉 Security Groups Created!"
echo "ALB SG: $ALB_SG"
echo "Laravel SG: $LARAVEL_SG"
echo "Node.js SG: $NODEJS_SG"
echo "RDS SG: $RDS_SG"
echo "Redis SG: $REDIS_SG"
echo "WebSocket SG: $WEBSOCKET_SG"
