# Laravel Forge Setup Guide for AWS EC2

## Why Use Forge?

Forge automates everything we'd otherwise do manually:
- ✅ Zero-downtime deployments
- ✅ Queue worker management
- ✅ SSL certificates (Let's Encrypt)
- ✅ Scheduled jobs (cron)
- ✅ Nginx configuration
- ✅ Security updates
- ✅ Database backups to S3

**Cost:** $19/month for unlimited servers (worth every penny!)

---

## Step 1: Sign Up for Forge

1. Go to: https://forge.laravel.com
2. Sign up or log in
3. Choose the **Growth** plan ($19/month)

---

## Step 2: Connect AWS Account (Optional)

While we can add our EC2 as a "Custom VPS", connecting AWS gives us extra features:

1. In Forge, go to **Account → Providers**
2. Click **AWS**
3. Add credentials:
   - Access Key ID
   - Secret Access Key
   - Region: (our AWS_REGION)

To get AWS credentials for Forge:

```bash
# Create IAM user for Forge
aws iam create-user --user-name forge-deployment

# Create access key
aws iam create-access-key --user-name forge-deployment

# Attach policy (limited permissions)
cat > forge-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "elasticloadbalancing:Describe*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-user-policy \
  --user-name forge-deployment \
  --policy-name ForgeReadOnly \
  --policy-document file://forge-policy.json
```

---

## Step 3: Add Our EC2 Server to Forge

### Option A: Custom VPS (Recommended)

1. In Forge, click **Servers → Create Server**
2. Select **Custom VPS**
3. Fill in details:
   - **Name:** Mysos Production
   - **IP Address:** (our LARAVEL_PUBLIC_IP from aws-resources.env)
   - **SSH Port:** 22
   - **PHP Version:** PHP 8.4
   - **Database:** None (we're using RDS)

4. Copy the SSH public key provided by Forge

5. Add Forge's public key to our EC2:

```bash
source aws-resources.env

ssh -i mysos-titan-key.pem ubuntu@$LARAVEL_PUBLIC_IP

# Add Forge's public key
echo "PASTE_FORGE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys

# OR use Forge's one-line command (they provide this)
# It looks like: sudo su forge -c "echo 'ssh-rsa AAAA...' >> ~/.ssh/authorized_keys"
```

6. Click **Add Server** in Forge
7. Wait 5-10 minutes for Forge to provision

### What Forge Installs:

- Nginx
- PHP 8.4-FPM
- Supervisor
- Node.js & NPM
- Composer
- Git
- Fail2ban (security)
- UFW (firewall)

---

## Step 4: Configure Server Settings

Once provisioned:

### 4.1: Update PHP Settings

1. Go to **Server → PHP**
2. Update `upload_max_filesize` and `post_max_size` if needed
3. Update `memory_limit` to 512M
4. Click **Update PHP Configuration**

### 4.2: Setup Supervisor (for queues)

Forge automatically configures Supervisor, but we'll add workers per site later.

### 4.3: Configure Firewall

Forge configures UFW automatically with these rules:
- Port 22 (SSH)
- Port 80 (HTTP)
- Port 443 (HTTPS)

To add custom ports (for WebSockets):

1. Go to **Server → Network**
2. Under **Firewall Rules**, add:
   - Port: 6001
   - Name: WebSockets
   - Click **Add Rule**

---

## Step 5: Create Sites for Each Laravel App

We need to create 6 sites in Forge:

### 5.1: Create cortex.mysos.co.za (API)

1. Go to **Sites → New Site**
2. Fill in:
   - **Root Domain:** cortex.mysos.co.za
   - **Project Type:** General PHP/Laravel
   - **Web Directory:** /public
   - **PHP Version:** PHP 8.4
   - **Create Database:** No (using RDS)
   - **Wildcard Sub-Domains:** No

3. Click **Add Site**

4. Configure the site:

   **a) Install Repository:**
   - Go to **Site → Apps → Git Repository**
   - Select provider (GitHub/GitLab/Bitbucket)
   - Repository: `your-org/cortex-api`
   - Branch: `main`
   - Install Composer Dependencies: ✅
   - Click **Install Repository**

   **b) Environment Variables:**
   - Go to **Site → Environment**
   - Update .env with our RDS and Redis credentials:

   ```bash
   APP_NAME="Cortex API"
   APP_ENV=production
   APP_KEY=base64:... (generate with php artisan key:generate)
   APP_DEBUG=false
   APP_URL=https://cortex.mysos.co.za

   LOG_CHANNEL=stack
   LOG_LEVEL=error

   DB_CONNECTION=mysql
   DB_HOST=YOUR_RDS_ENDPOINT
   DB_PORT=3306
   DB_DATABASE=mysos_production
   DB_USERNAME=mysos_admin
   DB_PASSWORD=YOUR_DB_PASSWORD

   BROADCAST_DRIVER=redis
   CACHE_DRIVER=redis
   QUEUE_CONNECTION=redis
   SESSION_DRIVER=redis

   REDIS_HOST=YOUR_REDIS_ENDPOINT
   REDIS_PASSWORD=null
   REDIS_PORT=6379
   REDIS_CLIENT=predis
   ```

   - Click **Save**

   **c) Deploy Script:**
   - Go to **Site → Apps → Deployment**
   - Forge's default script is usually perfect:

   ```bash
   cd /home/forge/cortex.mysos.co.za
   git pull origin main
   composer install --no-interaction --prefer-dist --optimize-autoloader
   
   ( flock -w 10 9 || exit 1
       echo 'Restarting FPM...'; sudo -S service php8.4-fpm reload ) 9>/tmp/fpmlock
   
   if [ -f artisan ]; then
       php artisan migrate --force
       php artisan config:cache
       php artisan route:cache
       php artisan view:cache
   fi
   ```

   - Enable **Quick Deploy** (auto-deploy on Git push)

   **d) SSL Certificate:**
   - Go to **Site → SSL**
   - Select **LetsEncrypt**
   - Domains: cortex.mysos.co.za
   - Click **Obtain Certificate**
   - Wait 1-2 minutes
   - Enable **Force HTTPS**

   **e) Queue Worker:**
   - Go to **Site → Queue**
   - Click **Create Worker**
   - Connection: redis
   - Queue: default
   - Processes: 1
   - Max Tries: 3
   - Click **Create**

   **f) Scheduled Jobs:**
   - Go to **Site → Scheduler**
   - Click **Enable Scheduler**
   - This runs Laravel's scheduler every minute

   **g) Deploy:**
   - Go to **Site → Apps**
   - Click **Deploy Now**

