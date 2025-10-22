#!/bin/bash
# EC2 Laravel Instances Setup for mysos-titan
set -e

source aws-resources.env

echo "🚀 Creating EC2 Instances for Laravel Apps..."

# Variables
KEY_NAME="mysos-titan-key"
INSTANCE_TYPE="t3.large"  # 2 vCPU, 8GB RAM

# Create SSH Key Pair if it doesn't exist
if ! aws ec2 describe-key-pairs --region $AWS_REGION --key-names $KEY_NAME &>/dev/null; then
  aws ec2 create-key-pair \
    --region $AWS_REGION \
    --key-name $KEY_NAME \
    --query 'KeyMaterial' \
    --output text > $KEY_NAME.pem
  
  chmod 400 $KEY_NAME.pem
  echo "✅ SSH Key Created: $KEY_NAME.pem"
  echo "⚠️  IMPORTANT: Save this key file securely!"
else
  echo "✅ SSH Key already exists: $KEY_NAME"
fi

# Get latest Ubuntu 22.04 AMI
AMI_ID=$(aws ec2 describe-images \
  --region $AWS_REGION \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

echo "✅ Using Ubuntu AMI: $AMI_ID"

# User Data Script for Laravel Server Setup
cat > user-data-laravel.sh << 'USERDATA'
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
USERDATA

# Create IAM Role for EC2 (for CloudWatch access)
ROLE_NAME="$PROJECT_NAME-ec2-role"

# Check if role exists
if ! aws iam get-role --role-name $ROLE_NAME &>/dev/null; then
  # Create trust policy
  cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json

  # Attach CloudWatch policy
  aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

  # Create instance profile
  aws iam create-instance-profile \
    --instance-profile-name $ROLE_NAME

  aws iam add-role-to-instance-profile \
    --instance-profile-name $ROLE_NAME \
    --role-name $ROLE_NAME

  echo "✅ IAM Role Created: $ROLE_NAME"
  sleep 10  # Wait for IAM propagation
else
  echo "✅ IAM Role already exists: $ROLE_NAME"
fi

# Launch Laravel EC2 Instance
LARAVEL_INSTANCE=$(aws ec2 run-instances \
  --region $AWS_REGION \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $LARAVEL_SG \
  --subnet-id $PUBLIC_SUBNET_1 \
  --iam-instance-profile Name=$ROLE_NAME \
  --user-data file://user-data-laravel.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$PROJECT_NAME-laravel-1},{Key=Type,Value=laravel}]" \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":50,\"VolumeType\":\"gp3\"}}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ Laravel Instance Launched: $LARAVEL_INSTANCE"
echo "⏳ Waiting for instance to be running..."

# Wait for instance to be running
aws ec2 wait instance-running \
  --region $AWS_REGION \
  --instance-ids $LARAVEL_INSTANCE

# Get instance details
LARAVEL_PUBLIC_IP=$(aws ec2 describe-instances \
  --region $AWS_REGION \
  --instance-ids $LARAVEL_INSTANCE \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

LARAVEL_PRIVATE_IP=$(aws ec2 describe-instances \
  --region $AWS_REGION \
  --instance-ids $LARAVEL_INSTANCE \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

echo "✅ Instance Running!"
echo ""
echo "📝 Laravel Instance Details:"
echo "Instance ID: $LARAVEL_INSTANCE"
echo "Public IP: $LARAVEL_PUBLIC_IP"
echo "Private IP: $LARAVEL_PRIVATE_IP"
echo ""
echo "SSH: ssh -i $KEY_NAME.pem ubuntu@$LARAVEL_PUBLIC_IP"
echo ""

# Register instance with all Laravel target groups
echo "📝 Registering instance with target groups..."

for TG in $TG_CORTEX $TG_APEX $TG_CONSOLE $TG_APP $TG_WEB $TG_SOCKETS; do
  aws elbv2 register-targets \
    --region $AWS_REGION \
    --target-group-arn $TG \
    --targets Id=$LARAVEL_INSTANCE
  echo "✅ Registered with target group: $TG"
done

# Save to env file
cat >> aws-resources.env << EOF
export KEY_NAME=$KEY_NAME
export LARAVEL_INSTANCE=$LARAVEL_INSTANCE
export LARAVEL_PUBLIC_IP=$LARAVEL_PUBLIC_IP
export LARAVEL_PRIVATE_IP=$LARAVEL_PRIVATE_IP
EOF

echo ""
echo "🎉 Laravel EC2 Setup Complete!"
echo ""
echo "Next steps:"
echo "1. SSH into instance: ssh -i $KEY_NAME.pem ubuntu@$LARAVEL_PUBLIC_IP"
echo "2. Add server to Laravel Forge"
echo "3. Deploy Laravel apps via Forge"
echo "4. Configure Nginx sites for each app domain"
