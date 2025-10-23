#!/bin/bash
# Application Load Balancer Setup for mysos-titan
set -e

source aws-resources.env

echo "⚖️  Creating Application Load Balancer..."

# Create ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
  --region $AWS_REGION \
  --name "$PROJECT_NAME-alb" \
  --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
  --security-groups $ALB_SG \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --tags "Key=Name,Value=$PROJECT_NAME-alb" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region $AWS_REGION \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "✅ ALB Created: $ALB_DNS"

# Create Target Groups for each Laravel app
declare -A APPS
APPS=(
  ["cortex"]="cortex.mysos.co.za"
  ["apex"]="apex.mysos.co.za"
  ["console"]="console.mysos.co.za"
  ["mobile"]="mobile.mysos.co.za"
  ["web"]="web.mysos.co.za"
  ["sockets"]="sockets.mysos.co.za"
)

# Create default target group (will be used for unknown hosts)
DEFAULT_TG=$(aws elbv2 create-target-group \
  --region $AWS_REGION \
  --name "$PROJECT_NAME-default" \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --health-check-enabled \
  --health-check-protocol HTTP \
  --health-check-path "/" \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --tags "Key=Name,Value=$PROJECT_NAME-default" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "✅ Default Target Group Created"

# Create target groups for each app
declare -A TG_ARNS

for APP in "${!APPS[@]}"; do
  TG_ARN=$(aws elbv2 create-target-group \
    --region $AWS_REGION \
    --name "$PROJECT_NAME-$APP" \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --health-check-enabled \
    --health-check-protocol HTTP \
    --health-check-path "/" \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --target-type instance \
    --tags "Key=Name,Value=$PROJECT_NAME-$APP" "Key=App,Value=$APP" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
  
  TG_ARNS[$APP]=$TG_ARN
  echo "✅ Target Group Created: $APP ($TG_ARN)"
done

# Create HTTP Listener (port 80)
HTTP_LISTENER=$(aws elbv2 create-listener \
  --region $AWS_REGION \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$DEFAULT_TG \
  --query 'Listeners[0].ListenerArn' \
  --output text)

echo "✅ HTTP Listener Created"

# Create host-based routing rules for each app
PRIORITY=1
for APP in "${!APPS[@]}"; do
  DOMAIN="${APPS[$APP]}"
  TG_ARN="${TG_ARNS[$APP]}"
  
  aws elbv2 create-rule \
    --region $AWS_REGION \
    --listener-arn $HTTP_LISTENER \
    --priority $PRIORITY \
    --conditions Field=host-header,Values="$DOMAIN" \
    --actions Type=forward,TargetGroupArn=$TG_ARN \
    --tags "Key=Name,Value=$PROJECT_NAME-rule-$APP"
  
  echo "✅ Rule Created: $DOMAIN -> $APP"
  PRIORITY=$((PRIORITY + 1))
done

# Create HTTPS Listener (port 443) - we'll add SSL certificates later
# Note: This will fail until we have a certificate
echo ""
echo "📝 To add HTTPS support:"
echo "1. Request/import SSL certificate in AWS Certificate Manager"
echo "2. Create HTTPS listener with certificate"
echo "3. Update listener with: aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTPS --port 443 --certificates CertificateArn=<cert-arn> --default-actions Type=forward,TargetGroupArn=$DEFAULT_TG"
echo ""

# Save to env file
cat >> aws-resources.env << EOF
export ALB_ARN=$ALB_ARN
export ALB_DNS=$ALB_DNS
export HTTP_LISTENER=$HTTP_LISTENER
export DEFAULT_TG=$DEFAULT_TG
export TG_CORTEX=${TG_ARNS[cortex]}
export TG_APEX=${TG_ARNS[apex]}
export TG_CONSOLE=${TG_ARNS[console]}
export TG_APP=${TG_ARNS[app]}
export TG_WEB=${TG_ARNS[web]}
export TG_SOCKETS=${TG_ARNS[sockets]}
EOF

echo ""
echo "🎉 Load Balancer Setup Complete!"
echo "ALB DNS: $ALB_DNS"
echo ""
echo "Next steps:"
echo "1. Update DNS records to point our domains to: $ALB_DNS"
echo "2. Create SSL certificates in ACM"
echo "3. Launch EC2 instances and register them with target groups"