### 5.2: Repeat for Other Sites

Create sites for:
- **apex.mysos.co.za** (User Portal)
- **console.mysos.co.za** (Admin Console)
- **app.mysos.co.za** (Mobile Backend)
- **web.mysos.co.za** (Marketing Info)
- **sockets.mysos.co.za** (WebSockets) - Special config below

For each site, repeat the same process:
1. Create site
2. Install repository
3. Configure environment
4. Setup SSL
5. Add queue workers (if needed)
6. Deploy

---

## Step 6: Special Configuration for WebSockets (sockets.mysos.co.za)

### 6.1: Create the Site

Follow the same steps as above, but add these additional configurations:

### 6.2: Nginx Configuration for WebSockets

1. Go to **Site → Nginx → Edit Configuration**
2. Add this location block before the PHP location block:

```nginx
location /socket.io {
    proxy_pass http://127.0.0.1:6001;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 86400;
}
```

3. Click **Save**

### 6.3: Create Daemon for Laravel Echo Server

1. Go to **Site → Daemons → Create Daemon**
2. Fill in:
   - **Command:** `php artisan websockets:serve`
   - **Directory:** `/home/forge/sockets.mysos.co.za`
   - **User:** forge
   - **Processes:** 1
3. Click **Create**

Alternatively, if using Laravel Reverb or Soketi:

```bash
# For Soketi
Command: soketi start
Directory: /home/forge/sockets.mysos.co.za
```

---

## Step 7: Nginx Optimization

For better performance, update the global Nginx config:

1. Go to **Server → Nginx**
2. Click **Edit Default Nginx Configuration**
3. Update these values:

```nginx
# Inside http block
client_max_body_size 100M;
fastcgi_buffers 16 16k;
fastcgi_buffer_size 32k;

# Enable gzip
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;

# Cache static files
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
    expires 365d;
    add_header Cache-Control "public, immutable";
}
```

4. Click **Save**

---

## Step 8: Database Backups to S3

Even though we're using RDS with automatic backups, we can add application-level backups:

1. Create S3 bucket for backups:

```bash
aws s3 mb s3://mysos-forge-backups --region $AWS_REGION
```

2. In Forge, go to **Server → Backup**
3. Configure:
   - **Provider:** AWS S3
   - **Bucket:** mysos-forge-backups
   - **Region:** (our region)
   - **Frequency:** Daily at 2:00 AM
4. Click **Schedule Backup**

---

## Step 9: Security Hardening

### 9.1: Update Forge User Password

```bash
ssh -i mysos-titan-key.pem ubuntu@$LARAVEL_PUBLIC_IP

# Switch to forge user
sudo su - forge

# Change password
passwd
```

### 9.2: Enable Two-Factor Auth in Forge

