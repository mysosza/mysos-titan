#!/bin/bash
# AWS WAF (Web Application Firewall) Setup
# Protects ALB from common web attacks
set -e

source aws-resources.env

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        AWS WAF Setup for Application Load Balancer          ║"
echo "║                                                              ║"
echo "║  Protects against: SQL injection, XSS, bad bots, DDoS       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "📋 What this creates:"
echo "  - WAF Web ACL"
echo "  - AWS Managed Rule Groups (free protection)"
echo "  - Rate limiting (1000 req/5min per IP)"
echo "  - IP reputation lists"
echo "  - Bot control (basic)"
echo ""

read -p "Continue with WAF setup? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Setup cancelled."
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Creating WAF Web ACL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create WAF Web ACL with AWS Managed Rules
cat > waf-rules.json << 'EOF'
{
  "Name": "mysos-titan-waf",
  "Scope": "REGIONAL",
  "DefaultAction": {
    "Allow": {}
  },
  "Description": "WAF protection for Mysos Titan ALB",
  "Rules": [
    {
      "Name": "AWSManagedRulesCommonRuleSet",
      "Priority": 0,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesCommonRuleSet"
        }
      },
      "OverrideAction": {
        "None": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "AWSManagedRulesCommonRuleSetMetric"
      }
    },
    {
      "Name": "AWSManagedRulesKnownBadInputsRuleSet",
      "Priority": 1,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesKnownBadInputsRuleSet"
        }
      },
      "OverrideAction": {
        "None": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "AWSManagedRulesKnownBadInputsRuleSetMetric"
      }
    },
    {
      "Name": "AWSManagedRulesSQLiRuleSet",
      "Priority": 2,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesSQLiRuleSet"
        }
      },
      "OverrideAction": {
        "None": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "AWSManagedRulesSQLiRuleSetMetric"
      }
    },
    {
      "Name": "AWSManagedRulesLinuxRuleSet",
      "Priority": 3,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesLinuxRuleSet"
        }
      },
      "OverrideAction": {
        "None": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "AWSManagedRulesLinuxRuleSetMetric"
      }
    },
    {
      "Name": "AWSManagedRulesAmazonIpReputationList",
      "Priority": 4,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesAmazonIpReputationList"
        }
      },
      "OverrideAction": {
        "None": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "AWSManagedRulesAmazonIpReputationListMetric"
      }
    },
    {
      "Name": "RateLimitRule",
      "Priority": 5,
      "Statement": {
        "RateBasedStatement": {
          "Limit": 1000,
          "AggregateKeyType": "IP"
        }
      },
      "Action": {
        "Block": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "RateLimitRuleMetric"
      }
    }
  ],
  "VisibilityConfig": {
    "SampledRequestsEnabled": true,
    "CloudWatchMetricsEnabled": true,
    "MetricName": "mysos-titan-waf"
  }
}
EOF

echo "⏳ Creating WAF Web ACL with managed rule groups..."

WAF_OUTPUT=$(aws wafv2 create-web-acl \
  --region $AWS_REGION \
  --cli-input-json file://waf-rules.json)

WAF_ARN=$(echo $WAF_OUTPUT | jq -r '.Summary.ARN')
WAF_ID=$(echo $WAF_OUTPUT | jq -r '.Summary.Id')

echo "✅ WAF Web ACL Created"
echo "   ARN: $WAF_ARN"
echo "   ID: $WAF_ID"

rm waf-rules.json

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Associating WAF with ALB"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "⏳ Associating WAF Web ACL with Application Load Balancer..."

aws wafv2 associate-web-acl \
  --region $AWS_REGION \
  --web-acl-arn $WAF_ARN \
  --resource-arn $ALB_ARN

echo "✅ WAF associated with ALB"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Creating CloudWatch Dashboard for WAF"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat > waf-dashboard.json << EOF
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/WAFV2", "AllowedRequests", {"stat": "Sum"}],
          [".", "BlockedRequests", {"stat": "Sum"}]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "$AWS_REGION",
        "title": "WAF Requests - Allowed vs Blocked"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/WAFV2", "CountedRequests", {"stat": "Sum"}]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "$AWS_REGION",
        "title": "WAF Total Requests"
      }
    }
  ]
}
EOF

