#!/bin/bash
# S3 Storage for Laravel File System
# Essential for horizontal scaling and durability
set -e

source aws-resources.env

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            S3 Storage Setup for Laravel Apps                ║"
echo "║                                                              ║"
echo "║  Shared file storage across all Laravel instances           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "📋 What this creates:"
echo "  - S3 bucket for Laravel storage"
echo "  - Separate folders for each app"
echo "  - IAM policy for EC2 access"
echo "  - CloudFront distribution (optional)"
echo "  - Lifecycle policies for cost optimization"
echo ""

read -p "Continue with S3 setup? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Setup cancelled."
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Creating S3 Bucket"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

S3_BUCKET="mysos-laravel-storage-$(date +%s)"

echo "⏳ Creating S3 bucket: $S3_BUCKET"

aws s3 mb s3://$S3_BUCKET --region $AWS_REGION

# Enable versioning (for important files)
aws s3api put-bucket-versioning \
  --bucket $S3_BUCKET \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $S3_BUCKET \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket $S3_BUCKET \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "✅ S3 bucket created: $S3_BUCKET"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Creating Folder Structure"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create folders for each Laravel app
APPS=("cortex" "apex" "console" "app" "web" "sockets")

for app in "${APPS[@]}"; do
  aws s3api put-object \
    --bucket $S3_BUCKET \
    --key "$app/" \
    --content-length 0
  
  # Create subfolders
  for folder in "public" "private" "temp"; do
    aws s3api put-object \
      --bucket $S3_BUCKET \
      --key "$app/$folder/" \
      --content-length 0
  done
  
  echo "  ✅ Created folders for $app"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Creating IAM Policy for EC2 Access"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

POLICY_NAME="$PROJECT_NAME-s3-storage-policy"

cat > s3-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::$S3_BUCKET"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::$S3_BUCKET/*"
    }
  ]
}
EOF

echo "⏳ Creating IAM policy..."

POLICY_ARN=$(aws iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://s3-policy.json \
  --description "S3 access for Laravel storage" \
  --query 'Policy.Arn' \
  --output text)

echo "✅ IAM policy created: $POLICY_ARN"

# Attach policy to EC2 role
aws iam attach-role-policy \
  --role-name $PROJECT_NAME-ec2-role \
  --policy-arn $POLICY_ARN

echo "✅ Policy attached to EC2 role"

