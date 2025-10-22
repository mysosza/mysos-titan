# AWS Cost Optimization Guide for Mysos Titan

## Current Cost Breakdown (~$245/month)

| Service | Cost | Optimization Potential |
|---------|------|------------------------|
| EC2 Laravel (t3.large) | $60 | ⭐⭐⭐ High |
| EC2 Node.js (t3.medium) | $30 | ⭐⭐ Medium |
| RDS MySQL (db.t3.small) | $36 | ⭐⭐ Medium |
| ElastiCache Redis | $12 | ⭐ Low |
| Application Load Balancer | $23 | ⚠️ Fixed |
| NAT Gateway | $32 | ⭐⭐⭐ High |
| Lightsail WordPress | $10 | ⚠️ Already optimal |
| CloudWatch | $15 | ⭐⭐ Medium |
| S3 + Data Transfer | $15 | ⭐ Low |
| Backups | $3 | ⭐ Low |
| EBS Storage | $8 | ⭐ Low |

**Budget:** $380/month  
**Current Cost:** ~$245/month  
**Savings Potential:** Up to $100/month additional  

---

## Immediate Optimizations (Can Implement Today)

### 1. Reserved Instances (Save ~40%)

Instead of on-demand pricing, commit to 1-year Reserved Instances:

```bash
# Check current costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

**Recommendation:** Purchase 1-year Reserved Instances:

| Instance | Current | Reserved | Savings |
|----------|---------|----------|---------|
| t3.large (Laravel) | $60/mo | $37/mo | $23/mo |
| t3.medium (Node.js) | $30/mo | $19/mo | $11/mo |
| db.t3.small (RDS) | $36/mo | $23/mo | $13/mo |

**Total Savings:** ~$47/month ($564/year)

Purchase via AWS Console → EC2 → Reserved Instances

### 2. Use Savings Plans (More Flexible)

Alternative to Reserved Instances with more flexibility:

- **Compute Savings Plan:** 1-year commitment
- Save up to 66% on EC2/Fargate/Lambda
- More flexible than Reserved Instances

Calculate savings: https://aws.amazon.com/savingsplans/pricing/

---

## Medium-Term Optimizations (This Month)

### 3. Optimize NAT Gateway ($32 → $0)

**Problem:** NAT Gateway is expensive and only used for private subnet internet access.

**Solution A: Remove NAT Gateway (Recommended)**

If our private resources (RDS, Redis) don't need internet access:

```bash
# 1. Check if anything in private subnets needs internet
# RDS and Redis typically don't need outbound internet

# 2. Delete NAT Gateway
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW

# 3. Release Elastic IP
aws ec2 release-address --allocation-id $EIP_ALLOC
```

**Savings:** $32/month ($384/year)

**Solution B: Use NAT Instance (if internet needed)**

```bash
# Launch t4g.nano NAT instance (~$3/month)
# Much cheaper than NAT Gateway for low traffic
```

**Savings:** $29/month

### 4. Right-Size EC2 Instances

Monitor actual usage and downsize if possible:

```bash
# Check CPU utilization over last 7 days
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$LARAVEL_INSTANCE \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average
```

**If average CPU < 30%:**

| Current | Downsize To | Savings |
|---------|-------------|---------|
| t3.large | t3.medium | $30/mo |
| t3.medium | t3.small | $15/mo |

**Potential Savings:** $30-45/month

### 5. Use Spot Instances for Non-Critical Workloads

For development/testing environments:

- Spot Instances: Up to 90% discount
- Perfect for non-production workloads
- Not recommended for production database/apps

### 6. Optimize CloudWatch Logs ($15 → $5)

```bash
# Reduce log retention
aws logs put-retention-policy \
  --log-group-name /aws/ec2/laravel \
  --retention-in-days 7  # Instead of 30 days

# Delete unnecessary log streams
# Export old logs to S3 for long-term storage (much cheaper)
```

**Savings:** $10/month

### 7. Use ARM-Based Graviton Instances

AWS Graviton processors are 20% cheaper with better performance:

| Current | Graviton Alternative | Savings |
|---------|---------------------|---------|
| t3.large | t4g.large | $12/mo |
| t3.medium | t4g.medium | $6/mo |

**Total Savings:** $18/month

**Note:** Requires ARM-compatible software (Laravel/PHP works fine)

---

## Advanced Optimizations (Next Quarter)

### 8. Move Static Assets to CloudFront + S3

Instead of serving assets from EC2:

```bash
# Upload assets to S3
aws s3 sync ./public/assets s3://mysos-assets/

# Create CloudFront distribution
aws cloudfront create-distribution \
  --origin-domain-name mysos-assets.s3.amazonaws.com
