#!/bin/bash
# AWS VPC and Networking Setup for mysos-titan
set -e

echo "🚀 Creating VPC and networking infrastructure..."

# Variables
REGION="af-south-1"  # Change to our preferred region (e.g., us-east-1, eu-west-1)
VPC_CIDR="10.0.0.0/16"
PROJECT_NAME="mysos-titan"

# Create VPC
VPC_ID=$(aws ec2 create-vpc \
  --region $REGION \
  --cidr-block $VPC_CIDR \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$PROJECT_NAME-vpc}]" \
  --query 'Vpc.VpcId' \
  --output text)

echo "✅ VPC Created: $VPC_ID"

# Enable DNS hostnames
aws ec2 modify-vpc-attribute \
  --region $REGION \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --region $REGION \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$PROJECT_NAME-igw}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

echo "✅ Internet Gateway Created: $IGW_ID"

# Attach IGW to VPC
aws ec2 attach-internet-gateway \
  --region $REGION \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID

# Create Public Subnets (2 AZs for HA)
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
  --region $REGION \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ${REGION}a \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$PROJECT_NAME-public-1a}]" \
  --query 'Subnet.SubnetId' \
  --output text)

PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
  --region $REGION \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone ${REGION}b \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$PROJECT_NAME-public-1b}]" \
  --query 'Subnet.SubnetId' \
  --output text)

echo "✅ Public Subnets Created: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"

# Create Private Subnets
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
  --region $REGION \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.11.0/24 \
  --availability-zone ${REGION}a \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$PROJECT_NAME-private-1a}]" \
  --query 'Subnet.SubnetId' \
  --output text)

PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
  --region $REGION \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.12.0/24 \
  --availability-zone ${REGION}b \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$PROJECT_NAME-private-1b}]" \
  --query 'Subnet.SubnetId' \
  --output text)

echo "✅ Private Subnets Created: $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"

# Create Route Table for Public Subnets
PUBLIC_RT=$(aws ec2 create-route-table \
  --region $REGION \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$PROJECT_NAME-public-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)

# Add route to Internet Gateway
aws ec2 create-route \
  --region $REGION \
  --route-table-id $PUBLIC_RT \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

# Associate public subnets with route table
aws ec2 associate-route-table \
  --region $REGION \
  --subnet-id $PUBLIC_SUBNET_1 \
  --route-table-id $PUBLIC_RT

aws ec2 associate-route-table \
  --region $REGION \
  --subnet-id $PUBLIC_SUBNET_2 \
  --route-table-id $PUBLIC_RT

echo "✅ Route tables configured"

# Create NAT Gateway (for private subnets to access internet)
# Allocate Elastic IP
EIP_ALLOC=$(aws ec2 allocate-address \
  --region $REGION \
  --domain vpc \
  --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$PROJECT_NAME-nat-eip}]" \
  --query 'AllocationId' \
  --output text)

# Create NAT Gateway in public subnet
NAT_GW=$(aws ec2 create-nat-gateway \
  --region $REGION \
  --subnet-id $PUBLIC_SUBNET_1 \
  --allocation-id $EIP_ALLOC \
  --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$PROJECT_NAME-nat}]" \
  --query 'NatGateway.NatGatewayId' \
  --output text)

echo "✅ NAT Gateway Created: $NAT_GW (waiting for it to become available...)"

# Wait for NAT Gateway to be available
aws ec2 wait nat-gateway-available \
  --region $REGION \
  --nat-gateway-ids $NAT_GW

# Create Route Table for Private Subnets
PRIVATE_RT=$(aws ec2 create-route-table \
  --region $REGION \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$PROJECT_NAME-private-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)

# Add route to NAT Gateway
aws ec2 create-route \
  --region $REGION \
  --route-table-id $PRIVATE_RT \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GW

# Associate private subnets with route table
aws ec2 associate-route-table \
  --region $REGION \
  --subnet-id $PRIVATE_SUBNET_1 \
  --route-table-id $PRIVATE_RT

aws ec2 associate-route-table \
  --region $REGION \
  --subnet-id $PRIVATE_SUBNET_2 \
  --route-table-id $PRIVATE_RT

echo "✅ Private route tables configured"

# Save IDs to file for other scripts
cat > aws-resources.env << EOF
export AWS_REGION=$REGION
export VPC_ID=$VPC_ID
export IGW_ID=$IGW_ID
export PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1
export PUBLIC_SUBNET_2=$PUBLIC_SUBNET_2
export PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1
export PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2
export NAT_GW=$NAT_GW
export EIP_ALLOC=$EIP_ALLOC
EOF

echo ""
echo "🎉 VPC Setup Complete!"
echo "Resource IDs saved to aws-resources.env"
echo ""
echo "VPC ID: $VPC_ID"
echo "Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "Private Subnets: $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"