rm s3-policy.json

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Setting Up Lifecycle Policies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat > lifecycle.json << EOF
{
  "Rules": [
    {
      "Id": "Move temp files to IA after 30 days",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "*/temp/"
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        }
      ]
    },
    {
      "Id": "Delete temp files after 90 days",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "*/temp/"
      },
      "Expiration": {
        "Days": 90
      }
    },
    {
      "Id": "Delete old versions after 30 days",
      "Status": "Enabled",
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 30
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket $S3_BUCKET \
  --lifecycle-configuration file://lifecycle.json

echo "✅ Lifecycle policies applied"

rm lifecycle.json

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: CloudFront Distribution (Optional)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Create CloudFront CDN for public files? (Recommended) (yes/no): " CREATE_CDN

if [ "$CREATE_CDN" == "yes" ]; then
  echo "⏳ Creating CloudFront distribution..."
  
  # Create Origin Access Identity
  OAI_OUTPUT=$(aws cloudfront create-cloud-front-origin-access-identity \
    --cloud-front-origin-access-identity-config \
      CallerReference=$(date +%s),Comment="OAI for $S3_BUCKET")
  
  OAI_ID=$(echo $OAI_OUTPUT | jq -r '.CloudFrontOriginAccessIdentity.Id')
  
  # Create bucket policy for CloudFront
  cat > cloudfront-bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOAI",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity $OAI_ID"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$S3_BUCKET/*/public/*"
    }
  ]
}
EOF
  
  aws s3api put-bucket-policy \
    --bucket $S3_BUCKET \
    --policy file://cloudfront-bucket-policy.json
  
  # Create CloudFront distribution
  cat > cloudfront-config.json << EOF
{
  "CallerReference": "$(date +%s)",
  "Comment": "CDN for Mysos Laravel storage",
  "Enabled": true,
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-$S3_BUCKET",
        "DomainName": "$S3_BUCKET.s3.$AWS_REGION.amazonaws.com",
        "S3OriginConfig": {
          "OriginAccessIdentity": "origin-access-identity/cloudfront/$OAI_ID"
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-$S3_BUCKET",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"]
    },
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000,
    "Compress": true,
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    }
  }
}
EOF
  
  CDN_OUTPUT=$(aws cloudfront create-distribution \
    --distribution-config file://cloudfront-config.json)
  
  CDN_ID=$(echo $CDN_OUTPUT | jq -r '.Distribution.Id')
  CDN_DOMAIN=$(echo $CDN_OUTPUT | jq -r '.Distribution.DomainName')
  
  echo "✅ CloudFront distribution created"
  echo "   ID: $CDN_ID"
  echo "   Domain: $CDN_DOMAIN"
  echo "   (Distribution takes 15-20 minutes to deploy)"
  
  rm cloudfront-bucket-policy.json cloudfront-config.json
  
  # Save to env
  echo "export CDN_ID=$CDN_ID" >> aws-resources.env
  echo "export CDN_DOMAIN=$CDN_DOMAIN" >> aws-resources.env
else
  echo "⏭  CloudFront skipped"
fi

# Save to env file
cat >> aws-resources.env << EOF
export S3_BUCKET=$S3_BUCKET
export S3_POLICY_ARN=$POLICY_ARN
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Creating Laravel Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create Laravel .env config
cat > laravel-s3-config.txt << EOF
# Add to Laravel .env files

# S3 Configuration
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=$AWS_REGION
AWS_BUCKET=$S3_BUCKET
AWS_USE_PATH_STYLE_ENDPOINT=false

# Filesystem disk (in config/filesystems.php, use 's3' disk)
FILESYSTEM_DISK=s3

EOF

if [ "$CREATE_CDN" == "yes" ]; then
  cat >> laravel-s3-config.txt << EOF
# CloudFront CDN URL
AWS_URL=https://$CDN_DOMAIN

EOF
fi

cat >> laravel-s3-config.txt << EOF
# NOTE: EC2 instances use IAM role, so no need for AWS keys!
# Remove AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY if running on EC2

# Usage in Laravel:
# Storage::disk('s3')->put('file.jpg', \$contents);
# \$url = Storage::disk('s3')->url('file.jpg');
EOF

echo "✅ Laravel config saved to: laravel-s3-config.txt"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            🎉 S3 Storage Setup Complete! 🎉                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 S3 Storage Details"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Bucket Name: $S3_BUCKET"
echo "Region: $AWS_REGION"
if [ "$CREATE_CDN" == "yes" ]; then
  echo "CloudFront: $CDN_DOMAIN"
fi
echo ""
echo "Folder Structure:"
echo "  s3://$S3_BUCKET/"
echo "    ├── cortex/public/    (user uploads)"
echo "    ├── cortex/private/   (protected files)"
echo "    ├── apex/public/"
echo "    ├── console/public/"
echo "    └── ..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Laravel Configuration Steps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Install AWS SDK in Laravel:"
echo "   composer require league/flysystem-aws-s3-v3 \"^3.0\" --with-all-dependencies"
echo ""
echo "2. Update .env (see laravel-s3-config.txt):"
echo "   AWS_BUCKET=$S3_BUCKET"
echo "   AWS_DEFAULT_REGION=$AWS_REGION"
echo "   FILESYSTEM_DISK=s3"
echo ""
echo "3. Update config/filesystems.php:"
echo "   's3' => ["
echo "       'driver' => 's3',"
echo "       'key' => env('AWS_ACCESS_KEY_ID'),"
echo "       'secret' => env('AWS_SECRET_ACCESS_KEY'),"
echo "       'region' => env('AWS_DEFAULT_REGION'),"
echo "       'bucket' => env('AWS_BUCKET'),"
echo "   ]"
echo ""
echo "4. Use in code:"
echo "   Storage::disk('s3')->put('avatars/user.jpg', \$file);"
echo "   \$url = Storage::disk('s3')->url('avatars/user.jpg');"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Benefits Achieved"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Shared storage across all Laravel instances"
echo "✅ Can now scale horizontally (multiple EC2s)"
echo "✅ 99.999999999% durability (11 nines!)"
echo "✅ Automatic backups (versioning enabled)"
echo "✅ Lifecycle policies reduce costs"
echo "✅ Encryption at rest"
if [ "$CREATE_CDN" == "yes" ]; then
  echo "✅ CloudFront CDN for fast global delivery"
fi
echo ""
echo "💰 Cost Estimate:"
echo "  - S3 storage: ~$0.023/GB/month"
echo "  - For 10GB: ~$0.23/month"
echo "  - For 100GB: ~$2.30/month"
if [ "$CREATE_CDN" == "yes" ]; then
  echo "  - CloudFront: ~$0.085/GB data transfer"
fi
echo ""
echo "📊 Monitoring:"
echo "  aws s3 ls s3://$S3_BUCKET --recursive --human-readable --summarize"
echo ""
echo "🔧 Useful Commands:"
echo "  # List files"
echo "  aws s3 ls s3://$S3_BUCKET/cortex/public/"
echo ""
echo "  # Sync local to S3"
echo "  aws s3 sync ./storage/app/public s3://$S3_BUCKET/cortex/public/"
echo ""
echo "  # Download file"
echo "  aws s3 cp s3://$S3_BUCKET/cortex/public/file.jpg ./file.jpg"
echo ""
echo "Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Install AWS SDK in all Laravel apps"
echo "2. Update .env files with S3 config"
echo "3. Test file uploads"
echo "4. Migrate existing files to S3"
echo "5. Update any hardcoded file paths"
echo ""
