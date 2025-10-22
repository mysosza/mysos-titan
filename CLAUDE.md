# CLAUDE.md

This file provides guidance to Claude Code when working with the MySOS AWS infrastructure deployment scripts.

## Project Overview

AWS infrastructure deployment for MySOS Titan - a hybrid cloud architecture combining AWS services for application hosting with Xneelo dedicated server for WordPress, email, and DNS management.

## Infrastructure Architecture

### Hybrid Setup: AWS + Xneelo

**AWS Infrastructure ($248/month):**
- 2 EC2 instances (Laravel t3.large + Node.js t3.medium)
- RDS MySQL database (db.t3.small, 20GB storage)
- ElastiCache Redis (cache.t3.micro)
- Application Load Balancer (ALB) for HTTPS traffic
- Network Load Balancer (NLB) for TCP panic button connections
- WAF protection, CloudWatch monitoring, SSM Session Manager
- VPC with public/private subnets across 2 availability zones
- NAT Gateway for private subnet internet access

**Xneelo Server ($100/month):**
- WordPress marketing site (mysos.co.za)
- Email hosting (SMTP/IMAP)
- DNS management
- Legacy websites

### Application Domains

**Laravel Apps (on AWS ALB):**
- `cerebrum.mysos.co.za` - Main Laravel application (formerly cortex)
- `neo.mysos.co.za` - API services (formerly apex)
- `portal.mysos.co.za` - Admin console (formerly console)
- `mobile.mysos.co.za` - Mobile app backend (formerly asterix/app)
- `websrc.mysos.co.za` - Web application (formerly web)
- `webskts.mysos.co.za` - WebSocket server (formerly sockets)

**Node.js Apps (on AWS NLB):**
- TCP ports 4000-4009, 5000+ for panic button hardware connections
- 10+ multi-tenant panic button servers managed by PM2

## Key Configuration Files

### aws-resources.env
Central configuration file storing all AWS resource identifiers. Source this file before running any AWS CLI commands or deployment scripts.

**Important exports:**
```bash
export AWS_REGION=af-south-1
export VPC_ID=vpc-0efa5c3ac9425b8d0
export DB_ENDPOINT=mysos-titan-db.c7coqesk2kne.af-south-1.rds.amazonaws.com
export REDIS_ENDPOINT=mysos-titan-redis.mythzx.0001.afs1.cache.amazonaws.com
export ALB_DNS=mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
export LARAVEL_PUBLIC_IP=13.245.247.128
export NODEJS_PUBLIC_IP=13.245.88.195
```

### Deployment Scripts (Run in Order)

1. **1-setup-vpc-and-networking.sh** - VPC, subnets, internet gateway, NAT gateway
2. **2-setup-security-groups.sh** - Security groups for ALB, Laravel, Node.js, RDS, Redis
3. **3-setup-rds-database.sh** - MySQL database (5-10 min provisioning time)
4. **4-setup-elasticache-redis.sh** - Redis cache (3-5 min provisioning time)
5. **5-setup-load-balancer.sh** - ALB with target groups and listener rules
6. **6-setup-ec2-laravel-instances.sh** - Laravel EC2 instance with Ubuntu 24.04
7. **7-setup-ec2-nodejs-instances.sh** - Node.js EC2 instance for panic button servers
8. **8-setup-cloudwatch-monitoring.sh** - CloudWatch alarms and SNS notifications
9. **10-setup-network-load-balancer-tcp.sh** - NLB for TCP panic button traffic
10. **11-setup-waf-protection.sh** - WAF rules for DDoS and bot protection
11. **12-setup-ssm-session-manager.sh** - SSM for secure shell access

### Master Deployment Script

**0-MASTER-DEPLOY-ALL.sh** - Runs all scripts in sequence with validation checks

## Recent Changes (2025-10-17)

### Domain Name Updates

The Laravel application domains were renamed for better clarity:

**Old → New:**
- cortex.mysos.co.za → **cerebrum.mysos.co.za**
- apex.mysos.co.za → **neo.mysos.co.za**
- console.mysos.co.za → **portal.mysos.co.za**

**Infrastructure Changes Made:**
1. Created 3 new ALB target groups (cerebrum, neo, portal)
2. Registered Laravel EC2 instance with new target groups
3. Created ALB listener rules with priorities 10, 11, 12
4. Updated aws-resources.env with new target group ARNs
5. Removed old target group exports (TG_CORTEX, TG_APEX, TG_CONSOLE)
6. Updated COMPLETE-AWS-MYSOS-TITAN-DEPLOYMENT-GUIDE.md

**Old target groups still exist in AWS but are not referenced in configuration files**

### Current Target Groups

