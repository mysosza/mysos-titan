# Node.js Panic Button TCP Server Deployment Guide

## 1. Copy Your Apps to the Server

```bash
# From your local machine
scp -i mysos-titan-key.pem -r ./panicbutton-app-* ubuntu@None:/opt/panicbuttons/
```

## 2. SSH into the server

```bash
ssh -i mysos-titan-key.pem ubuntu@None
```

## 3. Setup Each App with PM2

```bash
cd /opt/panicbuttons

# Install dependencies for each app
for app in panicbutton-app-*; do
  cd /opt/panicbuttons/$app
  npm install --production
done

# Create PM2 ecosystem file
cat > /opt/panicbuttons/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      name: 'panicbutton-1',
      script: './panicbutton-app-1/server.js',
      instances: 1,
      exec_mode: 'fork',
      env: {
        PORT: 4000,
        REDIS_HOST: 'YOUR_REDIS_ENDPOINT',
        REDIS_PORT: 6379,
        NODE_ENV: 'production'
      }
    },
    {
      name: 'panicbutton-2',
      script: './panicbutton-app-2/server.js',
      instances: 1,
      exec_mode: 'fork',
      env: {
        PORT: 4001,
        REDIS_HOST: 'YOUR_REDIS_ENDPOINT',
        REDIS_PORT: 6379,
        NODE_ENV: 'production'
      }
    },
    // Add remaining 8 apps with ports 4002-4009
  ]
};
EOF

# Start all apps
pm2 start ecosystem.config.js

# Save PM2 process list
pm2 save

# View logs
pm2 logs

# Monitor apps
pm2 monit
```

## 4. Verify Apps are Running

```bash
# Check if apps are listening
netstat -tlnp | grep node

# Test connection
telnet localhost 4000
```

## 5. Configure Auto-restart on Reboot

```bash
pm2 startup
# Follow the instructions from the output
pm2 save
```

## PM2 Useful Commands

```bash
pm2 list                    # List all apps
pm2 restart all             # Restart all apps
pm2 stop all                # Stop all apps
pm2 logs                    # View logs
pm2 logs panicbutton-1      # View specific app logs
pm2 monit                   # Monitor CPU/Memory
pm2 describe panicbutton-1  # Detailed info
```
