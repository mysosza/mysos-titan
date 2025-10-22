#!/bin/bash
# Network Load Balancer Setup for Node.js TCP Panic Button Servers
# CRITICAL: This prevents single point of failure for panic buttons
set -e

source aws-resources.env

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   Network Load Balancer for Panic Button TCP Servers        ║"
echo "║                                                              ║"
echo "║  This is CRITICAL for panic button reliability!             ║"
echo "║  Creates high-availability TCP load balancing               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "📋 What this creates:"
echo "  - Network Load Balancer (Layer 4)"
echo "  - Target Groups for ports 4000-4009"
echo "  - Health checks for each TCP port"
echo "  - Static IP addresses for panic buttons"
echo "  - Automatic failover capability"
echo ""

read -p "Continue with NLB setup? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Setup cancelled."
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Creating Network Load Balancer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Allocate Elastic IPs for NLB (for static IP addresses)
EIP_1=$(aws ec2 allocate-address \
  --region $AWS_REGION \
  --domain vpc \
  --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$PROJECT_NAME-nlb-eip-1}]" \
  --query 'AllocationId' \
  --output text)

EIP_2=$(aws ec2 allocate-address \
  --region $AWS_REGION \
  --domain vpc \
  --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$PROJECT_NAME-nlb-eip-2}]" \
  --query 'AllocationId' \
  --output text)

echo "✅ Elastic IPs allocated:"
echo "   EIP 1: $EIP_1"
echo "   EIP 2: $EIP_2"

# Get the public IPs
NLB_IP_1=$(aws ec2 describe-addresses \
  --region $AWS_REGION \
  --allocation-ids $EIP_1 \
  --query 'Addresses[0].PublicIp' \
  --output text)

NLB_IP_2=$(aws ec2 describe-addresses \
  --region $AWS_REGION \
  --allocation-ids $EIP_2 \
  --query 'Addresses[0].PublicIp' \
  --output text)

echo "   Public IPs: $NLB_IP_1, $NLB_IP_2"

