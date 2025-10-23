# AWS SQS Migration Guide

**Migration from IronMQ to AWS SQS for MySOS Titan Infrastructure**

## Executive Summary

This guide documents the migration from IronMQ (external paid service) to AWS SQS (Simple Queue Service) for all MySOS Laravel applications.

### Benefits
- **Cost Savings**: $588-1,188/year (from $49-99/month to $0-1/month)
- **AWS Native Integration**: Better integration with existing AWS infrastructure
- **High Availability**: 99.9% SLA
- **No External Dependencies**: Everything within AWS ecosystem
- **Free Tier**: 1 million requests/month included

### Impact
- **Applications Affected**: Cerebrum, Neo, Portal, App, Web, Sockets
- **Downtime Required**: None (gradual migration supported)
- **Rollback**: Easy (keep IronMQ credentials until confirmed stable)

---

## Infrastructure Setup (Completed)

### ✅ Phase 1: AWS SQS Queue Creation

Three SQS queues have been created in the `af-south-1` region:

1. **Default Queue** (mysos-queue-default)
   - URL: `https://sqs.af-south-1.amazonaws.com/877582899699/mysos-queue-default`
   - For standard priority jobs

2. **High Priority Queue** (mysos-queue-high)
   - URL: `https://sqs.af-south-1.amazonaws.com/877582899699/mysos-queue-high`
   - For time-critical jobs (emergency notifications, SMS)

3. **Failed Jobs Queue** (mysos-queue-failed)
   - URL: `https://sqs.af-south-1.amazonaws.com/877582899699/mysos-queue-failed`
   - For dead-letter queue functionality

### ✅ Phase 2: IAM Permissions

IAM role `mysos-titan-ec2-role` has been configured with SQS access:

**Policy Name**: `MySOS-SQS-Access`

**Permissions Granted**:
- `sqs:SendMessage` - Dispatch jobs to queue
- `sqs:ReceiveMessage` - Process jobs from queue
- `sqs:DeleteMessage` - Remove completed jobs
- `sqs:GetQueueAttributes` - Monitor queue metrics
- `sqs:GetQueueUrl` - Resolve queue URLs
- `sqs:ChangeMessageVisibility` - Extend job processing time
- `sqs:PurgeQueue` - Clear queue (testing only)
- `sqs:ListQueues` - Discover available queues

**Resource Scope**: Limited to the three MySOS queues only

### ✅ Phase 3: Configuration File Updates

The `aws-resources.env` file has been updated with SQS configuration:

```bash
export SQS_PREFIX=https://sqs.af-south-1.amazonaws.com/877582899699
export SQS_QUEUE_DEFAULT=https://sqs.af-south-1.amazonaws.com/877582899699/mysos-queue-default
export SQS_QUEUE_HIGH=https://sqs.af-south-1.amazonaws.com/877582899699/mysos-queue-high
export SQS_QUEUE_FAILED=https://sqs.af-south-1.amazonaws.com/877582899699/mysos-queue-failed
```

---

## Application Migration Steps

### For Each Laravel Application

The following applications need to be updated:
1. **cerebrum.mysos.co.za** - Main backend API
2. **neo.mysos.co.za** - API services
3. **portal.mysos.co.za** - Admin console
4. **mobile.mysos.co.za** - Mobile app backend
5. **web.mysos.co.za** - Web application
6. **sockets.mysos.co.za** - WebSocket server

### Step 1: Update Environment Variables (Forge)

For each site in Laravel Forge, update the environment variables:

#### Add SQS Configuration
```env
# AWS SQS Queue Configuration (replaces IronMQ)
QUEUE_CONNECTION=sqs
SQS_PREFIX=https://sqs.af-south-1.amazonaws.com/877582899699
SQS_QUEUE=mysos-queue-default
SQS_REGION=af-south-1

# AWS Credentials (should already exist)
AWS_ACCESS_KEY_ID=your_aws_access_key_id_here
AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key_here
AWS_DEFAULT_REGION=af-south-1
```

#### Keep IronMQ Configuration (for rollback)
```env
# IronMQ Configuration (KEEP for now - will remove after testing)
# QUEUE_CONNECTION=iron
IRON_MQ_HOST=mq-aws-us-east-1-1.iron.io
IRON_MQ_TOKEN=<your_iron_token>
IRON_MQ_PROJECT_ID=<your_project_id>
```

**Note**: Comment out `QUEUE_CONNECTION=iron` but keep credentials for easy rollback if needed.

### Step 2: Update Queue Configuration (if needed)

