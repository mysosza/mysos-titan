#!/bin/bash
# AWS Systems Manager Session Manager Setup
# Secure shell access WITHOUT opening SSH port 22!
set -e

source aws-resources.env

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          AWS Systems Manager Session Manager Setup          ║"
echo "║                                                              ║"
echo "║  Secure shell access without SSH! Close port 22 forever!    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "📋 What this does:"
echo "  - Installs SSM agent on EC2 instances"
echo "  - Configures IAM for SSM access"
echo "  - Enables secure shell via AWS Console/CLI"
echo "  - Allows us to CLOSE SSH port 22!"
echo "  - All sessions logged to CloudWatch"
echo ""
echo "💰 Cost: FREE!"
echo ""

read -p "Continue with SSM setup? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Setup cancelled."
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Updating IAM Role for SSM"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ROLE_NAME="$PROJECT_NAME-ec2-role"

echo "⏳ Attaching SSM managed policy to EC2 role..."

# Attach SSM policy
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

echo "✅ SSM policy attached to role"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Installing/Updating SSM Agent on Instances"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "⏳ Installing SSM agent on Laravel instance..."

# Create install script
cat > install-ssm-agent.sh << 'SSMSCRIPT'
#!/bin/bash
# Install/Update SSM Agent

# Check if Ubuntu (Amazon Linux has it pre-installed)
if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [ "$ID" = "ubuntu" ]; then
    echo "Installing SSM agent on Ubuntu..."
    
    # Download and install
    cd /tmp
    wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
    sudo dpkg -i amazon-ssm-agent.deb
    sudo systemctl enable amazon-ssm-agent
    sudo systemctl start amazon-ssm-agent
    
    echo "SSM agent installed and started"
    sudo systemctl status amazon-ssm-agent --no-pager
  fi
fi
SSMSCRIPT

chmod +x install-ssm-agent.sh

# Install on Laravel instance
echo "  Installing on Laravel instance ($LARAVEL_INSTANCE)..."
scp -i $KEY_NAME.pem -o StrictHostKeyChecking=no install-ssm-agent.sh ubuntu@$LARAVEL_PUBLIC_IP:/tmp/
ssh -i $KEY_NAME.pem -o StrictHostKeyChecking=no ubuntu@$LARAVEL_PUBLIC_IP 'bash /tmp/install-ssm-agent.sh'

echo "✅ SSM agent installed on Laravel instance"

# Install on Node.js instance
echo "  Installing on Node.js instance ($NODEJS_INSTANCE)..."
scp -i $KEY_NAME.pem -o StrictHostKeyChecking=no install-ssm-agent.sh ubuntu@$NODEJS_PUBLIC_IP:/tmp/
ssh -i $KEY_NAME.pem -o StrictHostKeyChecking=no ubuntu@$NODEJS_PUBLIC_IP 'bash /tmp/install-ssm-agent.sh'

echo "✅ SSM agent installed on Node.js instance"

rm install-ssm-agent.sh

echo ""
echo "⏳ Waiting for instances to register with SSM (30 seconds)..."
sleep 30

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Verifying SSM Registration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Checking if instances are managed by SSM..."

# Check Laravel instance
LARAVEL_SSM=$(aws ssm describe-instance-information \
  --region $AWS_REGION \
  --filters "Key=InstanceIds,Values=$LARAVEL_INSTANCE" \
  --query 'InstanceInformationList[0].PingStatus' \
  --output text 2>/dev/null || echo "Not registered")

if [ "$LARAVEL_SSM" == "Online" ]; then
  echo "  ✅ Laravel instance: Online in SSM"
else
  echo "  ⚠️  Laravel instance: $LARAVEL_SSM (may need a few more minutes)"
fi

# Check Node.js instance
NODEJS_SSM=$(aws ssm describe-instance-information \
  --region $AWS_REGION \
  --filters "Key=InstanceIds,Values=$NODEJS_INSTANCE" \
  --query 'InstanceInformationList[0].PingStatus' \
  --output text 2>/dev/null || echo "Not registered")

if [ "$NODEJS_SSM" == "Online" ]; then
  echo "  ✅ Node.js instance: Online in SSM"
else
  echo "  ⚠️  Node.js instance: $NODEJS_SSM (may need a few more minutes)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Configuring Session Manager Logging"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "⏳ Creating S3 bucket for session logs..."

SSM_LOG_BUCKET="mysos-ssm-logs-$(date +%s)"

aws s3 mb s3://$SSM_LOG_BUCKET --region $AWS_REGION

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $SSM_LOG_BUCKET \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "✅ S3 bucket created: $SSM_LOG_BUCKET"

# Create CloudWatch log group
aws logs create-log-group \
  --region $AWS_REGION \
  --log-group-name /aws/ssm/sessions

echo "✅ CloudWatch log group created"