```

**Benefits:**
- Faster content delivery
- Reduce EC2 bandwidth costs
- Better user experience
- **Savings:** $5-10/month

### 9. Use ElastiCache Reserved Nodes

Similar to EC2, commit to 1-year Redis:

**Current:** $12/month  
**Reserved:** $8/month  
**Savings:** $4/month

### 10. Implement Auto-Scaling

Scale down during low traffic:

```bash
# Create Auto Scaling Group
# Scale to 1 instance during night (8 PM - 6 AM)
# Scale to 2 instances during day

# If traffic is low at night, run 1 instance only
# Savings: ~$20/month (50% reduction during 10 hours/day)
```

**Savings:** $15-20/month

### 11. Optimize Database

#### a) Use Aurora Serverless v2 (if compatible)

- Pay per second of database usage
- Auto-scales based on load
- Can save 50%+ for variable workloads

#### b) Use RDS Read Replicas

- Offload read queries
- Can use smaller primary instance

#### c) Optimize RDS Storage

```bash
# Switch from gp3 to gp2 if IOPS not critical
# Or reduce allocated storage if over-provisioned

# Current: 20GB gp3
# Optimized: 20GB gp2 (if < 3000 IOPS needed)
# Savings: ~$2/month
```

### 12. Use S3 Intelligent-Tiering

For backups and archives:

```bash
# Enable Intelligent-Tiering
aws s3api put-bucket-intelligent-tiering-configuration \
  --bucket mysos-backups \
  --id auto-tier \
  --intelligent-tiering-configuration Status=Enabled,Tiering={Days=90,AccessTier=ARCHIVE_ACCESS}