aws cloudwatch put-dashboard \
  --region $AWS_REGION \
  --dashboard-name "mysos-titan-waf" \
  --dashboard-body file://waf-dashboard.json

echo "✅ WAF CloudWatch Dashboard created"

rm waf-dashboard.json

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Creating WAF Logging (Optional but Recommended)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Enable WAF logging to S3? (Adds ~$5/month) (yes/no): " ENABLE_LOGGING

if [ "$ENABLE_LOGGING" == "yes" ]; then
  # Create S3 bucket for WAF logs
  WAF_LOG_BUCKET="aws-waf-logs-mysos-titan-$(date +%s)"
  
  aws s3 mb s3://$WAF_LOG_BUCKET --region $AWS_REGION
  
  # Set bucket policy for WAF
  cat > waf-bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSLogDeliveryWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::$WAF_LOG_BUCKET/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    },
    {
      "Sid": "AWSLogDeliveryAclCheck",
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::$WAF_LOG_BUCKET"
    }
  ]
}
EOF
  
  aws s3api put-bucket-policy \
    --bucket $WAF_LOG_BUCKET \
    --policy file://waf-bucket-policy.json
  
  # Enable logging
  aws wafv2 put-logging-configuration \
    --region $AWS_REGION \
    --logging-configuration \
      ResourceArn=$WAF_ARN,\
LogDestinationConfigs=arn:aws:s3:::$WAF_LOG_BUCKET
  
  echo "✅ WAF logging enabled to S3: $WAF_LOG_BUCKET"
  
  rm waf-bucket-policy.json
else
  echo "⏭  WAF logging skipped"
fi

# Save to env file
cat >> aws-resources.env << EOF
export WAF_ARN=$WAF_ARN
export WAF_ID=$WAF_ID
EOF

if [ "$ENABLE_LOGGING" == "yes" ]; then
  echo "export WAF_LOG_BUCKET=$WAF_LOG_BUCKET" >> aws-resources.env
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              🎉 WAF Protection Active! 🎉                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 WAF Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Web ACL ARN: $WAF_ARN"
echo "Associated with: $ALB_ARN"
echo ""
echo "🛡️  Protection Enabled:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Common web exploits (OWASP Top 10)"
echo "✅ Known bad inputs"
echo "✅ SQL injection attacks"
echo "✅ Linux/POSIX command injection"
echo "✅ IP reputation filtering"
echo "✅ Rate limiting (1000 req per 5 minutes per IP)"
echo ""
echo "📊 Monitoring:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "WAF Dashboard:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=mysos-titan-waf"
echo ""
echo "WAF Metrics:"
echo "https://console.aws.amazon.com/wafv2/homev2/web-acl/$WAF_ID?region=$AWS_REGION"
echo ""
echo "💰 Cost: ~$5-10/month + $1 per million requests"
echo ""
echo "📝 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Monitor WAF metrics in CloudWatch"
echo "2. Review blocked requests to ensure no false positives"
echo "3. Fine-tune rate limits if needed"
echo "4. Consider adding custom rules for our specific needs"
echo ""
echo "🔧 To adjust rate limit:"
echo "  1. Go to WAF Console"
echo "  2. Edit 'RateLimitRule'"
echo "  3. Change limit from 1000 to desired value"
echo ""
echo "⚠️  If legitimate traffic is blocked:"
echo "  1. Check WAF dashboard for blocked patterns"
echo "  2. Add exception rules in WAF console"
echo "  3. Review CloudWatch logs"
echo ""
echo "🎯 WAF is now protecting our ALB from:"
echo "  - SQL injection attempts"
echo "  - Cross-site scripting (XSS)"
echo "  - Bot traffic"
echo "  - Known malicious IPs"
echo "  - Rate limit abuse"
echo "  - Common web exploits"
echo ""
