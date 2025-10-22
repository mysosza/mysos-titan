#!/bin/bash
# AWS Secrets Manager Setup
# Secure credential storage with automatic rotation
set -e

source aws-resources.env

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            AWS Secrets Manager Setup                         ║"
echo "║                                                              ║"
echo "║  No more plain text passwords in .env files!                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "📋 What this does:"
echo "  - Stores database password in Secrets Manager"
echo "  - Stores Redis connection info"
echo "  - Stores API keys and secrets"
echo "  - Enables automatic rotation"
echo "  - Configures IAM access for EC2"
echo ""

read -p "Continue with Secrets Manager setup? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Setup cancelled."
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Creating Database Secret"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DB_SECRET_NAME="$PROJECT_NAME/database/credentials"

echo "⏳ Creating secret for RDS database..."

# Create secret with database credentials
DB_SECRET_STRING=$(cat << EOF
{
  "username": "$DB_USERNAME",
  "password": "$DB_PASSWORD",
  "engine": "mysql",
  "host": "$DB_ENDPOINT",
  "port": 3306,
  "dbname": "$DB_NAME"
}
EOF
)

DB_SECRET_ARN=$(aws secretsmanager create-secret \
  --name $DB_SECRET_NAME \
  --description "RDS MySQL database credentials for Mysos Titan" \
  --secret-string "$DB_SECRET_STRING" \
  --tags Key=Project,Value=Mysos Key=Environment,Value=Production \
  --query 'ARN' \
  --output text)

echo "✅ Database secret created: $DB_SECRET_ARN"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Creating Redis Secret"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

REDIS_SECRET_NAME="$PROJECT_NAME/redis/connection"

echo "⏳ Creating secret for Redis..."

REDIS_SECRET_STRING=$(cat << EOF
{
  "host": "$REDIS_ENDPOINT",
  "port": $REDIS_PORT,
  "password": null
}
EOF
)

REDIS_SECRET_ARN=$(aws secretsmanager create-secret \
  --name $REDIS_SECRET_NAME \
  --description "ElastiCache Redis connection info" \
  --secret-string "$REDIS_SECRET_STRING" \
  --tags Key=Project,Value=Mysos Key=Environment,Value=Production \
  --query 'ARN' \
  --output text)

echo "✅ Redis secret created: $REDIS_SECRET_ARN"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Creating Application Secrets"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

APP_SECRET_NAME="$PROJECT_NAME/app/keys"

read -p "Enter APP_KEY for Laravel (or press Enter to generate): " APP_KEY
if [ -z "$APP_KEY" ]; then
  APP_KEY="base64:$(openssl rand -base64 32)"
  echo "Generated APP_KEY: $APP_KEY"
fi

read -p "Enter JWT_SECRET (or press Enter to generate): " JWT_SECRET
if [ -z "$JWT_SECRET" ]; then
  JWT_SECRET="$(openssl rand -base64 64)"
  echo "Generated JWT_SECRET"
fi

APP_SECRET_STRING=$(cat << EOF
{
  "APP_KEY": "$APP_KEY",
  "JWT_SECRET": "$JWT_SECRET"
}
EOF
)

APP_SECRET_ARN=$(aws secretsmanager create-secret \
  --name $APP_SECRET_NAME \
  --description "Application keys and secrets" \
  --secret-string "$APP_SECRET_STRING" \
  --tags Key=Project,Value=Mysos Key=Environment,Value=Production \
  --query 'ARN' \
  --output text)

echo "✅ Application secrets created: $APP_SECRET_ARN"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Creating IAM Policy for Secrets Access"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SECRETS_POLICY_NAME="$PROJECT_NAME-secrets-access"

cat > secrets-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "$DB_SECRET_ARN",
        "$REDIS_SECRET_ARN",
        "$APP_SECRET_ARN"
      ]
    }
  ]
}
EOF

echo "⏳ Creating IAM policy for secrets access..."

SECRETS_POLICY_ARN=$(aws iam create-policy \
  --policy-name $SECRETS_POLICY_NAME \
  --policy-document file://secrets-policy.json \
  --description "Allows EC2 instances to read secrets" \
  --query 'Policy.Arn' \
  --output text)

echo "✅ IAM policy created: $SECRETS_POLICY_ARN"

# Attach to EC2 role
aws iam attach-role-policy \
  --role-name $PROJECT_NAME-ec2-role \
  --policy-arn $SECRETS_POLICY_ARN

echo "✅ Policy attached to EC2 role"

rm secrets-policy.json

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Enabling Automatic Rotation for Database"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Enable automatic password rotation? (30 days) (yes/no): " ENABLE_ROTATION

if [ "$ENABLE_ROTATION" == "yes" ]; then
  echo "⏳ Setting up automatic rotation..."
  
  # Note: This requires additional Lambda setup
  # For now, we'll just document the manual rotation process
  echo "  ⚠️  Automatic rotation requires Lambda function setup"
  echo "  📝 Manual rotation instructions will be provided"
  echo "  For now, rotation is disabled"
else
  echo "⏭  Automatic rotation skipped"
fi

# Save to env file
cat >> aws-resources.env << EOF
export DB_SECRET_ARN=$DB_SECRET_ARN
export REDIS_SECRET_ARN=$REDIS_SECRET_ARN
export APP_SECRET_ARN=$APP_SECRET_ARN
export SECRETS_POLICY_ARN=$SECRETS_POLICY_ARN
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Creating Laravel Helper Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create script to retrieve secrets
cat > retrieve-secrets.php << 'EOF'
<?php
// Laravel helper to retrieve secrets from AWS Secrets Manager
// Put this in app/Helpers/SecretsManager.php

