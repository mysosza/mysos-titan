#!/bin/bash
# RDS MySQL Setup for mysos-titan
set -e

source aws-resources.env

echo "🗄️  Creating RDS MySQL Database..."

# Variables
DB_INSTANCE_ID="mysos-titan-db"
DB_NAME="mysos_production"
DB_USERNAME="mysos_admin"
DB_PASSWORD="$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)"  # Generate secure password

# Create DB Subnet Group
aws rds create-db-subnet-group \
  --region $AWS_REGION \
  --db-subnet-group-name "$PROJECT_NAME-db-subnet" \
  --db-subnet-group-description "Subnet group for mysos RDS" \
  --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2 \
  --tags "Key=Name,Value=$PROJECT_NAME-db-subnet"

echo "✅ DB Subnet Group Created"

# Create RDS MySQL Instance
aws rds create-db-instance \
  --region $AWS_REGION \
  --db-instance-identifier $DB_INSTANCE_ID \
  --db-instance-class db.t3.small \
  --engine mysql \
  --engine-version 8.0.43 \
  --master-username $DB_USERNAME \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 20 \
  --storage-type gp3 \
  --storage-encrypted \
  --vpc-security-group-ids $RDS_SG \
  --db-subnet-group-name "$PROJECT_NAME-db-subnet" \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00" \
  --preferred-maintenance-window "mon:04:00-mon:05:00" \
  --no-multi-az \
  --no-publicly-accessible \
  --tags "Key=Name,Value=$PROJECT_NAME-rds" "Key=Environment,Value=production"

echo "✅ RDS Instance Created: $DB_INSTANCE_ID"
echo "⏳ Waiting for RDS instance to become available (this takes 5-10 minutes)..."

# Wait for RDS to be available
aws rds wait db-instance-available \
  --region $AWS_REGION \
  --db-instance-identifier $DB_INSTANCE_ID

# Get RDS endpoint
DB_ENDPOINT=$(aws rds describe-db-instances \
  --region $AWS_REGION \
  --db-instance-identifier $DB_INSTANCE_ID \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "✅ RDS Instance Available!"
echo ""
echo "📝 Database Connection Details:"
echo "Endpoint: $DB_ENDPOINT"
echo "Port: 3306"
echo "Username: $DB_USERNAME"
echo "Password: $DB_PASSWORD"
echo "Database: $DB_NAME"
echo ""
echo "⚠️  IMPORTANT: Save these credentials securely!"
echo ""

# Save to env file
cat >> aws-resources.env << EOF
export DB_ENDPOINT=$DB_ENDPOINT
export DB_NAME=$DB_NAME
export DB_USERNAME=$DB_USERNAME
export DB_PASSWORD="$DB_PASSWORD"
EOF

# Create .env snippet for Laravel
cat > laravel-db-config.txt << EOF
DB_CONNECTION=mysql
DB_HOST=$DB_ENDPOINT
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
EOF

echo "✅ Laravel .env database config saved to laravel-db-config.txt"
echo ""
echo "🔄 Next steps for database migration:"
echo "1. Export data from current MySQL database"
echo "2. Import to RDS using: mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD < backup.sql"
echo "3. Or use mysqldump: mysqldump -h old_host -u old_user -p old_db | mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME"
