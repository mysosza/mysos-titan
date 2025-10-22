#!/bin/bash
# Database Migration Tool for Mysos Titan
# Migrates MySQL database from old server to AWS RDS

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Database Migration Tool for Mysos Titan            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Load AWS resources
if [ ! -f "aws-resources.env" ]; then
  echo "❌ aws-resources.env not found. Run setup scripts first."
  exit 1
fi

source aws-resources.env

echo "📋 This script will:"
echo "  1. Backup current database from old server"
echo "  2. Verify backup integrity"
echo "  3. Import to AWS RDS"
echo "  4. Verify import"
echo "  5. Create post-migration snapshot"
echo ""

# Get old database credentials
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Old Database Information"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Old Database Host (e.g., mysql.old-server.com): " OLD_DB_HOST
read -p "Old Database Port [3306]: " OLD_DB_PORT
OLD_DB_PORT=${OLD_DB_PORT:-3306}
read -p "Old Database Name: " OLD_DB_NAME
read -p "Old Database Username: " OLD_DB_USER
read -sp "Old Database Password: " OLD_DB_PASS
echo ""
echo ""

# Confirm
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Migration Plan"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Source:"
echo "  Host: $OLD_DB_HOST:$OLD_DB_PORT"
echo "  Database: $OLD_DB_NAME"
echo "  User: $OLD_DB_USER"
echo ""
echo "Destination:"
echo "  Host: $DB_ENDPOINT:3306"
echo "  Database: $DB_NAME"
echo "  User: $DB_USERNAME"
echo ""
read -p "Proceed with migration? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Migration cancelled."
  exit 0
fi

# Create backup directory
BACKUP_DIR="database-backups"
mkdir -p $BACKUP_DIR
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/mysos_backup_$TIMESTAMP.sql"
BACKUP_FILE_GZ="$BACKUP_FILE.gz"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Backing up old database"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if mysqldump is available
if ! command -v mysqldump &> /dev/null; then
  echo "❌ mysqldump not found. Installing MySQL client..."
  sudo apt-get update
  sudo apt-get install -y mysql-client
fi

echo "⏳ Creating backup... (this may take a few minutes for 5.5GB)"

# Perform backup
mysqldump \
  --host=$OLD_DB_HOST \
  --port=$OLD_DB_PORT \
  --user=$OLD_DB_USER \
  --password="$OLD_DB_PASS" \
  --single-transaction \
  --quick \
  --lock-tables=false \
  --routines \
  --triggers \
  --events \
  --add-drop-table \
  --databases $OLD_DB_NAME \
  --result-file=$BACKUP_FILE

if [ $? -eq 0 ]; then
  echo "✅ Backup created: $BACKUP_FILE"
else
  echo "❌ Backup failed!"
  exit 1
fi

# Get backup size
BACKUP_SIZE=$(du -h $BACKUP_FILE | cut -f1)
echo "📦 Backup size: $BACKUP_SIZE"

# Compress backup
echo "⏳ Compressing backup..."
gzip -c $BACKUP_FILE > $BACKUP_FILE_GZ
COMPRESSED_SIZE=$(du -h $BACKUP_FILE_GZ | cut -f1)
echo "✅ Compressed: $BACKUP_FILE_GZ ($COMPRESSED_SIZE)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Verifying backup integrity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if backup contains data
TABLE_COUNT=$(grep -c "CREATE TABLE" $BACKUP_FILE || true)
echo "✅ Found $TABLE_COUNT tables in backup"

if [ $TABLE_COUNT -eq 0 ]; then
  echo "❌ Backup appears to be empty!"
  exit 1
fi

# Check for common tables (adjust based on your schema)
echo "🔍 Checking for essential tables..."
for table in users companies panic_buttons; do
  if grep -q "CREATE TABLE.*\`$table\`" $BACKUP_FILE; then
    echo "  ✅ Found table: $table"
  else
    echo "  ⚠️  Table not found: $table (might be okay if table name differs)"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Importing to AWS RDS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test connection to RDS
echo "🔌 Testing connection to RDS..."
if mysql -h $DB_ENDPOINT -u $DB_USERNAME -p"$DB_PASSWORD" -e "SELECT 1;" &> /dev/null; then
  echo "✅ Connected to RDS successfully"
else
  echo "❌ Cannot connect to RDS. Check security groups and credentials."
  exit 1
fi

echo "⏳ Importing database to RDS... (this will take several minutes)"
echo ""

# Import to RDS
# Note: Remove the CREATE DATABASE line since we're using an existing database
sed "s/CREATE DATABASE.*\`$OLD_DB_NAME\`/-- &/" $BACKUP_FILE | \
  sed "s/USE \`$OLD_DB_NAME\`/USE \`$DB_NAME\`/" | \
  mysql -h $DB_ENDPOINT -u $DB_USERNAME -p"$DB_PASSWORD" $DB_NAME

if [ $? -eq 0 ]; then
  echo "✅ Import completed successfully"
else
  echo "❌ Import failed!"
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Verifying import"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verify tables were imported
echo "🔍 Checking imported tables..."
RDS_TABLE_COUNT=$(mysql -h $DB_ENDPOINT -u $DB_USERNAME -p"$DB_PASSWORD" $DB_NAME -e "SHOW TABLES;" -s | wc -l)
echo "✅ Found $RDS_TABLE_COUNT tables in RDS"