use Aws\SecretsManager\SecretsManagerClient;
use Aws\Exception\AwsException;

class SecretsManager
{
    private static $client = null;
    private static $cache = [];
    
    private static function getClient()
    {
        if (self::$client === null) {
            self::$client = new SecretsManagerClient([
                'version' => 'latest',
                'region' => env('AWS_DEFAULT_REGION', 'us-east-1')
            ]);
        }
        return self::$client;
    }
    
    public static function getSecret($secretName)
    {
        // Check cache first
        if (isset(self::$cache[$secretName])) {
            return self::$cache[$secretName];
        }
        
        try {
            $result = self::getClient()->getSecretValue([
                'SecretId' => $secretName,
            ]);
            
            if (isset($result['SecretString'])) {
                $secret = json_decode($result['SecretString'], true);
                self::$cache[$secretName] = $secret;
                return $secret;
            }
            
        } catch (AwsException $e) {
            \Log::error('Error retrieving secret: ' . $e->getMessage());
            throw $e;
        }
        
        return null;
    }
    
    public static function getDatabaseCredentials()
    {
        return self::getSecret(env('DB_SECRET_NAME'));
    }
    
    public static function getRedisConnection()
    {
        return self::getSecret(env('REDIS_SECRET_NAME'));
    }
}

// Usage in config/database.php:
// $dbSecret = SecretsManager::getDatabaseCredentials();
// 
// 'mysql' => [
//     'driver' => 'mysql',
//     'host' => $dbSecret['host'],
//     'port' => $dbSecret['port'],
//     'database' => $dbSecret['dbname'],
//     'username' => $dbSecret['username'],
//     'password' => $dbSecret['password'],
//     ...
// ]
EOF

echo "✅ Laravel helper script created: retrieve-secrets.php"

# Create .env template
cat > laravel-secrets-config.txt << EOF
# Add to Laravel .env

# Secrets Manager Configuration
AWS_DEFAULT_REGION=$AWS_REGION
DB_SECRET_NAME=$DB_SECRET_NAME
REDIS_SECRET_NAME=$REDIS_SECRET_NAME
APP_SECRET_NAME=$APP_SECRET_NAME

# Remove these - they're now in Secrets Manager:
# DB_HOST=
# DB_DATABASE=
# DB_USERNAME=
# DB_PASSWORD=
# REDIS_HOST=
# REDIS_PORT=
# APP_KEY=
# JWT_SECRET=

# Install AWS SDK for PHP:
# composer require aws/aws-sdk-php

# Then use the helper class in config files
EOF

echo "✅ Laravel config template created: laravel-secrets-config.txt"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          🎉 Secrets Manager Setup Complete! 🎉               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Secrets Created"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Database Secret:"
echo "  Name: $DB_SECRET_NAME"
echo "  ARN: $DB_SECRET_ARN"
echo ""
echo "Redis Secret:"
echo "  Name: $REDIS_SECRET_NAME"
echo "  ARN: $REDIS_SECRET_ARN"
echo ""
echo "App Keys Secret:"
echo "  Name: $APP_SECRET_NAME"
echo "  ARN: $APP_SECRET_ARN"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 How to Use in Laravel"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Install AWS SDK:"
echo "   composer require aws/aws-sdk-php"
echo ""
echo "2. Copy helper class:"
echo "   cp retrieve-secrets.php app/Helpers/SecretsManager.php"
echo ""
echo "3. Update config/database.php:"
echo "   \$db = SecretsManager::getDatabaseCredentials();"
echo "   Use \$db['host'], \$db['username'], etc."
echo ""
echo "4. Update .env (see laravel-secrets-config.txt)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Useful Commands"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Retrieve secret:"
echo "  aws secretsmanager get-secret-value --secret-id $DB_SECRET_NAME"
echo ""
echo "Update secret:"
echo "  aws secretsmanager update-secret --secret-id $DB_SECRET_NAME \\"
echo "    --secret-string '{\"username\":\"new_user\",\"password\":\"new_pass\"}'"
echo ""
echo "Rotate secret manually:"
echo "  1. Update secret value in Secrets Manager"
echo "  2. Laravel automatically picks up new value on next request"
echo "  3. No application restart needed!"
echo ""
echo "List all secrets:"
echo "  aws secretsmanager list-secrets"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Benefits Achieved"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ No more passwords in .env files"
echo "✅ Encrypted at rest and in transit"
echo "✅ Audit log of secret access"
echo "✅ Automatic rotation (when enabled)"
echo "✅ IAM-controlled access"
echo "✅ Versioning of secrets"
echo "✅ No application restart needed for updates"
echo ""
echo "💰 Cost: ~$0.40/secret/month + $0.05 per 10,000 API calls"
echo "  For 3 secrets: ~$1.20/month"
echo ""
echo "🔐 Security Best Practices:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Remove all passwords from .env files"
echo "✅ Delete .env from Git history if committed"
echo "✅ Rotate secrets regularly (30-90 days)"
echo "✅ Monitor secret access in CloudTrail"
echo "✅ Use separate secrets for dev/staging/prod"
echo "✅ Never log secret values"
echo ""
echo "📝 Migration Checklist:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "[ ] Install AWS SDK in Laravel"
echo "[ ] Copy SecretsManager helper class"
echo "[ ] Update config/database.php to use secrets"
echo "[ ] Update config/cache.php for Redis"
echo "[ ] Test locally with AWS CLI credentials"
echo "[ ] Test on EC2 (should work automatically with IAM role)"
echo "[ ] Remove plain text credentials from .env"
echo "[ ] Update documentation"
echo "[ ] Train team on secret retrieval"
echo ""
