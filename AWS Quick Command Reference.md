# AWS Quick Command Reference for Mysos Titan

## Load Environment Variables

```bash
source aws-resources.env
```

---

## EC2 Commands

### List All Instances
```bash
aws ec2 describe-instances \
  --region $AWS_REGION \
  --filters "Name=tag:Name,Values=mysos-titan-*" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

### Start/Stop Instances
```bash
# Stop instance
aws ec2 stop-instances --region $AWS_REGION --instance-ids $LARAVEL_INSTANCE

# Start instance
aws ec2 start-instances --region $AWS_REGION --instance-ids $LARAVEL_INSTANCE

# Reboot instance
aws ec2 reboot-instances --region $AWS_REGION --instance-ids $LARAVEL_INSTANCE
```

### SSH to Instances
```bash
# Laravel server
ssh -i mysos-titan-key.pem ubuntu@$LARAVEL_PUBLIC_IP

# Node.js server
ssh -i mysos-titan-key.pem ubuntu@$NODEJS_PUBLIC_IP
```

### View Instance Logs
```bash
# System log
aws ec2 get-console-output \
  --region $AWS_REGION \
  --instance-id $LARAVEL_INSTANCE \
  --output text

# CloudWatch logs
aws logs tail /aws/ec2/instance/$LARAVEL_INSTANCE --follow
```

### Create Instance Snapshot
```bash
aws ec2 create-image \
  --region $AWS_REGION \
  --instance-id $LARAVEL_INSTANCE \
  --name "mysos-laravel-$(date +%Y%m%d-%H%M)" \
  --description "Manual backup"
```

---

## RDS Commands

### Database Status
```bash
aws rds describe-db-instances \
  --region $AWS_REGION \
  --db-instance-identifier mysos-titan-db \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address,AllocatedStorage]' \
  --output table
```

### Create Database Snapshot
```bash
aws rds create-db-snapshot \
  --region $AWS_REGION \
  --db-instance-identifier mysos-titan-db \
  --db-snapshot-identifier mysos-titan-db-$(date +%Y%m%d-%H%M)
```

### List Database Snapshots
```bash
aws rds describe-db-snapshots \
  --region $AWS_REGION \
  --db-instance-identifier mysos-titan-db \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
  --output table
```

### Connect to Database
```bash
mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME
```

### Restore from Snapshot
```bash
aws rds restore-db-instance-from-db-snapshot \
  --region $AWS_REGION \
  --db-instance-identifier mysos-titan-db-restored \
  --db-snapshot-identifier mysos-titan-db-YYYYMMDD-HHMM
```

---

## Load Balancer Commands

### Check Target Health
```bash
# All target groups
aws elbv2 describe-target-health \
  --region $AWS_REGION \
  --target-group-arn $TG_CORTEX

# Specific target
aws elbv2 describe-target-health \
  --region $AWS_REGION \
  --target-group-arn $TG_CORTEX \
  --targets Id=$LARAVEL_INSTANCE
```

### Register/Deregister Targets
```bash
# Register instance with target group
aws elbv2 register-targets \
  --region $AWS_REGION \
  --target-group-arn $TG_CORTEX \
  --targets Id=$LARAVEL_INSTANCE

# Deregister instance
aws elbv2 deregister-targets \
  --region $AWS_REGION \
  --target-group-arn $TG_CORTEX \
  --targets Id=$LARAVEL_INSTANCE
```

### View Load Balancer Rules
```bash
aws elbv2 describe-rules \
  --region $AWS_REGION \
  --listener-arn $HTTP_LISTENER \
  --output table
```

---

## Redis (ElastiCache) Commands

### Redis Status
```bash
aws elasticache describe-cache-clusters \
  --region $AWS_REGION \
  --cache-cluster-id mysos-titan-redis \
  --show-cache-node-info
```

### Connect to Redis
```bash
# From Laravel or Node.js instance
redis-cli -h $REDIS_ENDPOINT -p $REDIS_PORT

# Test connection
redis-cli -h $REDIS_ENDPOINT -p $REDIS_PORT ping
```

### Create Redis Snapshot
```bash
aws elasticache create-snapshot \
  --region $AWS_REGION \
  --cache-cluster-id mysos-titan-redis \
  --snapshot-name mysos-redis-$(date +%Y%m%d-%H%M)
```

---

## CloudWatch Commands

### View Recent Logs
```bash
# List log groups
aws logs describe-log-groups --region $AWS_REGION

# Tail logs
aws logs tail /aws/ec2/laravel --follow --region $AWS_REGION
```

### Get Metrics
```bash
# CPU usage for last hour
aws cloudwatch get-metric-statistics \
  --region $AWS_REGION \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$LARAVEL_INSTANCE \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --output table
