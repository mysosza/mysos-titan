# Complete AWS Deployment Guide for Mysos Titan

## Overview

This guide covers the complete migration and deployment of the Mysos infrastructure to AWS.

### Architecture Summary

**Hybrid Architecture: AWS + Xneelo**

```
                                    Internet
                                       |
                        ┌──────────────┼──────────────────┐
                        |              |                  |
                  mysos.co.za    *.mysos.co.za      Panic Buttons
                        |              |                  |
                        |              |                  |
              ┌─────────────────┐  [AWS ALB]          [AWS NLB]
              │ Xneelo Dedicated│   + HTTPS            TCP Ports
              │     Server      │      |               4000-4009
              └─────────────────┘      |               5000+
                      |                |                  |
              - WordPress          ┌───┴────┐       ┌────┴────┐
              - Email (SMTP)       │        │       │         │
              - DNS Management [EC2 Laravel] [EC2 Node.js]
              - Legacy Sites    6 Laravel apps  Panic button
                                - cerebrum       servers
                                - neo            - PM2 managed
                                - portal         - Multi-tenant
                                - app
                                - web
                                - sockets
                                    |                  |
                                    └────────┬─────────┘
                                             |
                              ┌──────────────┼──────────────┐
                              |              |              |
                         [RDS MySQL]   [ElastiCache]   [S3 Storage]
                          20GB SSD        Redis          Assets
```

## Cost Breakdown (Monthly)

### AWS Infrastructure

| Service | Configuration | Cost |
|---------|--------------|------|
| **EC2 Laravel** | t3.large (2 vCPU, 8GB) | $60 |
| **EC2 Node.js** | t3.medium (2 vCPU, 4GB) | $30 |
| **RDS MySQL** | db.t3.small (2GB RAM, 20GB) | $36 |
| **ElastiCache Redis** | cache.t3.micro (0.5GB) | $12 |
| **Application Load Balancer** | ALB + routing rules | $23 |
| **Network Load Balancer** | NLB for panic buttons | $6 |
| **WAF Protection** | Web Application Firewall | $6 |
| **NAT Gateway** | For private subnet internet | $32 |
| **CloudWatch** | Logs + Metrics + Alarms | $15 |
| **S3 Storage** | ~50GB assets + SSM logs | $6 |
| **Data Transfer** | ~100GB/month | $10 |
| **SSL Certificates** | ACM certificates | Free |
| **Route 53** | Hosted zone + queries | $1 |
| **EBS Storage** | 80GB SSD (gp3) | $8 |
| **Backups** | RDS snapshots | $3 |
| **Elastic IPs** | 3 total (NAT + 2 NLB) | $0 |
| **AWS Total** | | **~$248/month** |

### Xneelo Infrastructure (Existing)

| Service | Configuration | Cost |
|---------|--------------|------|
| **Dedicated Server** | R1800/month (~$100 USD) | $100 |
| - WordPress | mysos.co.za marketing site | Included |
| - Email Hosting | SMTP/IMAP for all users | Included |
| - DNS Management | Multiple domains | Included |
| - Legacy Sites | Old websites still needed | Included |

### Combined Total

| Category | Monthly Cost |
|----------|-------------|
| AWS Infrastructure | $248 |
| Xneelo (existing) | $100 |
| **TOTAL** | **~$348/month** |

**Note:** Xneelo cost is shared across multiple services (email, DNS, legacy sites), so WordPress hosting is essentially free. Moving WordPress to AWS would add $10/month without reducing Xneelo costs.

---

## Deployment Steps

### Phase 1: Infrastructure Setup (Day 1)

Run these scripts in order:

```bash
# 1. Setup VPC and networking
chmod +x 1-setup-vpc-and-networking.sh
./1-setup-vpc-and-networking.sh

# 2. Create security groups
chmod +x 2-setup-security-groups.sh
./2-setup-security-groups.sh

# 3. Setup RDS database
chmod +x 3-setup-rds-database.sh
./3-setup-rds-database.sh
# ⏳ This takes 5-10 minutes

# 4. Setup ElastiCache Redis
chmod +x 4-setup-elasticache-redis.sh
./4-setup-elasticache-redis.sh
# ⏳ This takes 3-5 minutes

# 5. Setup Application Load Balancer
chmod +x 5-setup-load-balancer.sh
./5-setup-load-balancer.sh

# 6. Launch Laravel EC2 instances
chmod +x 6-setup-ec2-laravel-instances.sh
./6-setup-ec2-laravel-instances.sh

# 7. Launch Node.js EC2 instance
chmod +x 7-setup-ec2-nodejs-instances.sh
./7-setup-ec2-nodejs-instances.sh

# 8. Setup CloudWatch monitoring
chmod +x 8-setup-cloudwatch-monitoring.sh
./8-setup-cloudwatch-monitoring.sh
```

