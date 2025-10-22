# Laravel Forge Setup Guide - MySOS Titan Deployment

## Server Status: ✅ READY FOR FORGE CONFIGURATION

The EC2 instance has been successfully provisioned with:
- ✅ Forge user created (uid 1001, sudo + www-data groups)
- ✅ PHP 8.4.13 installed
- ✅ Composer 2.8.12 installed
- ✅ Nginx 1.28.0 installed
- ✅ Supervisor installed
- ✅ Ubuntu 24.04 LTS

**Server IP:** 13.245.247.128
**Forge Server ID:** 972748
**SSH Key:** mysos-titan-key.pem

---

## Part 1: Connect Server to Forge Dashboard

### Step 1: Log into Laravel Forge

Visit: https://forge.laravel.com/servers/972748

### Step 2: Verify Server Connection

The server should already appear in your Forge dashboard as Server ID 972748. If the server shows as disconnected:

1. SSH into the server and run: `sudo systemctl status forge-daemon`
2. Check logs: `sudo journalctl -u forge-daemon -f`
3. If needed, restart: `sudo systemctl restart forge-daemon`

---

## Part 2: Create 6 Laravel Sites

You need to create the following sites in Forge:

### Sites to Create:

1. **cerebrum.mysos.co.za** - Main Laravel API (formerly cortex)
2. **neo.mysos.co.za** - API services (formerly apex)
3. **portal.mysos.co.za** - Admin console (formerly console)
4. **app.mysos.co.za** - Mobile app backend
5. **web.mysos.co.za** - Web application
6. **sockets.mysos.co.za** - WebSocket server

---

### For Each Site, Follow These Steps:

## Site Creation Wizard

### 1. Create New Site

Click **"New Site"** on Server 972748

**Site Details:**
- **Root Domain:** [e.g., cerebrum.mysos.co.za]
- **Project Type:** Laravel 12 (General PHP/Laravel)
- **Web Directory:** /public
- **PHP Version:** PHP 8.4
- **Wildcard Subdomain:** No

Click **"Add Site"**

---

### 2. Link Git Repository

Navigate to: **Site → Git Repository**

**Repository Details:**
- **Provider:** GitHub
- **Repository:** `mysosza/mysos-cerebrum` (or appropriate repo)
- **Branch:** `main`
- **Install Composer Dependencies:** ✅ Yes

Click **"Install Repository"**

---

### 3. Configure Environment Variables (.env)

Navigate to: **Site → Environment**

Click **"Edit Environment"** and paste appropriate configuration for each app:

#### A. Cerebrum Environment Variables

```env
APP_NAME="mySOS Cerebrum"
APP_ENV=production
APP_KEY=base64:GENERATE_THIS_IN_FORGE
APP_DEBUG=false
APP_URL=https://cerebrum.mysos.co.za

LOG_CHANNEL=stack
LOG_LEVEL=info

# Database (RDS MySQL)
DB_CONNECTION=mysql
DB_HOST=mysos-titan-db.c7coqesk2kne.af-south-1.rds.amazonaws.com
DB_PORT=3306
DB_DATABASE=my_sos_production
DB_USERNAME=mysos_admin
DB_PASSWORD=y91W267JVYGGwRsfRNStCGca

# Redis (ElastiCache)
REDIS_HOST=mysos-titan-redis.mythzx.0001.afs1.cache.amazonaws.com
REDIS_PORT=6379
REDIS_PASSWORD=null
REDIS_CLIENT=phpredis

# Cache & Session
CACHE_DRIVER=redis
SESSION_DRIVER=redis
SESSION_LIFETIME=120

# Queue Configuration - AWS SQS (RECOMMENDED)
QUEUE_CONNECTION=sqs
SQS_PREFIX=https://sqs.af-south-1.amazonaws.com/877582899699
SQS_QUEUE=mysos-queue-default
SQS_REGION=af-south-1

# Queue Configuration - IronMQ (LEGACY - will be deprecated)
# QUEUE_CONNECTION=iron
# IRON_MQ_HOST=mq-aws-us-east-1-1.iron.io
# IRON_MQ_TOKEN=your_iron_token
# IRON_MQ_PROJECT_ID=your_project_id

# AWS S3 Storage
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_DEFAULT_REGION=af-south-1
AWS_BUCKET=mysos-assets
AWS_USE_PATH_STYLE_ENDPOINT=false

# SMS Provider - Connect Mobile (PRIMARY - credentials in code)
# SMS is handled via Connect Mobile API (https://sms.connect-mobile.co.za)
# Credentials are hardcoded in ServiceSMS_Providers_Connect.php

# SMS Provider - Twilio (BACKUP - currently disabled)
# TWILIO_SID=your_twilio_sid
# TWILIO_TOKEN=your_twilio_token
# TWILIO_FROM=+27xxxxx

# Push Notifications
APNS_KEY_ID=your_apns_key
APNS_TEAM_ID=your_team_id
APNS_BUNDLE_ID=com.mysos.app
FCM_SERVER_KEY=your_fcm_key

# URL Shortening
BITLY_ACCESS_TOKEN=your_bitly_token
```