# Configure Session Manager preferences
cat > ssm-preferences.json << EOF
{
  "inputs": {
    "s3BucketName": "$SSM_LOG_BUCKET",
    "s3KeyPrefix": "session-logs/",
    "s3EncryptionEnabled": true,
    "cloudWatchLogGroupName": "/aws/ssm/sessions",
    "cloudWatchEncryptionEnabled": false,
    "idleSessionTimeout": "20",
    "maxSessionDuration": ""
  }
}
EOF

aws ssm create-document \
  --region $AWS_REGION \
  --name SSM-SessionManagerRunShell-$PROJECT_NAME \
  --document-type Session \
  --content file://ssm-preferences.json \
  2>/dev/null || echo "  (Document may already exist)"

echo "✅ Session logging configured"

rm ssm-preferences.json

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Security - Closing SSH Port 22 (Optional)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Now that SSM is active, we can CLOSE SSH port 22!"
echo ""
read -p "Remove SSH (port 22) from security groups? (yes/no): " CLOSE_SSH

if [ "$CLOSE_SSH" == "yes" ]; then
  echo ""
  echo "⏳ Removing SSH ingress rules..."
  
  # Remove SSH from Laravel SG
  aws ec2 revoke-security-group-ingress \
    --region $AWS_REGION \
    --group-id $LARAVEL_SG \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    2>/dev/null || echo "  (Rule may not exist)"
  
  echo "  ✅ Removed SSH from Laravel security group"
  
  # Remove SSH from Node.js SG
  aws ec2 revoke-security-group-ingress \
    --region $AWS_REGION \
    --group-id $NODEJS_SG \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    2>/dev/null || echo "  (Rule may not exist)"
  
  echo "  ✅ Removed SSH from Node.js security group"
  
  # Remove SSH from WebSocket SG if exists
  if [ ! -z "$WEBSOCKET_SG" ]; then
    aws ec2 revoke-security-group-ingress \
      --region $AWS_REGION \
      --group-id $WEBSOCKET_SG \
      --protocol tcp \
      --port 22 \
      --cidr 0.0.0.0/0 \
      2>/dev/null || echo "  (Rule may not exist)"
    
    echo "  ✅ Removed SSH from WebSocket security group"
  fi
  
  echo ""
  echo "🎉 SSH port 22 is now CLOSED! Much more secure!"
else
  echo "⏭  SSH port left open (can close later)"
fi

# Save to env file
cat >> aws-resources.env << EOF
export SSM_LOG_BUCKET=$SSM_LOG_BUCKET
export SSM_ENABLED=true
EOF

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         🎉 Session Manager Setup Complete! 🎉                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 How to Connect to Instances"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Method 1: AWS Console (Easy)"
echo "  1. Go to EC2 Console"
echo "  2. Select instance"
echo "  3. Click 'Connect'"
echo "  4. Choose 'Session Manager'"
echo "  5. Click 'Connect'"
echo ""
echo "Method 2: AWS CLI (Recommended)"
echo ""
echo "  # Connect to Laravel server"
echo "  aws ssm start-session --target $LARAVEL_INSTANCE --region $AWS_REGION"
echo ""
echo "  # Connect to Node.js server"
echo "  aws ssm start-session --target $NODEJS_INSTANCE --region $AWS_REGION"
echo ""
echo "Method 3: Using AWS CLI with local SSH config (Advanced)"
echo "  # One-time setup"
echo "  ssh -i ~/.ssh/id_rsa ubuntu@$LARAVEL_INSTANCE \\"
echo "    -o ProxyCommand=\"aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p\""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Monitoring & Logging"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "All sessions are logged to:"
echo "  - S3: s3://$SSM_LOG_BUCKET/session-logs/"
echo "  - CloudWatch: /aws/ssm/sessions"
echo ""
echo "View session history:"
echo "  aws ssm describe-sessions --state History --region $AWS_REGION"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Benefits Achieved"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ "$CLOSE_SSH" == "yes" ]; then
  echo "✅ SSH port 22 closed - NO MORE SSH BRUTE FORCE ATTACKS!"
fi
echo "✅ Secure shell access via IAM permissions"
echo "✅ All sessions logged and auditable"
echo "✅ No SSH keys needed"
echo "✅ No bastion host required"
echo "✅ Works from anywhere with AWS CLI"
echo "✅ Automatic timeout after inactivity"
echo "✅ CloudTrail logging of who accessed what"
echo ""
echo "💰 Cost: FREE! (just S3 storage ~$0.50/month)"
echo ""
echo "📝 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Test connection: aws ssm start-session --target $LARAVEL_INSTANCE"
echo "2. Update team on new access method"
echo "3. Install AWS CLI + Session Manager plugin on team workstations"
echo "4. Remove old SSH keys from laptops"
echo "5. Update runbooks with SSM commands"
echo ""
echo "🔧 Install Session Manager Plugin:"
echo "  macOS: brew install --cask session-manager-plugin"
echo "  Linux: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
echo ""
echo "💡 Pro Tips:"
echo "  - Create IAM users for team members"
echo "  - Grant ssm:StartSession permission"
echo "  - Use IAM roles for fine-grained access control"
echo "  - Review session logs regularly"
echo ""