After running all scripts, you'll have:
- ✅ Complete AWS infrastructure
- ✅ EC2 instances ready for apps
- ✅ Database and Redis ready
- ✅ Load balancer configured
- ✅ Monitoring and alarms active

### Phase 2: SSL Certificates (Day 1)

```bash
# Request SSL certificate in AWS Certificate Manager
aws acm request-certificate \
  --region $AWS_REGION \
  --domain-name "*.mysos.co.za" \
  --subject-alternative-names "mysos.co.za" \
  --validation-method DNS

# Get certificate ARN
CERT_ARN=$(aws acm list-certificates \
  --region $AWS_REGION \
  --query 'CertificateSummaryList[0].CertificateArn' \
  --output text)

# Get DNS validation records
aws acm describe-certificate \
  --region $AWS_REGION \
  --certificate-arn $CERT_ARN

# Add the CNAME records to your DNS
# Then wait for validation (usually 5-30 minutes)

# Create HTTPS listener
source aws-resources.env

aws elbv2 create-listener \
  --region $AWS_REGION \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=$CERT_ARN \
  --default-actions Type=forward,TargetGroupArn=$DEFAULT_TG

# Add redirect from HTTP to HTTPS
aws elbv2 modify-listener \
  --region $AWS_REGION \
  --listener-arn $HTTP_LISTENER \
  --default-actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}"
```

### Phase 3: DNS Configuration (Day 1)

**Hybrid DNS Setup: Xneelo + AWS**

Update your DNS records (on Xneelo or Route 53) to point Laravel apps to AWS:

```
# On Xneelo DNS (or Route 53):
# Laravel applications → AWS ALB
cerebrum.mysos.co.za   -> CNAME -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
neo.mysos.co.za        -> CNAME -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
portal.mysos.co.za     -> CNAME -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
mobile.mysos.co.za     -> CNAME -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
web.mysos.co.za        -> CNAME -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
sockets.mysos.co.za    -> CNAME -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com

# Marketing website → Xneelo (unchanged)
mysos.co.za            -> A     -> XNEELO_SERVER_IP

# Email (MX records) → Xneelo (unchanged)
@ MX 10 mail.mysos.co.za
mail.mysos.co.za       -> A     -> XNEELO_SERVER_IP
```

**Note:** WordPress (mysos.co.za), email, and legacy sites remain on Xneelo dedicated server.

### Phase 4: Database Migration (Day 1-2)

```bash
# 1. Export from current MySQL
mysqldump -h old_host -u old_user -p \
  --single-transaction \
  --quick \
  --lock-tables=false \
  old_database > mysos_backup.sql

# 2. Import to RDS
source aws-resources.env

mysql -h $DB_ENDPOINT \
  -u $DB_USERNAME \
  -p$DB_PASSWORD \
  $DB_NAME < mysos_backup.sql

# 3. Verify import
mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME -e "SHOW TABLES;"
```

### Phase 5: Laravel Apps Deployment (Day 2-3)

## Should We Use Forge?

**Yes, definitely keep using Forge!** Here's why:

### Advantages of Using Forge with AWS EC2:

✅ **Deployment Automation** - Zero-downtime deployments with Git
✅ **Site Management** - Easy Nginx config for multiple sites
✅ **SSL Certificates** - Automatic Let's Encrypt renewals
✅ **Queue Workers** - Automatic Supervisor configuration
✅ **Scheduled Jobs** - Easy cron management
✅ **Server Monitoring** - Built-in health checks
✅ **Environment Management** - Easy .env editing
✅ **Database Backups** - Automated backups to S3
✅ **Security Updates** - Automatic security patches

**Cost:** $19/month (unlimited servers) - totally worth it!

### Forge Setup:

```bash
# 1. Add server to Forge
# Go to: https://forge.laravel.com/servers/create

# Connection Details:
Server Provider: Custom VPS
IP Address: YOUR_LARAVEL_PUBLIC_IP
SSH Key: (upload your mysos-titan-key.pem content)

# 2. Forge will install:
# - Nginx, PHP 8.4, MySQL client
# - Redis, Memcached, Node.js
# - Supervisor, Fail2ban, UFW

# 3. Create sites in Forge for each domain
# cerebrum.mysos.co.za
# neo.mysos.co.za
# portal.mysos.co.za
# mobile.mysos.co.za
# web.mysos.co.za
# sockets.mysos.co.za (with WebSocket support)

# 4. Configure each site:
# - Root Directory: /home/forge/[site]/public
# - PHP Version: PHP 8.4
# - Repository: Your Git repo
# - Deploy Branch: main/master

# 5. Add environment variables (from laravel-db-config.txt and laravel-redis-config.txt)

# 6. Enable Quick Deploy (auto-deploy on Git push)

# 7. Deploy each site
```

### Alternative: Manual Management (Not Recommended)

If you don't want to use Forge, you'd need to:
- Manually configure Nginx for each site
- Set up PHP-FPM pools
- Configure SSL certificates manually
- Set up Supervisor for queue workers
- Configure cron jobs manually
- Handle deployments via SSH/CI/CD

**This is much more work and error-prone!** Forge is worth every penny.

---

### Phase 6: Node.js Apps Deployment (Day 2)

Follow the guide in `nodejs-deployment-guide.md`:

```bash
# 1. SSH into Node.js instance
source aws-resources.env
ssh -i mysos-titan-key.pem ubuntu@$NODEJS_PUBLIC_IP

# 2. Copy apps from Digital Ocean
scp -r user@digitalocean:/path/to/apps /opt/panicbuttons/

# Or from local:
scp -i mysos-titan-key.pem -r ./panicbuttons ubuntu@$NODEJS_PUBLIC_IP:/opt/

# 3. Create PM2 ecosystem config
# Update Redis endpoints to use ElastiCache

# 4. Start all apps with PM2
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# 5. Test connections
for port in {4000..4009}; do
  nc -zv localhost $port
done
```

### ~~Phase 7: WordPress Migration~~ (DEFERRED)

**WordPress (mysos.co.za) remains on Xneelo dedicated server.**

Reasons:
- Xneelo R1800/month already paid for email hosting + DNS + legacy sites
- Moving WordPress to AWS Lightsail adds $10/month without cost savings
- No migration risk to marketing website
- Email hosting must stay on Xneelo

See `9-wordpress-lightsail-setup-guide.md` for future reference if requirements change.

---

## Scaling Strategy

When you need more capacity:

### Horizontal Scaling (Recommended)

**Laravel Apps:**
```bash
# Launch additional Laravel instance
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.large \
  --key-name mysos-titan-key \
  --security-group-ids $LARAVEL_SG \
  --subnet-id $PUBLIC_SUBNET_2 \
  --user-data file://user-data-laravel.sh

# Register with all target groups
# ALB will automatically distribute traffic
```

**Node.js Apps:**
```bash
# Launch additional Node.js instance
# Split 10 apps across 2 instances (5 each)
```

### Vertical Scaling

If one server needs more power:

```bash
# Stop instance
aws ec2 stop-instances --instance-ids i-xxx

# Change instance type
aws ec2 modify-instance-attribute \
  --instance-id i-xxx \
  --instance-type t3.xlarge

# Start instance
aws ec2 start-instances --instance-ids i-xxx
```

### Database Scaling

```bash
# Upgrade RDS instance class
aws rds modify-db-instance \
  --db-instance-identifier mysos-titan-db \
  --db-instance-class db.t3.medium \
  --apply-immediately

# Or enable Multi-AZ for high availability
aws rds modify-db-instance \
  --db-instance-identifier mysos-titan-db \
  --multi-az \
  --apply-immediately
```

---

## Backup Strategy

### Automated Backups

**RDS Database:**
- Automated daily backups (7-day retention)
- Manual snapshots before major changes

**EC2 Instances:**
```bash
# Create AMI backup
aws ec2 create-image \
  --instance-id $LARAVEL_INSTANCE \
  --name "mysos-laravel-backup-$(date +%Y%m%d)" \
  --description "Backup before deployment"
```

**WordPress (on Xneelo):**
- Managed by Xneelo (check their backup schedule)
- Consider manual backups via WordPress plugins

### Forge Backups