Click **"Save Environment"**

---

#### B. Neo Environment Variables

```env
APP_NAME="mySOS Neo"
APP_ENV=production
APP_KEY=base64:GENERATE_THIS_IN_FORGE
APP_DEBUG=false
APP_URL=https://neo.mysos.co.za

# Database (same RDS as Cerebrum)
DB_CONNECTION=mysql
DB_HOST=mysos-titan-db.c7coqesk2kne.af-south-1.rds.amazonaws.com
DB_PORT=3306
DB_DATABASE=my_sos_production
DB_USERNAME=mysos_admin
DB_PASSWORD=y91W267JVYGGwRsfRNStCGca

# Redis (same ElastiCache)
REDIS_HOST=mysos-titan-redis.mythzx.0001.afs1.cache.amazonaws.com
REDIS_PORT=6379
CACHE_DRIVER=redis
SESSION_DRIVER=redis

# Queue - AWS SQS (RECOMMENDED)
QUEUE_CONNECTION=sqs
SQS_PREFIX=https://sqs.af-south-1.amazonaws.com/877582899699
SQS_QUEUE=mysos-queue-default
SQS_REGION=af-south-1

# Queue - IronMQ (LEGACY)
# QUEUE_CONNECTION=iron
# IRON_MQ_HOST=mq-aws-us-east-1-1.iron.io
# IRON_MQ_TOKEN=your_iron_token
# IRON_MQ_PROJECT_ID=your_project_id

# SMS Provider - Connect Mobile (PRIMARY - credentials in code)
# Twilio (BACKUP - currently disabled)
# TWILIO_SID=your_twilio_sid
# TWILIO_TOKEN=your_twilio_token
# TWILIO_FROM=+27xxxxx

# reCAPTCHA v3
RECAPTCHAV3_SITEKEY=your_recaptcha_sitekey
RECAPTCHAV3_SECRET=your_recaptcha_secret

# AWS S3
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_DEFAULT_REGION=af-south-1
AWS_BUCKET=mysos-assets
```

---

#### C. Portal Environment Variables

```env
APP_NAME="mySOS Portal"
APP_ENV=production
APP_KEY=base64:GENERATE_THIS_IN_FORGE
APP_DEBUG=false
APP_URL=https://portal.mysos.co.za

# Database
DB_CONNECTION=mysql
DB_HOST=mysos-titan-db.c7coqesk2kne.af-south-1.rds.amazonaws.com
DB_PORT=3306
DB_DATABASE=my_sos_production
DB_USERNAME=mysos_admin
DB_PASSWORD=y91W267JVYGGwRsfRNStCGca

# Redis
REDIS_HOST=mysos-titan-redis.mythzx.0001.afs1.cache.amazonaws.com
REDIS_PORT=6379
CACHE_DRIVER=redis
SESSION_DRIVER=redis

# Queue - AWS SQS (RECOMMENDED)
QUEUE_CONNECTION=sqs
SQS_PREFIX=https://sqs.af-south-1.amazonaws.com/877582899699
SQS_QUEUE=mysos-queue-default
SQS_REGION=af-south-1

# Queue - IronMQ (LEGACY)
# QUEUE_CONNECTION=iron
# IRON_MQ_HOST=mq-aws-us-east-1-1.iron.io
# IRON_MQ_TOKEN=your_iron_token
# IRON_MQ_PROJECT_ID=your_project_id

# SMS Provider - Connect Mobile (PRIMARY - credentials in code)
# Twilio (BACKUP - currently disabled)
# TWILIO_SID=your_twilio_sid
# TWILIO_TOKEN=your_twilio_token

# AWS S3
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_DEFAULT_REGION=af-south-1
AWS_BUCKET=mysos-assets
```

---

#### D. App, Web, Sockets Environment Variables

Similar to above, adjust `APP_NAME` and `APP_URL` accordingly.