```

### List Alarms
```bash
aws cloudwatch describe-alarms \
  --region $AWS_REGION \
  --alarm-name-prefix mysos-titan \
  --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
  --output table
```

### Disable/Enable Alarms
```bash
# Disable during maintenance
aws cloudwatch disable-alarm-actions \
  --region $AWS_REGION \
  --alarm-names mysos-titan-laravel-cpu-high

# Re-enable
aws cloudwatch enable-alarm-actions \
  --region $AWS_REGION \
  --alarm-names mysos-titan-laravel-cpu-high
```

---

## S3 Commands (for backups/assets)

### Create Bucket
```bash
aws s3 mb s3://mysos-assets --region $AWS_REGION
```

### Sync Files
```bash
# Upload assets
aws s3 sync ./local-assets s3://mysos-assets/

# Download assets
aws s3 sync s3://mysos-assets/ ./local-assets
```

### List Objects
```bash
aws s3 ls s3://mysos-assets/ --recursive --human-readable
```

---

## Security Group Commands

### List Rules
```bash
aws ec2 describe-security-groups \
  --region $AWS_REGION \
  --group-ids $LARAVEL_SG \
  --query 'SecurityGroups[0].IpPermissions'
```

### Add Rule
```bash
# Allow SSH from specific IP
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $LARAVEL_SG \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32
```

### Remove Rule
```bash
aws ec2 revoke-security-group-ingress \
  --region $AWS_REGION \
  --group-id $LARAVEL_SG \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

---

## Cost Management

### Current Month Costs
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

### Cost by Service (Last 30 Days)
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE \
  --output table
```

### Create Budget Alert
```bash
# Create budget for $400/month
cat > budget.json << EOF
{
  "BudgetName": "mysos-monthly-budget",
  "BudgetLimit": {
    "Amount": "400",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
EOF

aws budgets create-budget \
  --account-id YOUR_ACCOUNT_ID \
  --budget file://budget.json
```

---

## WordPress (Lightsail) Commands

### Instance Status
```bash
aws lightsail get-instance \
  --instance-name mysos-wordpress \
  --query 'instance.[state.name,publicIpAddress]' \
  --output table
```

### Create Snapshot
```bash
aws lightsail create-instance-snapshot \
  --instance-name mysos-wordpress \
  --instance-snapshot-name wordpress-$(date +%Y%m%d-%H%M)
```

### Reboot Instance
```bash
aws lightsail reboot-instance --instance-name mysos-wordpress
```

---

## Quick Troubleshooting

### Check All Services Status
```bash
#!/bin/bash
source aws-resources.env

echo "=== EC2 Instances ==="
aws ec2 describe-instances \
  --region $AWS_REGION \
  --instance-ids $LARAVEL_INSTANCE $NODEJS_INSTANCE \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],State.Name]' \
  --output table

echo "=== RDS Status ==="
aws rds describe-db-instances \
  --region $AWS_REGION \
  --db-instance-identifier mysos-titan-db \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text

echo "=== Redis Status ==="
aws elasticache describe-cache-clusters \
  --region $AWS_REGION \
  --cache-cluster-id mysos-titan-redis \
  --query 'CacheClusters[0].CacheClusterStatus' \
  --output text

echo "=== Target Health ==="
aws elbv2 describe-target-health \
  --region $AWS_REGION \
  --target-group-arn $TG_CORTEX \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table

echo "=== CloudWatch Alarms ==="
aws cloudwatch describe-alarms \
  --region $AWS_REGION \
  --state-value ALARM \
  --query 'MetricAlarms[*].[AlarmName,StateReason]' \
  --output table
```

---

## Emergency Procedures

### Scale Up Immediately (High Load)
```bash
# 1. Stop instance
aws ec2 stop-instances --region $AWS_REGION --instance-ids $LARAVEL_INSTANCE

# 2. Wait for stopped state
aws ec2 wait instance-stopped --region $AWS_REGION --instance-ids $LARAVEL_INSTANCE

# 3. Change to larger instance type
aws ec2 modify-instance-attribute \
  --region $AWS_REGION \
  --instance-id $LARAVEL_INSTANCE \
  --instance-type t3.xlarge

# 4. Start instance
aws ec2 start-instances --region $AWS_REGION --instance-ids $LARAVEL_INSTANCE
```

### Database Emergency Restore
```bash
# 1. Get latest snapshot
LATEST_SNAPSHOT=$(aws rds describe-db-snapshots \
  --region $AWS_REGION \
  --db-instance-identifier mysos-titan-db \
  --query 'reverse(sort_by(DBSnapshots[?Status==`available`], &SnapshotCreateTime))[0].DBSnapshotIdentifier' \
  --output text)

