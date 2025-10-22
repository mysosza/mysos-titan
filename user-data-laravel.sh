#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install PHP 8.4 and extensions
add-apt-repository ppa:ondrej/php -y
apt-get update
apt-get install -y php8.4 php8.4-fpm php8.4-cli php8.4-common php8.4-mysql \
  php8.4-zip php8.4-gd php8.4-mbstring php8.4-curl php8.4-xml php8.4-bcmath \
  php8.4-redis php8.4-intl php8.4-soap

# Install Nginx
apt-get install -y nginx

# Install Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Install Supervisor (for queue workers)
apt-get install -y supervisor

# Install Node.js (for Laravel Mix/Vite if needed)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install MySQL client
apt-get install -y mysql-client

# Install Redis CLI
apt-get install -y redis-tools

# Configure PHP-FPM
sed -i 's/pm.max_children = 5/pm.max_children = 50/' /etc/php/8.4/fpm/pool.d/www.conf
sed -i 's/pm.start_servers = 2/pm.start_servers = 10/' /etc/php/8.4/fpm/pool.d/www.conf
sed -i 's/pm.min_spare_servers = 1/pm.min_spare_servers = 5/' /etc/php/8.4/fpm/pool.d/www.conf
sed -i 's/pm.max_spare_servers = 3/pm.max_spare_servers = 15/' /etc/php/8.4/fpm/pool.d/www.conf

# Create web directory
mkdir -p /var/www
chown -R www-data:www-data /var/www

# Configure Nginx default site (Forge will manage this)
cat > /etc/nginx/sites-available/default << 'NGINX'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/default/public;
    
    index index.php index.html;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
NGINX

# Restart services
systemctl restart php8.4-fpm
systemctl restart nginx
systemctl enable supervisor
systemctl start supervisor

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

echo "✅ Laravel server setup complete!"