---

### 4. Generate Application Key

After saving environment:

Navigate to: **Site → Application**

Click **"Generate Key"** - This will generate `APP_KEY` in your `.env`

---

### 5. Enable Quick Deploy

Navigate to: **Site → Apps**

Toggle **"Quick Deploy"** to ON

This enables automatic deployments when you push to the Git branch.

---

### 6. Run First Deployment

Navigate to: **Site → Apps**

Click **"Deploy Now"**

This will:
1. Pull latest code from Git
2. Run `composer install`
3. Clear/cache config
4. Restart PHP-FPM

Monitor deployment logs for errors.

---

### 7. Run Database Migrations

**⚠️ IMPORTANT: Only do this AFTER database is successfully imported!**

Navigate to: **Site → Commands**

Run these commands:

```bash
# For first site only (Cerebrum)
php artisan migrate --force

# For all sites
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

---

### 8. Configure Queue Workers

Navigate to: **Site → Queue**

Click **"New Worker"**

**Worker Configuration (SQS - Recommended):**
- **Connection:** sqs
- **Queue:** default
- **Timeout:** 90 seconds
- **Sleep:** 3 seconds
- **Tries:** 3
- **Processes:** 1 (increase if needed)

**Worker Command:**
```bash
php /home/forge/cerebrum.mysos.co.za/artisan queue:work sqs --tries=3 --timeout=90 --sleep=3 --max-time=3600
```

Click **"Create Worker"**

**Alternative: IronMQ (Legacy - will be deprecated)**
- **Connection:** iron
- **Queue:** default
- **Timeout:** 90 seconds

**Note:** See `SQS-MIGRATION-GUIDE.md` for complete migration instructions from IronMQ to AWS SQS.

---

### 8a. AWS SQS Queue Configuration (Recommended)

**✅ Benefits of AWS SQS:**
- **Cost Savings:** $588-1,188/year savings vs IronMQ
- **AWS Native:** Better integration with existing infrastructure
- **High Availability:** 99.9% SLA
- **Free Tier:** 1 million requests/month included

#### Environment Variables for SQS

Add these to your site's environment configuration:

```env
# AWS SQS Queue Configuration (replaces IronMQ)
QUEUE_CONNECTION=sqs
SQS_PREFIX=https://sqs.af-south-1.amazonaws.com/877582899699
SQS_QUEUE=mysos-queue-default
SQS_REGION=af-south-1

# AWS Credentials (should already exist)
AWS_ACCESS_KEY_ID=your_aws_access_key_id_here
AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key_here
AWS_DEFAULT_REGION=af-south-1
```

#### SQS Queues Available

1. **mysos-queue-default** - Standard priority jobs
2. **mysos-queue-high** - Time-critical jobs (emergency alerts, SMS)
3. **mysos-queue-failed** - Failed jobs queue

#### High Priority Worker (Optional)

For time-critical jobs, create a second worker:

```bash
php /home/forge/cerebrum.mysos.co.za/artisan queue:work sqs --queue=mysos-queue-high --tries=3 --timeout=60 --sleep=1
```

**Complete Migration Guide:** See `/home/mac/Clients/MySOS/AWSDeployments/AWSScripts/SQS-MIGRATION-GUIDE.md`

---

### 9. Configure Scheduled Jobs (Cron)

Navigate to: **Site → Scheduler**

Verify that Laravel's scheduler is enabled:

```bash
* * * * * php /home/forge/[site]/artisan schedule:run >> /dev/null 2>&1
```

This should be created automatically. If not, add it manually.

---

### 10. SSL Certificate

Navigate to: **Site → SSL**

#### Option A: Let's Encrypt (Free, Recommended)

1. Select **"Let's Encrypt"**
2. Check ✅ domains to secure
3. Click **"Obtain Certificate"**

Forge will automatically:
- Request certificate
- Install certificate
- Configure Nginx
- Set up auto-renewal

#### Option B: Use AWS Certificate Manager (ACM)

If using ALB with HTTPS termination, you can skip site-level SSL and configure it at the ALB level instead (see SSL configuration section below).

---

### 11. Configure Nginx (If Needed)

Navigate to: **Site → Files → Edit Nginx Configuration**

Default configuration should work, but if you need custom rules:

```nginx
location / {
    try_files $uri $uri/ /index.php?$query_string;
}

# Increase upload size for media
client_max_body_size 100M;

# Add security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

Click **"Update"**

---

## Part 3: Verify All 6 Sites

After creating all sites, verify:

### Checklist:

- [ ] cerebrum.mysos.co.za - Deployed and running
- [ ] neo.mysos.co.za - Deployed and running
- [ ] portal.mysos.co.za - Deployed and running
- [ ] app.mysos.co.za - Deployed and running
- [ ] web.mysos.co.za - Deployed and running
- [ ] sockets.mysos.co.za - Deployed and running (with WebSocket support)

### Test Each Site:

```bash
# Test from your local machine or server
curl -I https://cerebrum.mysos.co.za
curl -I https://neo.mysos.co.za
curl -I https://portal.mysos.co.za
# etc...
```

Expected: HTTP 200 OK or 302 redirect (not 500 errors)

---

## Part 4: ALB Health Check Configuration

Once sites are deployed, register the Laravel EC2 instance with ALB target groups:

```bash
cd /home/mac/Clients/MySOS/AWSDeployments/AWSScripts
source aws-resources.env

# Register Laravel instance with all target groups
aws elbv2 register-targets --target-group-arn $TG_CEREBRUM --targets Id=$LARAVEL_INSTANCE
aws elbv2 register-targets --target-group-arn $TG_NEO --targets Id=$LARAVEL_INSTANCE
aws elbv2 register-targets --target-group-arn $TG_PORTAL --targets Id=$LARAVEL_INSTANCE
aws elbv2 register-targets --target-group-arn $TG_APP --targets Id=$LARAVEL_INSTANCE
aws elbv2 register-targets --target-group-arn $TG_WEB --targets Id=$LARAVEL_INSTANCE
aws elbv2 register-targets --target-group-arn $TG_SOCKETS --targets Id=$LARAVEL_INSTANCE

# Check health status (wait 1-2 minutes)
aws elbv2 describe-target-health --target-group-arn $TG_CEREBRUM
```

Target health should show `"State": "healthy"` for all target groups.

---

## Part 5: SSL Certificate for ALB (HTTPS)

### Step 1: Request Certificate in ACM

```bash
source aws-resources.env

# Request wildcard SSL certificate
aws acm request-certificate \
  --region $AWS_REGION \
  --domain-name "*.mysos.co.za" \
  --subject-alternative-names "mysos.co.za" \
  --validation-method DNS
```

### Step 2: Get Certificate ARN

```bash
CERT_ARN=$(aws acm list-certificates \
  --region $AWS_REGION \
  --query 'CertificateSummaryList[0].CertificateArn' \
  --output text)

echo "Certificate ARN: $CERT_ARN"
```

### Step 3: Get DNS Validation Records

```bash
aws acm describe-certificate \
  --region $AWS_REGION \
  --certificate-arn $CERT_ARN
```

### Step 4: Add CNAME Records to DNS

You'll get output like:

```json
"ResourceRecord": {
  "Name": "_abc123.mysos.co.za.",
  "Type": "CNAME",
  "Value": "_xyz456.acm-validations.aws."
}
```

Add this CNAME record to your DNS provider (Xneelo or Route 53).

### Step 5: Wait for Validation

Certificate validation usually takes 5-30 minutes. Check status:

```bash
aws acm describe-certificate \
  --region $AWS_REGION \
  --certificate-arn $CERT_ARN \
  --query 'Certificate.Status'
```

Wait until status shows `"ISSUED"`

### Step 6: Create HTTPS Listener on ALB

```bash
aws elbv2 create-listener \
  --region $AWS_REGION \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=$CERT_ARN \
  --default-actions Type=forward,TargetGroupArn=$DEFAULT_TG
```

### Step 7: Configure HTTP to HTTPS Redirect

```bash
aws elbv2 modify-listener \
  --region $AWS_REGION \
  --listener-arn $HTTP_LISTENER \
  --default-actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}"
```

---

## Part 6: DNS Configuration

### Update DNS Records (Xneelo or Route 53)

Point all Laravel domains to the ALB:

```
# CNAME records pointing to ALB
cerebrum.mysos.co.za   -> CNAME -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
neo.mysos.co.za        -> CNAME -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
portal.mysos.co.za     -> CNAME -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
app.mysos.co.za        -> CNAME -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
web.mysos.co.za        -> CNAME -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
sockets.mysos.co.za    -> CNAME -> mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
```

### DNS Propagation

- DNS changes can take 5 minutes to 24 hours to propagate
- Test with: `dig cerebrum.mysos.co.za` or `nslookup cerebrum.mysos.co.za`

---

## Part 7: Testing & Verification