```

**Savings:** 70% on infrequently accessed data

---

## Cost Monitoring & Alerts

### Set Up Budget Alerts

```bash
cat > budget.json << EOF
{
  "BudgetName": "mysos-monthly",
  "BudgetLimit": {
    "Amount": "380",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {},
  "CostTypes": {
    "IncludeTax": true,
    "IncludeSubscription": true,
    "UseBlended": false,
    "IncludeRefund": false,
    "IncludeCredit": false,
    "IncludeUpfront": true,
    "IncludeRecurring": true,
    "IncludeOtherSubscription": true,
    "IncludeSupport": true,
    "IncludeDiscount": true,
    "UseAmortized": false
  }
}
EOF

aws budgets create-budget \
  --account-id YOUR_ACCOUNT_ID \
  --budget file://budget.json \
  --notifications-with-subscribers \
    NotificationType=ACTUAL,ComparisonOperator=GREATER_THAN,Threshold=80,ThresholdType=PERCENTAGE,Notification={NotificationType=ACTUAL,ComparisonOperator=GREATER_THAN,Threshold=80},Subscribers=[{SubscriptionType=EMAIL,Address=your@email.com}]
```

### Enable Cost Anomaly Detection

```bash
aws ce create-anomaly-monitor \
  --anomaly-monitor MonitorName=MysosCostMonitor,MonitorType=DIMENSIONAL,MonitorDimension=SERVICE

aws ce create-anomaly-subscription \
  --anomaly-subscription AnomalySubscriptionName=MysosAlerts,MonitorArnList=<monitor-arn>,Subscribers=[{Address=your@email.com,Status=CONFIRMED,Type=EMAIL}],Threshold=100
```

### Use Cost Explorer

Access: https://console.aws.amazon.com/cost-management/home

- View daily costs
- Compare month-over-month
- Identify cost spikes
- Filter by service/tag

---

## Recommended Cost Optimization Plan

### Phase 1: Immediate (This Week) - Save $47/month

1. ✅ Purchase 1-year Reserved Instances
   - t3.large (Laravel): $23/month savings
   - t3.medium (Node.js): $11/month savings
   - db.t3.small (RDS): $13/month savings

### Phase 2: Short-term (This Month) - Save $40/month

1. ✅ Remove or replace NAT Gateway: $32/month
2. ✅ Reduce CloudWatch log retention: $10/month
3. ✅ Right-size instances if needed: Variable

### Phase 3: Medium-term (Next 3 Months) - Save $25/month

1. ✅ Migrate to Graviton instances: $18/month
2. ✅ Implement CloudFront for assets: $7/month
3. ✅ Use ElastiCache reserved node: $4/month

### Total Potential Savings: $112/month

**New Monthly Cost:** ~$133/month  
**Annual Savings:** $1,344/year  
**Budget Remaining:** $247/month for growth!

---

## Cost Allocation Tags

Tag all resources for better cost tracking:

```bash
# Tag EC2
aws ec2 create-tags \
  --resources $LARAVEL_INSTANCE \
  --tags Key=Project,Value=Mysos Key=Environment,Value=Production Key=CostCenter,Value=Infrastructure

# Tag RDS
aws rds add-tags-to-resource \
  --resource-name arn:aws:rds:region:account:db:mysos-titan-db \
  --tags Key=Project,Value=Mysos Key=Environment,Value=Production

# Enable cost allocation tags in Billing Console
```

Then filter costs by tag in Cost Explorer.

---

## Free Tier & Credits

### AWS Free Tier (First 12 Months)

- 750 hours/month t2.micro or t3.micro EC2
- 750 hours/month RDS db.t2.micro or db.t3.micro
- 25 GB RDS storage
- 1 million Lambda requests/month
- 50 GB S3 storage

**Note:** We're past free tier for production, but useful for dev/test

### AWS Credits

Check if eligible for:
- AWS Activate (for startups): Up to $100,000 in credits
- AWS ISV Accelerate
- AWS EdStart (if education-related)

Apply: https://aws.amazon.com/activate/

---

## Cost-Effective Architecture Alternatives

### Option A: All-in-One Instance (Save $80/month)

For lower traffic, combine Laravel + Node.js on one larger instance:

- 1x t3.xlarge instead of t3.large + t3.medium
- Current: $90/month → New: $125/month
- Wait, this is more expensive!

**Better: Keep separate instances**

### Option B: Serverless Architecture (Variable Cost)

Migrate to:
- Lambda for APIs (pay per request)
- Aurora Serverless v2
- API Gateway

**Pros:** Scale to zero, only pay for usage  
**Cons:** More complex migration, cold starts

**Good for:** Highly variable traffic (0-100 requests/sec)

### Option C: Lightsail for Everything (Limited Scale)

Move all apps to Lightsail:
- $40/month for 4GB RAM instance
- Much simpler, fixed pricing
- **Cons:** Less scalable, fewer features

**Good for:** Simple deployments, <10k daily users

---

## Monitoring Cost Efficiency

### Key Metrics to Track

```bash
# Cost per request
Total Monthly Cost / Total Requests = Cost per request

# Cost per user
Total Monthly Cost / Active Users = Cost per user

# Resource utilization
Average CPU / Memory utilization should be 40-70%
```

### Monthly Cost Review Checklist

- [ ] Review Cost Explorer for anomalies
- [ ] Check instance utilization (right-sized?)
- [ ] Review unused resources (idle instances, unattached volumes)
- [ ] Check backup retention policies
- [ ] Review data transfer costs
- [ ] Optimize log retention
- [ ] Check for unused Elastic IPs
- [ ] Review snapshot storage

---

## Tools for Cost Optimization

### AWS Cost Explorer
- Visualize spending
- Forecast future costs
- Identify trends

### AWS Trusted Advisor
- Free cost optimization recommendations
- Idle resources detection
- Reserved Instance recommendations

### Third-Party Tools
- **CloudHealth:** Advanced cost management
- **CloudCheckr:** Multi-cloud cost optimization
- **Spot.io:** Automated Spot instance management

---

## Summary: Recommended Optimizations

### Must-Do (High Impact, Low Effort)

1. ✅ **Buy Reserved Instances:** $47/month savings
2. ✅ **Remove NAT Gateway:** $32/month savings (if not needed)
3. ✅ **Reduce log retention:** $10/month savings

**Total Easy Wins:** $89/month ($1,068/year)

### Should-Do (Medium Impact, Medium Effort)

4. ✅ **Migrate to Graviton:** $18/month savings
5. ✅ **Right-size instances:** $15-30/month savings
6. ✅ **Implement CloudFront:** $7/month savings

**Total Additional:** $40-55/month

### Nice-to-Have (Lower Priority)

7. ⭐ **Auto-scaling:** $15-20/month savings
8. ⭐ **S3 lifecycle policies:** $5/month savings
9. ⭐ **Reserved Redis:** $4/month savings

---

## Final Optimized Architecture

**Current:** $245/month  
**After Optimizations:** $133-150/month  
**Annual Savings:** ~$1,200-1,300  
**Budget Utilization:** 35-40% (excellent buffer for growth!)

```
Monthly Cost Breakdown (Optimized):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EC2 Laravel (Reserved t4g.large)     $28
EC2 Node.js (Reserved t4g.medium)    $14
RDS MySQL (Reserved db.t3.small)     $23
ElastiCache Redis (Reserved)         $8
Application Load Balancer            $23
Lightsail WordPress                  $10
CloudWatch (optimized)               $5
S3 + CloudFront                      $10
Data Transfer                        $8
Backups                              $3
EBS Storage                          $8
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total                                $140/month
```

**We've saved over $100/month while maintaining the same performance!** 🎉