1. Go to **Account → Authentication**
2. Enable **Two-Factor Authentication**

### 9.3: Restrict SSH to Specific IPs

1. In Forge, go to **Server → Meta**
2. Edit **Allowed IPs**
3. Add our office IP addresses

---

## Step 10: Monitoring in Forge

Forge includes basic monitoring:

1. Go to **Server → Monitoring**
2. View:
   - CPU usage
   - Memory usage
   - Disk space
   - Network traffic

For alerts, we're already using CloudWatch, but Forge can send alerts too:

1. Go to **Server → Notifications**
2. Enable notifications for:
   - High CPU usage
   - High memory usage
   - Low disk space

---

## Daily Workflow with Forge

### Deploying Code Changes

**Option 1: Automatic (Quick Deploy enabled)**
- Push to Git
- Forge automatically deploys

**Option 2: Manual**
- Make changes locally
- Push to Git
- Go to Forge → Site → Apps
- Click **Deploy Now**

### Viewing Logs

1. Go to **Site → Logs**
2. View:
   - Laravel logs
   - Nginx error logs
   - PHP-FPM logs

### Restarting Services

1. Go to **Site → Meta**
2. Click buttons:
   - **Restart Nginx**
   - **Restart PHP-FPM**
   - **Restart Queue Workers**

### Running Artisan Commands

1. Go to **Site → Commands**
2. Enter command: `php artisan cache:clear`
3. Click **Run Command**

---

## Useful Forge Commands (SSH)

```bash
# Switch to forge user
sudo su - forge

# Navigate to site
cd /home/forge/cortex.mysos.co.za

# Run artisan commands
php artisan tinker
php artisan queue:work
php artisan migrate

# View logs
tail -f storage/logs/laravel.log

# Nginx
sudo nginx -t  # Test config
sudo service nginx restart

# PHP-FPM
sudo service php8.4-fpm restart

# Supervisor (queue workers)
sudo supervisorctl status
sudo supervisorctl restart all
```

---

## Troubleshooting

### Site Returns 502 Bad Gateway

```bash
# Check PHP-FPM status
sudo service php8.4-fpm status

# Restart PHP-FPM
sudo service php8.4-fpm restart

# Check PHP-FPM logs
sudo tail -f /var/log/php8.4-fpm.log
```

### Queue Workers Not Processing

```bash
# Check supervisor status
sudo supervisorctl status

# Restart workers
sudo supervisorctl restart all

# View worker logs
cd /home/forge/cortex.mysos.co.za
tail -f storage/logs/worker.log
```

### SSL Certificate Issues

1. Go to **Site → SSL**
2. Click **Revoke & Reissue**
3. Wait for new certificate

### Deployment Fails

1. Go to **Site → Deployment History**
2. Click on failed deployment
3. View error logs
4. Fix issue in code
5. Deploy again

---

## Cost Summary

| Item | Cost |
|------|------|
| Forge Subscription | $19/month |
| EC2 Instance (already counted) | $0 |
| S3 Backups | ~$1/month |
| **Total Additional** | **$20/month** |

**Updated Total AWS Cost:** ~$265/month (still under budget!)

---

## Forge vs Manual Management

| Task | With Forge | Without Forge |
|------|-----------|---------------|
| Deploy code | 1 click | SSH + Git + Composer + Artisan |
| SSL setup | 1 click | certbot + cron + nginx config |
| Queue workers | 1 click | supervisor config files |
| Scheduled jobs | 1 click | crontab -e |
| Zero-downtime | Automatic | Custom scripts |
| Logs | Web UI | SSH + tail |
| Monitoring | Built-in | Custom setup |
| Security updates | Automatic | Manual apt commands |

**Verdict: Forge is absolutely worth $19/month!**

---

## Next Steps After Forge Setup

1. ✅ All Laravel apps deployed via Forge
2. Configure load balancer health checks to hit our Forge sites
3. Test all applications thoroughly
4. Set up staging environment (optional)
5. Configure CI/CD with GitHub Actions to trigger Forge deployments

---

## Forge + AWS Load Balancer Integration

Our architecture:

```
Internet → Route 53 → ALB → EC2 (Forge managed) → RDS + Redis
```

The ALB routes to port 80 on our EC2, where Nginx (managed by Forge) handles the requests and routes them to the correct Laravel site based on domain.

**This is the perfect setup!** We get:
- AWS infrastructure reliability
- Forge deployment ease
- Load balancing and SSL at ALB level
- Easy app management with Forge

---

## Support

- **Forge Docs:** https://forge.laravel.com/docs
- **Forge Support:** support@laravel.com
- **Forge Discord:** https://discord.gg/KxwQuKb
