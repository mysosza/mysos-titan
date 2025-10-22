# WordPress on AWS Lightsail Setup Guide

> **⚠️ STATUS: DEFERRED - WordPress Staying on Xneelo**
>
> **Decision:** WordPress (mysos.co.za) will remain on the existing Xneelo dedicated server for now.
>
> **Reasons:**
> - Xneelo dedicated server (R1800/month) already paid for and hosts email, DNS, and legacy sites
> - Moving WordPress to AWS Lightsail would add $10/month without eliminating Xneelo costs
> - Email hosting must stay on Xneelo (critical business function)
> - DNS management currently on Xneelo serves multiple domains
> - No migration effort or risk to marketing website
> - Separation of marketing site from production infrastructure
>
> **This guide is kept for future reference if requirements change.**

---

## Why Lightsail for WordPress?

Lightsail is perfect for WordPress because:
- Fixed monthly pricing ($10/month for 2GB RAM)
- Pre-configured WordPress stack
- Easy SSL certificate management
- Built-in backups
- Much cheaper than EC2 for simple WordPress sites

## Setup Steps

### 1. Create Lightsail Instance

```bash
# Via AWS CLI
aws lightsail create-instances \
  --region $AWS_REGION \
  --instance-names mysos-wordpress \
  --availability-zone ${AWS_REGION}a \
  --blueprint-id wordpress \
  --bundle-id medium_2_0 \
  --tags key=Name,value=mysos-wordpress

# Wait for instance to be running
aws lightsail get-instance --instance-name mysos-wordpress
```

### 2. Get SSH Key

```bash
# Download SSH key
aws lightsail download-default-key-pair \
  --region $AWS_REGION \
  --output text > lightsail-key.pem

chmod 400 lightsail-key.pem
```

### 3. Get Instance Details

```bash
# Get public IP
aws lightsail get-instance \
  --instance-name mysos-wordpress \
  --query 'instance.publicIpAddress' \
  --output text
```

### 4. Access WordPress

1. SSH into instance:
   ```bash
   ssh -i lightsail-key.pem bitnami@YOUR_LIGHTSAIL_IP
   ```

2. Get WordPress admin password:
   ```bash
   cat bitnami_application_password
   ```

3. Access WordPress admin:
   ```
   https://YOUR_LIGHTSAIL_IP/wp-admin
   Username: user
   Password: (from step 2)
   ```

### 5. Attach Static IP

```bash
# Allocate static IP
aws lightsail allocate-static-ip \
  --region $AWS_REGION \
  --static-ip-name mysos-wordpress-ip

# Attach to instance
aws lightsail attach-static-ip \
  --region $AWS_REGION \
  --static-ip-name mysos-wordpress-ip \
  --instance-name mysos-wordpress
```

### 6. Configure DNS

Point your domain `mysos.co.za` to the Lightsail static IP in your DNS settings.

### 7. Enable SSL

```bash
# SSH into instance
ssh -i lightsail-key.pem bitnami@YOUR_LIGHTSAIL_IP

# Run Bitnami's SSL tool
sudo /opt/bitnami/bncert-tool
# Follow the prompts and enter mysos.co.za
```

### 8. Migrate Existing WordPress Site

#### Option A: Via Plugin (Easiest)

1. Install "All-in-One WP Migration" on both sites
2. Export from old site
3. Import to new site

#### Option B: Manual Migration

```bash
# On old server, backup database
mysqldump -u username -p database_name > wordpress_backup.sql

# Backup files
tar -czf wordpress_files.tar.gz /path/to/wordpress

# Copy to new server
scp -i lightsail-key.pem wordpress_backup.sql bitnami@NEW_IP:/tmp/
scp -i lightsail-key.pem wordpress_files.tar.gz bitnami@NEW_IP:/tmp/

# On new server, restore
mysql -u bn_wordpress -p bitnami_wordpress < /tmp/wordpress_backup.sql

# Extract files
cd /opt/bitnami/wordpress
sudo tar -xzf /tmp/wordpress_files.tar.gz

# Fix permissions
sudo chown -R bitnami:daemon /opt/bitnami/wordpress
sudo find /opt/bitnami/wordpress -type d -exec chmod 775 {} \;
sudo find /opt/bitnami/wordpress -type f -exec chmod 664 {} \;
```

### 9. Configure Cron Jobs

```bash
# SSH into Lightsail instance
ssh -i lightsail-key.pem bitnami@YOUR_LIGHTSAIL_IP

# Edit crontab
crontab -e

# Add your WordPress cron jobs
# Example:
# */5 * * * * php /opt/bitnami/wordpress/wp-cron.php >/dev/null 2>&1
```

### 10. Enable Automatic Backups

```bash
# Via CLI
aws lightsail enable-add-on \
  --region $AWS_REGION \
  --resource-name mysos-wordpress \
  --add-on-request addOnType=AutoSnapshot,autoSnapshotAddOnRequest={snapshotTimeOfDay=02:00}
```

## Lightsail Instance Management

### Connect via Browser

```bash
# Get browser SSH URL
aws lightsail get-instance-access-details \
  --region $AWS_REGION \
  --instance-name mysos-wordpress
```

### View Metrics

```bash
aws lightsail get-instance-metric-data \
  --region $AWS_REGION \
  --instance-name mysos-wordpress \
  --metric-name CPUUtilization \
  --period 300 \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --unit Percent \
  --statistics Average
```

### Create Manual Snapshot

```bash
aws lightsail create-instance-snapshot \
  --region $AWS_REGION \
  --instance-name mysos-wordpress \
  --instance-snapshot-name mysos-wordpress-snapshot-$(date +%Y%m%d)
```

## Cost

- Lightsail Instance (2GB RAM): **$10/month**
- Static IP: **Free** (when attached)
- Automatic Backups: **Free**
- SSL Certificate: **Free** (via Let's Encrypt)

**Total: $10/month**

## Useful Bitnami Commands

```bash
# Restart all services
sudo /opt/bitnami/ctlscript.sh restart

# Restart Apache
sudo /opt/bitnami/ctlscript.sh restart apache

# Restart MySQL
sudo /opt/bitnami/ctlscript.sh restart mysql

# Check status
sudo /opt/bitnami/ctlscript.sh status

# View logs
sudo tail -f /opt/bitnami/apache/logs/error_log
```

## Connect WordPress to RDS (Optional)

If you want WordPress to use the same RDS database:

1. Edit wp-config.php:
   ```bash
   sudo nano /opt/bitnami/wordpress/wp-config.php
   ```

2. Update database settings:
   ```php
   define('DB_NAME', 'mysos_production');
   define('DB_USER', 'mysos_admin');
   define('DB_PASSWORD', 'YOUR_PASSWORD');
   define('DB_HOST', 'YOUR_RDS_ENDPOINT');
   ```

3. Restart services:
   ```bash
   sudo /opt/bitnami/ctlscript.sh restart
   ```

## Monitoring

Lightsail includes built-in monitoring for:
- CPU utilization
- Network in/out
- Instance status

Access via AWS Console: https://lightsail.aws.amazon.com/
