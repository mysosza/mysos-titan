#!/bin/bash
# CloudWatch Monitoring and Alarms Setup for mysos-titan
set -e

source aws-resources.env

echo "📊 Setting up CloudWatch Monitoring and Alarms..."

# Create SNS Topic for Alarms
SNS_TOPIC_ARN=$(aws sns create-topic \
  --region $AWS_REGION \
  --name "$PROJECT_NAME-alerts" \
  --tags "Key=Name,Value=$PROJECT_NAME-alerts" \
  --query 'TopicArn' \
  --output text)

echo "✅ SNS Topic Created: $SNS_TOPIC_ARN"

# Subscribe email to SNS topic (replace with your email)
echo ""
read -p "Enter email address for alerts: " ALERT_EMAIL

aws sns subscribe \
  --region $AWS_REGION \
  --topic-arn $SNS_TOPIC_ARN \
  --protocol email \
  --notification-endpoint $ALERT_EMAIL

echo "✅ Email subscription pending confirmation. Check your inbox!"

# Create CloudWatch Dashboard
cat > dashboard.json << EOF
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/EC2", "CPUUtilization", {"stat": "Average", "label": "Laravel Server CPU"}],
          ["...", {"stat": "Average", "label": "Node.js Server CPU"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "$AWS_REGION",
        "title": "EC2 CPU Usage",
        "yAxis": {"left": {"min": 0, "max": 100}}
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/RDS", "CPUUtilization", {"stat": "Average"}],
          [".", "DatabaseConnections", {"stat": "Average"}],
          [".", "FreeStorageSpace", {"stat": "Average"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "$AWS_REGION",
        "title": "RDS Metrics"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "TargetResponseTime", {"stat": "Average"}],
          [".", "RequestCount", {"stat": "Sum"}],
          [".", "HTTPCode_Target_5XX_Count", {"stat": "Sum"}],
          [".", "HTTPCode_Target_4XX_Count", {"stat": "Sum"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "$AWS_REGION",
        "title": "Load Balancer Metrics"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ElastiCache", "CPUUtilization", {"stat": "Average"}],
          [".", "NetworkBytesIn", {"stat": "Sum"}],
          [".", "NetworkBytesOut", {"stat": "Sum"}],
          [".", "CurrConnections", {"stat": "Average"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "$AWS_REGION",
        "title": "Redis Metrics"
      }
    }
  ]
}
EOF

aws cloudwatch put-dashboard \
  --region $AWS_REGION \
  --dashboard-name "$PROJECT_NAME-dashboard" \
  --dashboard-body file://dashboard.json

echo "✅ CloudWatch Dashboard Created"

# Create CloudWatch Alarms

# EC2 Laravel Instance Alarms
aws cloudwatch put-metric-alarm \
  --region $AWS_REGION \
  --alarm-name "$PROJECT_NAME-laravel-cpu-high" \
  --alarm-description "Alert when Laravel server CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=InstanceId,Value=$LARAVEL_INSTANCE \
  --alarm-actions $SNS_TOPIC_ARN

echo "✅ Alarm Created: Laravel CPU High"

aws cloudwatch put-metric-alarm \
  --region $AWS_REGION \
  --alarm-name "$PROJECT_NAME-laravel-status-check" \
  --alarm-description "Alert when Laravel instance fails status checks" \
  --metric-name StatusCheckFailed \
  --namespace AWS/EC2 \
  --statistic Maximum \
  --period 60 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 2 \
  --dimensions Name=InstanceId,Value=$LARAVEL_INSTANCE \
  --alarm-actions $SNS_TOPIC_ARN

echo "✅ Alarm Created: Laravel Status Check"

# EC2 Node.js Instance Alarms
aws cloudwatch put-metric-alarm \
  --region $AWS_REGION \
  --alarm-name "$PROJECT_NAME-nodejs-cpu-high" \
  --alarm-description "Alert when Node.js server CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=InstanceId,Value=$NODEJS_INSTANCE \
  --alarm-actions $SNS_TOPIC_ARN

echo "✅ Alarm Created: Node.js CPU High"

# RDS Alarms
aws cloudwatch put-metric-alarm \
  --region $AWS_REGION \
  --alarm-name "$PROJECT_NAME-rds-cpu-high" \
  --alarm-description "Alert when RDS CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=DBInstanceIdentifier,Value=mysos-titan-db \
  --alarm-actions $SNS_TOPIC_ARN

echo "✅ Alarm Created: RDS CPU High"

aws cloudwatch put-metric-alarm \
  --region $AWS_REGION \
  --alarm-name "$PROJECT_NAME-rds-storage-low" \
  --alarm-description "Alert when RDS free storage is below 2GB" \
  --metric-name FreeStorageSpace \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 2000000000 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=DBInstanceIdentifier,Value=mysos-titan-db \
  --alarm-actions $SNS_TOPIC_ARN

echo "✅ Alarm Created: RDS Storage Low"

aws cloudwatch put-metric-alarm \
  --region $AWS_REGION \
  --alarm-name "$PROJECT_NAME-rds-connections-high" \
  --alarm-description "Alert when RDS connections exceed 80" \
  --metric-name DatabaseConnections \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=DBInstanceIdentifier,Value=mysos-titan-db \
  --alarm-actions $SNS_TOPIC_ARN

echo "✅ Alarm Created: RDS Connections High"

# Load Balancer Alarms
aws cloudwatch put-metric-alarm \
  --region $AWS_REGION \
  --alarm-name "$PROJECT_NAME-alb-5xx-errors" \
  --alarm-description "Alert on high 5XX error rate" \
  --metric-name HTTPCode_Target_5XX_Count \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d':' -f6 | cut -d'/' -f2-) \
  --alarm-actions $SNS_TOPIC_ARN

echo "✅ Alarm Created: ALB 5XX Errors"

aws cloudwatch put-metric-alarm \
  --region $AWS_REGION \
  --alarm-name "$PROJECT_NAME-alb-response-time" \
  --alarm-description "Alert when response time exceeds 2 seconds" \
  --metric-name TargetResponseTime \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 300 \
  --threshold 2 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d':' -f6 | cut -d'/' -f2-) \
  --alarm-actions $SNS_TOPIC_ARN

echo "✅ Alarm Created: ALB Response Time"

# Redis Alarms
aws cloudwatch put-metric-alarm \
  --region $AWS_REGION \
  --alarm-name "$PROJECT_NAME-redis-cpu-high" \
  --alarm-description "Alert when Redis CPU exceeds 75%" \
  --metric-name CPUUtilization \
  --namespace AWS/ElastiCache \
  --statistic Average \
  --period 300 \
  --threshold 75 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=CacheClusterId,Value=mysos-titan-redis \
  --alarm-actions $SNS_TOPIC_ARN

echo "✅ Alarm Created: Redis CPU High"

# Save to env file
cat >> aws-resources.env << EOF
export SNS_TOPIC_ARN=$SNS_TOPIC_ARN
export ALERT_EMAIL=$ALERT_EMAIL
EOF

echo ""
echo "🎉 CloudWatch Monitoring Setup Complete!"
echo ""
echo "📊 Dashboard: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=$PROJECT_NAME-dashboard"
echo ""
echo "Alarms Created:"
echo "  ✅ Laravel Server: CPU, Status Checks"
echo "  ✅ Node.js Server: CPU"
echo "  ✅ RDS: CPU, Storage, Connections"
echo "  ✅ Load Balancer: 5XX Errors, Response Time"
echo "  ✅ Redis: CPU"
echo ""
echo "⚠️  Don't forget to confirm the email subscription!"