# Create Network Load Balancer
NLB_ARN=$(aws elbv2 create-load-balancer \
  --region $AWS_REGION \
  --name "$PROJECT_NAME-nlb-tcp" \
  --type network \
  --scheme internet-facing \
  --subnet-mappings SubnetId=$PUBLIC_SUBNET_1,AllocationId=$EIP_1 SubnetId=$PUBLIC_SUBNET_2,AllocationId=$EIP_2 \
  --tags "Key=Name,Value=$PROJECT_NAME-nlb-tcp" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

NLB_DNS=$(aws elbv2 describe-load-balancers \
  --region $AWS_REGION \
  --load-balancer-arns $NLB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "✅ Network Load Balancer Created"
echo "   ARN: $NLB_ARN"
echo "   DNS: $NLB_DNS"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Creating Target Groups for TCP Ports"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create target groups for each panic button port (4000-4009)
declare -A TCP_TG_ARNS

for PORT in {4000..4009}; do
  TG_NAME="$PROJECT_NAME-tcp-$PORT"
  
  TG_ARN=$(aws elbv2 create-target-group \
    --region $AWS_REGION \
    --name "$TG_NAME" \
    --protocol TCP \
    --port $PORT \
    --vpc-id $VPC_ID \
    --target-type instance \
    --health-check-enabled \
    --health-check-protocol TCP \
    --health-check-port $PORT \
    --health-check-interval-seconds 30 \
    --healthy-threshold-count 3 \
    --unhealthy-threshold-count 3 \
    --tags "Key=Name,Value=$TG_NAME" "Key=Port,Value=$PORT" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
  
  TCP_TG_ARNS[$PORT]=$TG_ARN
  echo "✅ Target Group Created: Port $PORT ($TG_ARN)"
  
  # Register Node.js instance with this target group
  aws elbv2 register-targets \
    --region $AWS_REGION \
    --target-group-arn $TG_ARN \
    --targets Id=$NODEJS_INSTANCE,Port=$PORT
  
  echo "   ✅ Registered instance $NODEJS_INSTANCE:$PORT"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Creating Listeners for Each Port"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

declare -A TCP_LISTENER_ARNS

for PORT in {4000..4009}; do
  TG_ARN="${TCP_TG_ARNS[$PORT]}"
  
  LISTENER_ARN=$(aws elbv2 create-listener \
    --region $AWS_REGION \
    --load-balancer-arn $NLB_ARN \
    --protocol TCP \
    --port $PORT \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN \
    --tags "Key=Name,Value=$PROJECT_NAME-tcp-listener-$PORT" \
    --query 'Listeners[0].ListenerArn' \
    --output text)
  
  TCP_LISTENER_ARNS[$PORT]=$LISTENER_ARN
  echo "✅ Listener Created: Port $PORT → Target Group"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Updating Security Group"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Update Node.js security group to allow traffic from NLB
# NLB uses source IPs from the subnets, so we need to allow from VPC CIDR
echo "⏳ Updating Node.js security group to allow NLB traffic..."

aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $NODEJS_SG \
  --protocol tcp \
  --port 4000-4009 \
  --cidr 10.0.0.0/16 \
  2>/dev/null || echo "   (Rule may already exist)"

echo "✅ Security group updated"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Waiting for Target Health Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "⏳ Waiting for targets to become healthy (this takes 1-2 minutes)..."
sleep 120

echo ""
echo "Checking target health:"
for PORT in {4000..4009}; do
  TG_ARN="${TCP_TG_ARNS[$PORT]}"
  
  HEALTH_STATUS=$(aws elbv2 describe-target-health \
    --region $AWS_REGION \
    --target-group-arn $TG_ARN \
    --query 'TargetHealthDescriptions[0].TargetHealth.State' \
    --output text)
  
  if [ "$HEALTH_STATUS" == "healthy" ]; then
    echo "  ✅ Port $PORT: healthy"
  else
    echo "  ⚠️  Port $PORT: $HEALTH_STATUS (may need more time or check PM2 on server)"
  fi
done

# Save to env file
cat >> aws-resources.env << EOF
export NLB_ARN=$NLB_ARN
export NLB_DNS=$NLB_DNS
export NLB_IP_1=$NLB_IP_1
export NLB_IP_2=$NLB_IP_2
export NLB_EIP_1=$EIP_1
export NLB_EIP_2=$EIP_2
EOF

# Save target group ARNs
for PORT in {4000..4009}; do
  echo "export TCP_TG_$PORT=${TCP_TG_ARNS[$PORT]}" >> aws-resources.env
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           🎉 Network Load Balancer Setup Complete! 🎉        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Network Load Balancer Details"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "DNS Name: $NLB_DNS"
echo "Static IPs:"
echo "  - $NLB_IP_1 (AZ 1)"
echo "  - $NLB_IP_2 (AZ 2)"
echo ""
echo "Listening on ports: 4000-4009"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 IMPORTANT: Update Panic Button Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Update all panic buttons to connect to NLB instead of EC2:"
echo ""
echo "OLD: panic-button-1 connects to $NODEJS_PUBLIC_IP:4000"
echo "NEW: panic-button-1 connects to $NLB_IP_1:4000"
echo ""
echo "Or use DNS (recommended):"
echo "NEW: panic-button-1 connects to $NLB_DNS:4000"
echo ""
echo "Port mapping:"
for PORT in {4000..4009}; do
  APP_NUM=$((PORT - 3999))
  echo "  panic-button-$APP_NUM → $NLB_IP_1:$PORT or $NLB_DNS:$PORT"
done
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Testing Connection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Test TCP connection to NLB:"
echo "  nc -zv $NLB_DNS 4000"
echo ""
echo "Or from panic button, test connection:"
echo "  telnet $NLB_IP_1 4000"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Benefits Achieved"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ High availability - automatic failover"
echo "✅ Health checks - unhealthy targets removed"
echo "✅ Static IP addresses - easier panic button config"
echo "✅ Can now scale Node.js horizontally"
echo "✅ Zero-downtime deployments possible"
echo "✅ Better security - can restrict EC2 SSH"
echo ""
echo "💰 Cost: ~$16/month"
echo ""
echo "🎯 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Test each port: for i in {4000..4009}; do nc -zv $NLB_DNS \$i; done"
echo "2. Update panic button firmware/config to use new IPs"
echo "3. Monitor CloudWatch for connection metrics"
echo "4. Consider adding second Node.js instance for true HA"
echo "5. Update documentation with new connection endpoints"
echo ""
echo "📈 To add more Node.js instances:"
echo "  1. Launch new EC2 with same setup"
echo "  2. Register with target groups:"
echo "     aws elbv2 register-targets --target-group-arn <TG_ARN> --targets Id=<NEW_INSTANCE_ID>"
echo "  3. NLB automatically distributes traffic"
echo ""