### Test Application Endpoints

```bash
# Test via ALB DNS (before updating public DNS)
curl -H "Host: cerebrum.mysos.co.za" https://mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com

# Test after DNS update
curl -I https://cerebrum.mysos.co.za
curl -I https://neo.mysos.co.za
curl -I https://portal.mysos.co.za
```

### Monitor CloudWatch

Check: https://console.aws.amazon.com/cloudwatch/home?region=af-south-1#dashboards:name=mysos-titan-dashboard

Monitor:
- Target health
- Response times
- Error rates (4xx, 5xx)
- Request counts

### Check Forge Logs

Navigate to: **Site → Logs**

Monitor:
- Application logs
- Queue logs
- Deployment logs

### Test Database Connectivity

SSH into Laravel EC2:

```bash
ssh -i mysos-titan-key.pem ubuntu@13.245.247.128
sudo su - forge
cd /home/forge/cerebrum.mysos.co.za
php artisan tinker
>>> DB::connection()->getPdo();
>>> DB::table('users')->count();
```

Should not throw errors.

### Test Redis Connectivity

```bash
php artisan tinker
>>> Redis::ping();
>>> Cache::put('test', 'value', 60);
>>> Cache::get('test');
```

Should return "value".

---

## Part 8: Deployment Workflow

### Automatic Deployments

With Quick Deploy enabled:

1. Push code to Git main branch
2. Forge automatically pulls and deploys
3. Runs composer install
4. Clears/caches config

### Manual Deployments

Navigate to: **Site → Apps → Deploy Now**

### Rollback

Navigate to: **Site → Apps → Deployment History**

Click **"Rollback"** on any previous successful deployment.

---

## Part 9: Backup Strategy

### Configure Database Backups

Navigate to: **Server → Backups**

**Backup Configuration:**
- **Provider:** AWS S3
- **Bucket:** mysos-backups (create if needed)
- **Region:** af-south-1
- **Frequency:** Daily at 02:00 UTC
- **Retention:** 14 days

Click **"Configure"**

---

## Part 10: Monitoring & Alerts

### Enable Forge Monitoring

Navigate to: **Server → Monitoring**

Enable monitoring for:
- CPU usage
- Memory usage
- Disk usage
- Load average

### CloudWatch Alarms

Alarms are already configured via CloudWatch:
- High CPU (>80%)
- Instance status failures
- High error rates

Alerts sent to: awsadmin@mysos.co.za

---

## Troubleshooting

### Site Returns 500 Error

1. Check logs: **Site → Logs**
2. Check permissions: `sudo chown -R forge:forge /home/forge/[site]`
3. Check .env: Verify database credentials
4. Check storage: `cd /home/forge/[site] && php artisan storage:link`

### Queue Jobs Not Processing

1. Check worker: **Site → Queue**
2. Restart worker: Click **"Restart"**
3. Check supervisor: `sudo supervisorctl status`

### Database Connection Failed

1. Verify RDS endpoint: `echo $DB_HOST` in .env
2. Test connection: `mysql -h [RDS_ENDPOINT] -u mysos_admin -p`
3. Check security group: RDS_SG must allow Laravel_SG

### SSL Certificate Issues

1. Verify ACM certificate status: `aws acm describe-certificate`
2. Check ALB listener: `aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN`
3. Verify DNS CNAME validation records

---

## Summary

After completing this guide, you will have:

✅ 6 Laravel sites deployed and running on Forge
✅ Git-based automatic deployments configured
✅ Queue workers processing background jobs
✅ Scheduled tasks running via cron
✅ SSL certificates installed (via Let's Encrypt or ACM)
✅ Database backups configured
✅ Monitoring and alerting active
✅ ALB routing traffic to all sites

**Next Steps:**
1. Complete database import (see separate guide)
2. Run database migrations
3. Deploy Node.js panic button servers
4. Update DNS to point to AWS
5. Test end-to-end functionality

---

## Quick Reference

**Forge Dashboard:** https://forge.laravel.com/servers/972748
**Server IP:** 13.245.247.128
**Database Endpoint:** mysos-titan-db.c7coqesk2kne.af-south-1.rds.amazonaws.com
**Redis Endpoint:** mysos-titan-redis.mythzx.0001.afs1.cache.amazonaws.com
**ALB DNS:** mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com

**SSH Command:**
```bash
ssh -i mysos-titan-key.pem ubuntu@13.245.247.128
# Or as forge user:
ssh -i mysos-titan-key.pem forge@13.245.247.128
```