```bash
export TG_CEREBRUM=arn:aws:elasticloadbalancing:af-south-1:877582899699:targetgroup/mysos-titan-cerebrum/8007a3f8c8a721fe
export TG_NEO=arn:aws:elasticloadbalancing:af-south-1:877582899699:targetgroup/mysos-titan-neo/fa89ef42a7e54944
export TG_PORTAL=arn:aws:elasticloadbalancing:af-south-1:877582899699:targetgroup/mysos-titan-portal/329ee9a7a08e240f
export TG_MOBILE=arn:aws:elasticloadbalancing:af-south-1:877582899699:targetgroup/mysos-titan-app/36d8c46ca45f95d9
export TG_WEBSRC=arn:aws:elasticloadbalancing:af-south-1:877582899699:targetgroup/mysos-titan-web/8f182d5f099a96ca
export TG_WEBSKTS=arn:aws:elasticloadbalancing:af-south-1:877582899699:targetgroup/mysos-titan-sockets/97d35d01e7e18915
```

## Database Configuration

**RDS MySQL Details:**
- **Endpoint:** mysos-titan-db.c7coqesk2kne.af-south-1.rds.amazonaws.com
- **Port:** 3306
- **Database:** my_sos_production
- **Username:** mysos_admin
- **Password:** Stored in aws-resources.env (DB_PASSWORD)
- **Instance Class:** db.t3.small (2GB RAM, 20GB SSD)
- **Backups:** 7-day retention, automated daily

## Redis Configuration

**ElastiCache Redis:**
- **Endpoint:** mysos-titan-redis.mythzx.0001.afs1.cache.amazonaws.com
- **Port:** 6379
- **No password** (VPC security group protection)
- **Instance Class:** cache.t3.micro (0.5GB)

## Load Balancer Configuration

### Application Load Balancer (ALB)
- **DNS:** mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
- **Protocol:** HTTPS (port 443) + HTTP redirect (port 80)
- **Health Checks:** HTTP codes 200-399 accepted (allows redirects)
- **Listener Rules:** Host-based routing to target groups

### Network Load Balancer (NLB)
- **DNS:** mysos-titan-nlb-tcp-5fc7b76fa947682e.elb.af-south-1.amazonaws.com
- **Static IPs:** 16.28.37.255, 13.246.81.110
- **TCP Ports:** 4000-4009 (panic button servers)
- **Port 5000:** Panic button server for MySOS

## EC2 Instance Details

### Laravel Instance
- **Instance ID:** i-09a737dfe9348a28b
- **Public IP:** 13.245.247.128 (Elastic IP)
- **Private IP:** 10.0.1.81
- **Instance Type:** t3.large (2 vCPU, 8GB RAM)
- **OS:** Ubuntu 24.04 LTS
- **Management:** Laravel Forge
- **SSH Key:** mysos-titan-key.pem

### Node.js Instance
- **Instance ID:** i-04b97d4d49468a701
- **Public IP:** 13.245.88.195 (Elastic IP)
- **Private IP:** 10.0.1.165
- **Instance Type:** t3.medium (2 vCPU, 4GB RAM)
- **OS:** Ubuntu 24.04 LTS
- **Management:** PM2 process manager
- **SSH Key:** mysos-titan-key.pem

## SSH Access

### SSH Configuration
SSH config file location: `/home/mac/.ssh/config`

**Laravel Forge Server:**
```
Host forge-mysos-titan
    HostName 13.245.247.128
    User forge
    IdentityFile ~/.ssh/id_ed25519_mysos
    IdentitiesOnly yes
```

**Direct Ubuntu Access:**
```bash
ssh -i mysos-titan-key.pem ubuntu@13.245.247.128  # Laravel
ssh -i mysos-titan-key.pem ubuntu@13.245.88.195   # Node.js
```

## Laravel Forge Setup

**Server ID:** 972748
**Sites to Create:**
1. cerebrum.mysos.co.za
2. neo.mysos.co.za
3. portal.mysos.co.za
4. mobile.mysos.co.za (formerly asterix/app)
5. websrc.mysos.co.za (formerly web)
6. webskts.mysos.co.za (formerly sockets, with WebSocket support)

**Environment Variables (from aws-resources.env):**
- DB_HOST, DB_DATABASE, DB_USERNAME, DB_PASSWORD
- REDIS_HOST, REDIS_PORT
- AWS_REGION, AWS_BUCKET (for S3 storage)

## DNS Configuration Required

**CNAME Records to Create (Point to ALB):**
```
cerebrum.mysos.co.za   -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
neo.mysos.co.za        -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
portal.mysos.co.za     -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
mobile.mysos.co.za     -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
websrc.mysos.co.za     -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
webskts.mysos.co.za    -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
```

## Monitoring & Alerts

**CloudWatch Dashboard:** mysos-titan-dashboard
**SNS Topic:** mysos-titan-alerts
**Alert Email:** awsadmin@mysos.co.za

**Alarms Configured:**
- High CPU (>80%)
- Database connection failures
- Instance status check failures
- High error rates (>100 5xx errors in 5 min)
- Slow response times (>2 seconds)