Laravel's `config/queue.php` already supports SQS out of the box. Verify the SQS configuration exists:

```php
'sqs' => [
    'driver' => 'sqs',
    'key' => env('AWS_ACCESS_KEY_ID'),
    'secret' => env('AWS_SECRET_ACCESS_KEY'),
    'prefix' => env('SQS_PREFIX', 'https://sqs.us-east-1.amazonaws.com/your-account-id'),
    'queue' => env('SQS_QUEUE', 'default'),
    'suffix' => env('SQS_SUFFIX'),
    'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    'after_commit' => false,
],
```

**No changes required** - Laravel 12 includes this by default.

### Step 3: Update Queue Workers (Forge)

For each site in Forge, update the queue worker configuration:

#### Current Worker Command (IronMQ)
```bash
php /home/forge/cerebrum.mysos.co.za/artisan queue:work iron --tries=3 --timeout=90
```

#### New Worker Command (SQS)
```bash
php /home/forge/cerebrum.mysos.co.za/artisan queue:work sqs --tries=3 --timeout=90 --sleep=3 --max-time=3600
```

**Parameters Explained**:
- `sqs` - Use SQS connection instead of `iron`
- `--tries=3` - Retry failed jobs 3 times
- `--timeout=90` - Job timeout (must be < SQS visibility timeout)
- `--sleep=3` - Seconds to sleep when no jobs available
- `--max-time=3600` - Restart worker after 1 hour (prevents memory leaks)

#### High Priority Worker (Optional)

For time-critical jobs, create a second worker:

```bash
php /home/forge/cerebrum.mysos.co.za/artisan queue:work sqs --queue=mysos-queue-high --tries=3 --timeout=60 --sleep=1
```

### Step 4: Clear Configuration Cache

After updating environment variables, SSH to the server and run:

```bash
ssh forge@13.245.247.128
cd /home/forge/cerebrum.mysos.co.za
php artisan config:clear
php artisan queue:restart
```

This ensures Laravel picks up the new SQS configuration.

### Step 5: Test Queue Functionality

#### Dispatch a Test Job

SSH to server and use Tinker to test:

```bash
php artisan tinker

# Dispatch a simple test job
dispatch(function () {
    \Log::info('SQS test job executed successfully!');
})->onQueue('mysos-queue-default');

# Exit tinker
exit
```

#### Monitor Queue Processing

Watch the Laravel logs:

```bash
php artisan pail --filter="SQS"
```

You should see the test job being processed within seconds.

#### Verify in AWS Console

Check the SQS queue metrics:

```bash
source aws-resources.env

aws sqs get-queue-attributes \
  --queue-url $SQS_QUEUE_DEFAULT \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --region $AWS_REGION
```

### Step 6: Migration Sequence (Gradual Rollout)

Recommended migration order (lowest to highest risk):

1. **Development/Testing** (if available)
2. **sockets.mysos.co.za** - Lowest traffic
3. **web.mysos.co.za** - Medium traffic
4. **mobile.mysos.co.za** - User-facing but non-critical
5. **portal.mysos.co.za** - Admin only
6. **neo.mysos.co.za** - API services
7. **cerebrum.mysos.co.za** - Main backend (migrate last, highest traffic)

**Wait 24-48 hours** between each migration to monitor for issues.

---

## Queue Job Dispatching Updates

### Default Queue

For standard priority jobs, no code changes needed:

```php
// Existing code - works with both IronMQ and SQS
dispatch(new ProcessEmergency($emergency));
```

### High Priority Queue

For time-critical jobs, specify the high priority queue:

```php
// Emergency notifications, SMS, critical alerts
dispatch(new SendEmergencyAlert($emergency))
    ->onQueue('mysos-queue-high');
```

### Example Job Class

```php
namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class SendEmergencyAlert implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $tries = 3;
    public $timeout = 90;
    public $maxExceptions = 2;

    public function __construct(public Emergency $emergency)
    {
    }

    public function handle()
    {
        // Send emergency alert via Twilio, FCM, etc.
    }

    public function failed(\Throwable $exception)
    {
        // Job failed after 3 retries - log and alert
        \Log::error('Emergency alert failed', [
            'emergency_id' => $this->emergency->id,
            'error' => $exception->getMessage()
        ]);
    }
}
```

---

## Monitoring & Maintenance

### CloudWatch Metrics

Monitor SQS performance in AWS CloudWatch:

```bash
# View queue metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/SQS \
  --metric-name ApproximateNumberOfMessagesVisible \
  --dimensions Name=QueueName,Value=mysos-queue-default \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region af-south-1
```

### Key Metrics to Monitor

1. **ApproximateNumberOfMessagesVisible** - Jobs waiting to be processed
2. **ApproximateNumberOfMessagesNotVisible** - Jobs currently being processed
3. **ApproximateAgeOfOldestMessage** - How long oldest job has been waiting
4. **NumberOfMessagesSent** - Job dispatch rate
5. **NumberOfMessagesReceived** - Job processing rate
6. **NumberOfMessagesDeleted** - Completed jobs

### Set Up CloudWatch Alarms

```bash
source aws-resources.env

# Alert if queue depth > 1000
aws cloudwatch put-metric-alarm \
  --alarm-name mysos-sqs-queue-depth-high \
  --alarm-description "Alert when SQS queue has >1000 messages" \
  --metric-name ApproximateNumberOfMessagesVisible \
  --namespace AWS/SQS \
  --statistic Average \
  --period 300 \
  --threshold 1000 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=QueueName,Value=mysos-queue-default \
  --alarm-actions $SNS_TOPIC_ARN \
  --region $AWS_REGION

# Alert if oldest message > 30 minutes
aws cloudwatch put-metric-alarm \
  --alarm-name mysos-sqs-message-age-high \
  --alarm-description "Alert when oldest SQS message >30min" \
  --metric-name ApproximateAgeOfOldestMessage \
  --namespace AWS/SQS \
  --statistic Maximum \
  --period 300 \
  --threshold 1800 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=QueueName,Value=mysos-queue-default \
  --alarm-actions $SNS_TOPIC_ARN \
  --region $AWS_REGION
```

### Laravel Horizon (Optional Alternative)

For better queue monitoring, consider installing Laravel Horizon:

```bash
composer require laravel/horizon
php artisan horizon:install
php artisan horizon:publish
```

**Benefits**:
- Beautiful dashboard for queue monitoring
- Real-time metrics
- Failed job management
- Job retry functionality

---

## Troubleshooting

### Issue: Jobs Not Processing

**Symptoms**: Jobs dispatched but never executed

**Diagnosis**:
```bash
# Check queue depth
source aws-resources.env
aws sqs get-queue-attributes \
  --queue-url $SQS_QUEUE_DEFAULT \
  --attribute-names All \
  --region $AWS_REGION

# Check worker process
ssh forge@13.245.247.128
sudo supervisorctl status
```

**Solution**:
```bash
# Restart queue workers
ssh forge@13.245.247.128
php artisan queue:restart

# Or via Supervisor
sudo supervisorctl restart all
```

### Issue: Jobs Failing Immediately

**Symptoms**: Jobs move to failed queue instantly

**Diagnosis**:
```bash
# Check failed jobs
php artisan queue:failed

# View recent logs
php artisan pail --filter="queue"
```

**Common Causes**:
1. **Serialization issues** - Job class or dependencies not serializable
2. **Timeout too short** - Job needs more than 90 seconds
3. **Missing dependencies** - Database connection, Redis, external API down

**Solution**:
```bash
# Increase timeout in job class
public $timeout = 300; // 5 minutes

# Or in worker command
php artisan queue:work sqs --timeout=300

# Retry failed jobs after fixing
php artisan queue:retry all
```

### Issue: Duplicate Job Processing

**Symptoms**: Same job executed multiple times

**Cause**: Worker timeout < SQS visibility timeout (90 seconds)

**Solution**: Ensure worker timeout is less than SQS visibility timeout:

```bash
# SQS visibility timeout: 90 seconds (configured)
# Worker timeout: must be < 90 seconds

php artisan queue:work sqs --timeout=80
```

### Issue: AWS Credentials Invalid

**Symptoms**: "Unable to connect to SQS" errors

**Diagnosis**:
```bash
# Test AWS credentials
aws sts get-caller-identity --region af-south-1

# Test SQS access
source aws-resources.env
aws sqs send-message \
  --queue-url $SQS_QUEUE_DEFAULT \
  --message-body "Test" \
  --region $AWS_REGION
```

**Solution**: Verify IAM role is attached to EC2 instance:

```bash
aws ec2 describe-instances \
  --instance-ids $LARAVEL_INSTANCE \
  --query 'Reservations[0].Instances[0].IamInstanceProfile' \
  --region $AWS_REGION
```

---

## Cost Analysis

### IronMQ Costs (Current)