Configure in Forge:
- Database backups to S3 (daily)
- Retention: 14 days

---

## Disaster Recovery

### Complete Infrastructure Recreation

If you need to rebuild everything:

```bash
# 1. All infrastructure
./1-setup-vpc-and-networking.sh
./2-setup-security-groups.sh
./3-setup-rds-database.sh
# ... run all setup scripts

# 2. Restore database from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier mysos-titan-db-restored \
  --db-snapshot-identifier mysos-titan-db-snapshot-xxx

# 3. Launch EC2 from AMI
aws ec2 run-instances \
  --image-id ami-backup-xxx \
  --instance-type t3.large \
  ...
```

---

## Monitoring & Alerts

Access your monitoring:

**CloudWatch Dashboard:**
https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=mysos-titan-dashboard

**Alerts will be sent to your email for:**
- High CPU usage (>80%)
- Instance failures
- Database issues
- High error rates
- Slow response times

---

## Security Best Practices

### 1. Restrict SSH Access

```bash
# Update security groups to allow SSH only from your IP
aws ec2 authorize-security-group-ingress \
  --group-id $LARAVEL_SG \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32

# Remove the 0.0.0.0/0 rule
aws ec2 revoke-security-group-ingress \
  --group-id $LARAVEL_SG \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

### 2. Enable MFA on AWS Account

### 3. Use AWS Systems Manager Session Manager

```bash
# Instead of SSH, use SSM
aws ssm start-session --target $LARAVEL_INSTANCE
```

### 4. Regular Security Updates

Forge handles this automatically, but for non-Forge instances:

```bash
sudo apt update && sudo apt upgrade -y
```

### 5. Enable AWS Config

```bash
aws configservice put-configuration-recorder --configuration-recorder name=default,roleARN=arn:aws:iam::ACCOUNT:role/config-role --recording-group allSupported=true,includeGlobalResourceTypes=true
```

---

## Troubleshooting

### Can't connect to Laravel apps

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_CEREBRUM

# Check Nginx status on EC2
ssh -i mysos-titan-key.pem ubuntu@$LARAVEL_PUBLIC_IP
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log
```

### Database connection issues

```bash
# Test from Laravel instance
mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD

# Check security group
aws ec2 describe-security-groups --group-ids $RDS_SG
```

### Node.js apps not responding

```bash
# SSH into Node.js instance
pm2 list
pm2 logs
pm2 restart all
```

### High costs

```bash
# Check Cost Explorer
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Enable budget alerts
aws budgets create-budget \
  --account-id YOUR_ACCOUNT_ID \
  --budget file://budget.json
```

---

## Next Steps After Deployment

1. ✅ Test all applications thoroughly
2. ✅ Verify SSL certificates work
3. ✅ Test panic button connections
4. ✅ Monitor for 48 hours before switching DNS completely
5. ✅ Configure Forge for auto-deployments
6. ✅ Set up staging environment (optional)
7. ✅ Document any custom configurations
8. ✅ Train team on AWS console access
9. ✅ Schedule regular backup tests
10. ✅ Review and optimize costs after 1 month

---

## Support Resources

- **AWS Support:** https://console.aws.amazon.com/support/home
- **Forge Support:** https://forge.laravel.com/support
- **Infrastructure Scripts:** All saved in aws-resources.env

---

## Summary

### Hybrid Architecture (AWS + Xneelo)

✅ **AWS Infrastructure:** $248/month
   - EC2 Laravel + Node.js servers
   - RDS MySQL database
   - ElastiCache Redis
   - Load balancers (ALB + NLB)
   - Security (WAF, SSM)
   - Monitoring (CloudWatch)

✅ **Xneelo Server:** $100/month (R1800)
   - WordPress (mysos.co.za)
   - Email hosting (SMTP/IMAP)
   - DNS management
   - Legacy websites

✅ **Total Monthly Cost:** $348/month
✅ **Scalability:** Can easily add more AWS instances
✅ **High Availability:** Load balancers with health checks
✅ **Monitoring:** CloudWatch with SNS alarms
✅ **Backups:** Automated for all critical components
✅ **Security:** VPC, security groups, SSL, WAF
✅ **Easy Management:** Forge for Laravel deployments

**We've built a production-ready, scalable, monitored infrastructure with hybrid architecture that leverages existing Xneelo investment while gaining AWS scalability!** 🚀