## Security Features

- **WAF Protection:** Rate limiting, geo-blocking, SQL injection prevention
- **Security Groups:** Restrictive ingress rules
- **SSM Session Manager:** Secure shell access without SSH keys
- **VPC:** Private subnets for database and cache
- **Encryption:** SSL/TLS for all traffic, RDS encryption at rest

## Cost Optimization

**Monthly Costs (~$248):**
- EC2 instances: $90 (Laravel + Node.js)
- RDS: $36
- ElastiCache: $12
- ALB: $23
- NLB: $6
- NAT Gateway: $32
- CloudWatch: $15
- WAF: $6
- S3/EBS/Data Transfer: $28

## Backup & Recovery

**Automated Backups:**
- RDS: Daily snapshots, 7-day retention
- EC2: Create AMI before major changes
- Forge: Daily database backups to S3

**Manual Backup Commands:**
```bash
# Create RDS snapshot
aws rds create-db-snapshot \
  --db-instance-identifier mysos-titan-db \
  --db-snapshot-identifier mysos-backup-$(date +%Y%m%d)

# Create EC2 AMI
aws ec2 create-image \
  --instance-id $LARAVEL_INSTANCE \
  --name "mysos-laravel-backup-$(date +%Y%m%d)"
```

## Troubleshooting Common Issues

### ALB Health Check Failures
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn $TG_CEREBRUM

# Check Nginx on Laravel instance
ssh -i mysos-titan-key.pem ubuntu@$LARAVEL_PUBLIC_IP
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log
```

### Database Connection Issues
```bash
# Test from Laravel instance
mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD

# Check security group allows connection
aws ec2 describe-security-groups --group-ids $RDS_SG
```

### Node.js Apps Not Responding
```bash
# SSH to Node.js instance
ssh -i mysos-titan-key.pem ubuntu@$NODEJS_PUBLIC_IP

# Check PM2 processes
pm2 list
pm2 logs
pm2 restart all
```

## Important Commands

### Source Configuration
```bash
# Always source before running commands
source aws-resources.env
```

### View All Resources
```bash
# List all target groups
aws elbv2 describe-target-groups --region $AWS_REGION

# List all listener rules
aws elbv2 describe-rules --listener-arn $HTTP_LISTENER

# Check EC2 instance status
aws ec2 describe-instances --instance-ids $LARAVEL_INSTANCE
```

### Scaling Operations

**Vertical Scaling (Change Instance Type):**
```bash
aws ec2 stop-instances --instance-ids $LARAVEL_INSTANCE
aws ec2 modify-instance-attribute \
  --instance-id $LARAVEL_INSTANCE \
  --instance-type t3.xlarge
aws ec2 start-instances --instance-ids $LARAVEL_INSTANCE
```

**Horizontal Scaling (Add Instance):**
```bash
# Launch additional instance
aws ec2 run-instances \
  --image-id ami-xxx \
  --instance-type t3.large \
  --key-name mysos-titan-key \
  --security-group-ids $LARAVEL_SG \
  --subnet-id $PUBLIC_SUBNET_2

# Register with target groups
aws elbv2 register-targets \
  --target-group-arn $TG_CEREBRUM \
  --targets Id=i-newinstance
```

## Development Workflow

1. **Infrastructure Changes:**
   - Update deployment scripts
   - Test in staging environment (if available)
   - Update aws-resources.env
   - Update this CLAUDE.md file

2. **Application Deployment:**
   - Push code to Git
   - Forge auto-deploys (if Quick Deploy enabled)
   - Monitor CloudWatch for errors
   - Check ALB health checks

3. **Database Migrations:**
   - Backup database first
   - Run migrations via Forge or SSH
   - Verify application functionality

## Related Files

- **COMPLETE-AWS-MYSOS-TITAN-DEPLOYMENT-GUIDE.md** - Comprehensive deployment guide
- **9-wordpress-lightsail-setup-guide.md** - WordPress migration guide (deferred)
- **nodejs-deployment-guide.md** - Node.js panic button server setup
- **laravel-db-config.txt** - Laravel database connection config
- **laravel-redis-config.txt** - Laravel Redis connection config
- **aws-resources.env** - All AWS resource identifiers

## Notes for Claude Code

- Always source `aws-resources.env` before running AWS CLI commands
- The infrastructure uses af-south-1 (Cape Town) region
- Target groups accept HTTP codes 200-399 to allow Laravel redirects
- Old target groups (cortex, apex, console) exist but are deprecated
- WordPress remains on Xneelo - not migrating to AWS
- Use SSM Session Manager for secure access when possible
- Check background Bash processes for long-running operations
- Laravel Forge manages the Laravel server - avoid manual Nginx config
- PM2 manages Node.js panic button servers on the Node.js instance