# 2. Restore to new instance
aws rds restore-db-instance-from-db-snapshot \
  --region $AWS_REGION \
  --db-instance-identifier mysos-titan-db-emergency \
  --db-snapshot-identifier $LATEST_SNAPSHOT

# 3. Update apps to point to new endpoint
```

### Kill All Connections to RDS
```bash
mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD -e "
SELECT CONCAT('KILL ', id, ';') 
FROM INFORMATION_SCHEMA.PROCESSLIST 
WHERE user != 'rdsadmin' 
INTO OUTFILE '/tmp/kill_processes.txt';
SOURCE /tmp/kill_processes.txt;
"
```

---

## Automation Scripts

### Daily Health Check Script
```bash
#!/bin/bash
# Save as daily-health-check.sh

source aws-resources.env

echo "Daily Health Check - $(date)"
echo "================================"

# Check EC2
LARAVEL_STATUS=$(aws ec2 describe-instance-status --region $AWS_REGION --instance-ids $LARAVEL_INSTANCE --query 'InstanceStatuses[0].InstanceStatus.Status' --output text)
echo "Laravel Server: $LARAVEL_STATUS"

# Check RDS
RDS_STATUS=$(aws rds describe-db-instances --region $AWS_REGION --db-instance-identifier mysos-titan-db --query 'DBInstances[0].DBInstanceStatus' --output text)
echo "Database: $RDS_STATUS"

# Check Alarms
ALARM_COUNT=$(aws cloudwatch describe-alarms --region $AWS_REGION --state-value ALARM --query 'length(MetricAlarms)' --output text)
echo "Active Alarms: $ALARM_COUNT"

if [ "$ALARM_COUNT" -gt 0 ]; then
  echo "WARNING: There are active alarms!"
  aws cloudwatch describe-alarms --region $AWS_REGION --state-value ALARM --query 'MetricAlarms[*].[AlarmName,StateReason]' --output table
fi
```

### Auto-Scale Script (Add Instance When CPU High)
```bash
#!/bin/bash
# Save as auto-scale-check.sh

source aws-resources.env

CPU=$(aws cloudwatch get-metric-statistics \
  --region $AWS_REGION \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$LARAVEL_INSTANCE \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --query 'Datapoints[0].Average' \
  --output text)

if (( $(echo "$CPU > 80" | bc -l) )); then
  echo "CPU is high: $CPU%. Launching additional instance..."
  # Launch new instance script here
else
  echo "CPU is normal: $CPU%"
fi
```

---

## Useful Aliases

Add to ~/.bashrc or ~/.zshrc:

```bash
alias mysos-ssh-laravel='ssh -i ~/mysos-titan-key.pem ubuntu@$(source ~/aws-resources.env && echo $LARAVEL_PUBLIC_IP)'
alias mysos-ssh-nodejs='ssh -i ~/mysos-titan-key.pem ubuntu@$(source ~/aws-resources.env && echo $NODEJS_PUBLIC_IP)'
alias mysos-status='source ~/aws-resources.env && bash ~/daily-health-check.sh'
alias mysos-logs='aws logs tail /aws/ec2/laravel --follow'
alias mysos-costs='aws ce get-cost-and-usage --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) --granularity MONTHLY --metrics BlendedCost --group-by Type=SERVICE'
```

---

## Quick Reference Table

| Task | Command |
|------|---------|
| SSH to Laravel | `ssh -i mysos-titan-key.pem ubuntu@$LARAVEL_PUBLIC_IP` |
| SSH to Node.js | `ssh -i mysos-titan-key.pem ubuntu@$NODEJS_PUBLIC_IP` |
| Connect to MySQL | `mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME` |
| Connect to Redis | `redis-cli -h $REDIS_ENDPOINT -p $REDIS_PORT` |
| View Laravel logs | `aws logs tail /aws/ec2/laravel --follow` |
| Check target health | `aws elbv2 describe-target-health --target-group-arn $TG_CORTEX` |
| List alarms | `aws cloudwatch describe-alarms --alarm-name-prefix mysos-titan` |
| Stop Laravel server | `aws ec2 stop-instances --instance-ids $LARAVEL_INSTANCE` |
| Create DB snapshot | `aws rds create-db-snapshot --db-instance-identifier mysos-titan-db --db-snapshot-identifier backup-$(date +%Y%m%d)` |
| View costs | `aws ce get-cost-and-usage --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) --granularity MONTHLY --metrics BlendedCost` |