if [ $RDS_TABLE_COUNT -lt $TABLE_COUNT ]; then
  echo "⚠️  Warning: Table count mismatch!"
  echo "  Backup: $TABLE_COUNT tables"
  echo "  RDS: $RDS_TABLE_COUNT tables"
  read -p "Continue anyway? (yes/no): " CONTINUE
  if [ "$CONTINUE" != "yes" ]; then
    exit 1
  fi
fi

# Check row counts for a few tables
echo ""
echo "📊 Sample row counts:"
for table in users companies panic_buttons; do
  ROW_COUNT=$(mysql -h $DB_ENDPOINT -u $DB_USERNAME -p"$DB_PASSWORD" $DB_NAME -e "SELECT COUNT(*) FROM \`$table\`;" -s -N 2>/dev/null || echo "N/A")
  if [ "$ROW_COUNT" != "N/A" ]; then
    echo "  $table: $ROW_COUNT rows"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Creating RDS snapshot"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SNAPSHOT_ID="mysos-titan-db-post-migration-$TIMESTAMP"
echo "⏳ Creating snapshot: $SNAPSHOT_ID"

aws rds create-db-snapshot \
  --region $AWS_REGION \
  --db-instance-identifier mysos-titan-db \
  --db-snapshot-identifier $SNAPSHOT_ID \
  --tags "Key=Purpose,Value=PostMigration" "Key=Timestamp,Value=$TIMESTAMP"

echo "✅ Snapshot created: $SNAPSHOT_ID"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Post-migration tasks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Run Laravel migrations (optional)
echo "Would you like to run Laravel migrations on the imported database?"
echo "This will apply any pending migrations from your Laravel apps."
read -p "Run migrations? (yes/no): " RUN_MIGRATIONS

if [ "$RUN_MIGRATIONS" == "yes" ]; then
  echo ""
  echo "To run migrations, SSH into your Laravel server and run:"
  echo ""
  echo "  ssh -i $KEY_NAME.pem ubuntu@$LARAVEL_PUBLIC_IP"
  echo "  cd /home/forge/cortex.mysos.co.za"
  echo "  php artisan migrate --force"
  echo ""
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Upload backup to S3 (optional)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Upload backup to S3 for safekeeping? (yes/no): " UPLOAD_S3

if [ "$UPLOAD_S3" == "yes" ]; then
  S3_BUCKET="mysos-database-backups"
  
  # Create bucket if it doesn't exist
  if ! aws s3 ls "s3://$S3_BUCKET" 2>&1 | grep -q "NoSuchBucket"; then
    echo "✅ Bucket exists: s3://$S3_BUCKET"
  else
    echo "⏳ Creating S3 bucket: $S3_BUCKET"
    aws s3 mb "s3://$S3_BUCKET" --region $AWS_REGION
  fi
  
  echo "⏳ Uploading backup to S3..."
  aws s3 cp $BACKUP_FILE_GZ "s3://$S3_BUCKET/"
  
  echo "✅ Backup uploaded to: s3://$S3_BUCKET/$(basename $BACKUP_FILE_GZ)"
  
  # Set lifecycle policy to delete after 30 days
  cat > lifecycle.json << EOF
{
  "Rules": [
    {
      "Id": "DeleteOldBackups",
      "Status": "Enabled",
      "Prefix": "",
      "Expiration": {
        "Days": 30
      }
    }
  ]
}
EOF
  
  aws s3api put-bucket-lifecycle-configuration \
    --bucket $S3_BUCKET \
    --lifecycle-configuration file://lifecycle.json
  
  echo "✅ Lifecycle policy set: backups deleted after 30 days"
  rm lifecycle.json
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            🎉 DATABASE MIGRATION COMPLETE! 🎉                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Migration Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Backup created: $BACKUP_FILE"
echo "✅ Compressed backup: $BACKUP_FILE_GZ"
echo "✅ Tables imported: $RDS_TABLE_COUNT"
echo "✅ RDS Snapshot: $SNAPSHOT_ID"
echo ""
echo "📝 Database Connection Details:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Host: $DB_ENDPOINT"
echo "Port: 3306"
echo "Database: $DB_NAME"
echo "Username: $DB_USERNAME"
echo "Password: $DB_PASSWORD"
echo ""
echo "Connection string:"
echo "mysql -h $DB_ENDPOINT -u $DB_USERNAME -p'$DB_PASSWORD' $DB_NAME"
echo ""
echo "📝 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Update all Laravel .env files with new database credentials"
echo "2. Test database connectivity from Laravel apps"
echo "3. Run migrations if needed: php artisan migrate --force"
echo "4. Clear config cache: php artisan config:cache"
echo "5. Test all applications thoroughly"
echo "6. Monitor performance for 24-48 hours"
echo "7. Keep old database as backup for 1-2 weeks"
echo ""
echo "⚠️  IMPORTANT: Keep these files secure:"
echo "  - $BACKUP_FILE"
echo "  - $BACKUP_FILE_GZ"
echo ""
echo "💡 To restore from this backup:"
echo "  gunzip -c $BACKUP_FILE_GZ | mysql -h $DB_ENDPOINT -u $DB_USERNAME -p'$DB_PASSWORD' $DB_NAME"
echo ""