- **Plan**: Developer ($49/month) or Production ($99/month)
- **Annual Cost**: $588 - $1,188

### AWS SQS Costs (New)

**Pricing**:
- First 1 million requests/month: FREE
- Additional requests: $0.40 per million

**Estimated MySOS Usage**:
- Average: ~500,000 requests/month
- Peak: ~1,500,000 requests/month

**Monthly Cost**:
- Average: $0 (within free tier)
- Peak: $0.20 (500k requests × $0.40/million)

**Annual Cost**: $0 - $2.40

### Savings

- **Annual Savings**: $585.60 - $1,188
- **Percentage Reduction**: 99%

---

## Rollback Procedure

If issues arise, rollback to IronMQ is simple:

### Step 1: Update Environment Variables

In Forge, change `QUEUE_CONNECTION` back to `iron`:

```env
# Switch back to IronMQ
QUEUE_CONNECTION=iron

# Keep SQS config commented out
# SQS_PREFIX=https://sqs.af-south-1.amazonaws.com/877582899699
# SQS_QUEUE=mysos-queue-default
```

### Step 2: Update Queue Worker

Change worker command back to IronMQ:

```bash
php /home/forge/cerebrum.mysos.co.za/artisan queue:work iron --tries=3 --timeout=90
```

### Step 3: Clear Config and Restart

```bash
ssh forge@13.245.247.128
cd /home/forge/cerebrum.mysos.co.za
php artisan config:clear
php artisan queue:restart
```

**Rollback time**: < 5 minutes per application

---

## Post-Migration Cleanup

### After 30 Days of Stable Operation

1. **Remove IronMQ Credentials** from all Forge environment configs
2. **Remove IronMQ Package** from composer.json:

```bash
cd /home/mac/Clients/MySOS/AWSDeployments/mysos-cerebrum
composer remove iron-io/iron_mq
git add composer.json composer.lock
git commit -m "Remove IronMQ dependency after SQS migration"
git push
```

3. **Cancel IronMQ Subscription** via https://www.iron.io
4. **Update Documentation** to reflect SQS as standard queue service

---

## Testing Checklist

Before marking migration complete, verify:

- [ ] Test job dispatched successfully
- [ ] Test job processed within expected time
- [ ] Failed jobs move to failed queue
- [ ] Job retries work correctly (simulate failure)
- [ ] High priority queue processes faster than default
- [ ] Queue metrics visible in CloudWatch
- [ ] CloudWatch alarms trigger correctly
- [ ] No memory leaks after 24 hours
- [ ] Worker auto-restart after max-time
- [ ] Emergency alerts still sent (critical path test)
- [ ] SMS notifications still sent
- [ ] Push notifications still sent
- [ ] Email queue still processing

---

## Support & Documentation

### AWS SQS Documentation
- [SQS Developer Guide](https://docs.aws.amazon.com/sqs/)
- [Laravel Queue Documentation](https://laravel.com/docs/12.x/queues)

### Internal Documentation
- `CLAUDE.md` - Project overview and architecture
- `FORGE-SETUP-GUIDE.md` - Forge configuration
- `aws-resources.env` - AWS resource identifiers

### Monitoring Dashboards
- **CloudWatch**: https://console.aws.amazon.com/cloudwatch (af-south-1)
- **Forge**: https://forge.laravel.com/servers/972748
- **SQS Console**: https://console.aws.amazon.com/sqs (af-south-1)

---

## Migration Completion Checklist

- [x] Create SQS queues (default, high, failed)
- [x] Configure IAM permissions
- [x] Update aws-resources.env
- [ ] Update Cerebrum environment variables
- [ ] Update Cerebrum queue worker
- [ ] Test Cerebrum queue processing
- [ ] Update Neo environment variables
- [ ] Update Neo queue worker
- [ ] Test Neo queue processing
- [ ] Update Portal environment variables
- [ ] Update Portal queue worker
- [ ] Test Portal queue processing
- [ ] Update App environment variables
- [ ] Update App queue worker
- [ ] Test App queue processing
- [ ] Update Web environment variables
- [ ] Update Web queue worker
- [ ] Test Web queue processing
- [ ] Update Sockets environment variables
- [ ] Update Sockets queue worker
- [ ] Test Sockets queue processing
- [ ] Monitor for 30 days
- [ ] Remove IronMQ credentials
- [ ] Remove IronMQ package
- [ ] Cancel IronMQ subscription

---

**Document Version**: 1.0
**Last Updated**: 2025-10-19
**Author**: Claude Code (AWS SQS Migration)
