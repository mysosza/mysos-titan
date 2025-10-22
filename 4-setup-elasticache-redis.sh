#!/bin/bash
# ElastiCache Redis Setup for mysos-titan
set -e

source aws-resources.env

echo "💾 Creating ElastiCache Redis..."

# Variables
CACHE_CLUSTER_ID="mysos-titan-redis"

# Create Redis Subnet Group
aws elasticache create-cache-subnet-group \
  --region $AWS_REGION \
  --cache-subnet-group-name "$PROJECT_NAME-redis-subnet" \
  --cache-subnet-group-description "Subnet group for mysos Redis" \
  --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2

echo "✅ Redis Subnet Group Created"

# Create Redis Cluster
aws elasticache create-cache-cluster \
  --region $AWS_REGION \
  --cache-cluster-id $CACHE_CLUSTER_ID \
  --cache-node-type cache.t3.micro \
  --engine redis \
  --engine-version 7.1 \
  --num-cache-nodes 1 \
  --cache-subnet-group-name "$PROJECT_NAME-redis-subnet" \
  --security-group-ids $REDIS_SG \
  --preferred-maintenance-window "sun:05:00-sun:06:00" \
  --tags "Key=Name,Value=$PROJECT_NAME-redis"

echo "✅ Redis Cluster Created: $CACHE_CLUSTER_ID"
echo "⏳ Waiting for Redis cluster to become available (this takes 3-5 minutes)..."

# Wait for Redis to be available
aws elasticache wait cache-cluster-available \
  --region $AWS_REGION \
  --cache-cluster-id $CACHE_CLUSTER_ID

# Get Redis endpoint
REDIS_ENDPOINT=$(aws elasticache describe-cache-clusters \
  --region $AWS_REGION \
  --cache-cluster-id $CACHE_CLUSTER_ID \
  --show-cache-node-info \
  --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' \
  --output text)

REDIS_PORT=$(aws elasticache describe-cache-clusters \
  --region $AWS_REGION \
  --cache-cluster-id $CACHE_CLUSTER_ID \
  --show-cache-node-info \
  --query 'CacheClusters[0].CacheNodes[0].Endpoint.Port' \
  --output text)

echo "✅ Redis Cluster Available!"
echo ""
echo "📝 Redis Connection Details:"
echo "Endpoint: $REDIS_ENDPOINT"
echo "Port: $REDIS_PORT"
echo ""

# Save to env file
cat >> aws-resources.env << EOF
export REDIS_ENDPOINT=$REDIS_ENDPOINT
export REDIS_PORT=$REDIS_PORT
EOF

# Create .env snippet for Laravel
cat > laravel-redis-config.txt << EOF
REDIS_HOST=$REDIS_ENDPOINT
REDIS_PASSWORD=null
REDIS_PORT=$REDIS_PORT
REDIS_CLIENT=predis
EOF

echo "✅ Laravel .env redis config saved to laravel-redis-config.txt"
