# Mysos Titan AWS Deployment Package

Complete infrastructure-as-code for migrating Mysos applications to AWS.

## 🎯 What This Package Does

Deploys a production-ready, scalable AWS infrastructure for:
- 7 Laravel PHP 8.4 applications
- 10 Node.js TCP servers (panic buttons)
- 1 WordPress site
- MySQL database (5.5GB)
- Redis cache
- Full monitoring and alerting

## 📦 What's Included

### Setup Scripts (Run in Order)

**Core Infrastructure (Required):**
1. `0-MASTER-DEPLOY-ALL.sh` - **Run this first!** Executes all core scripts
2. `1-setup-vpc-and-networking.sh` - VPC, subnets, internet gateway
3. `2-setup-security-groups.sh` - Security groups for all services
4. `3-setup-rds-database.sh` - MySQL database on RDS
5. `4-setup-elasticache-redis.sh` - Redis cache cluster
6. `5-setup-load-balancer.sh` - Application Load Balancer with routing
7. `6-setup-ec2-laravel-instances.sh` - EC2 instance for Laravel apps
8. `7-setup-ec2-nodejs-instances.sh` - EC2 instance for Node.js apps
9. `8-setup-cloudwatch-monitoring.sh` - Monitoring, alarms, dashboard

**Robustness Enhancements (Highly Recommended):**
10. `10-setup-network-load-balancer-tcp.sh` - **CRITICAL!** HA for panic buttons
11. `11-setup-waf-protection.sh` - Web application firewall (security)
12. `12-setup-ssm-session-manager.sh` - Secure access without SSH port 22
13. `13-setup-s3-laravel-storage.sh` - Shared file storage (required for scaling)
14. `14-setup-secrets-manager.sh` - Encrypted credential storage

### Migration & Management Tools
- `database-migration-tool.sh` - Migrate MySQL data to RDS
- `CLEANUP-destroy-all.sh` - Remove all AWS resources (use with caution!)

### Documentation
- `README.md` - **Start here!** Quick start guide (this file)
- `COMPLETE-DEPLOYMENT-GUIDE.md` - Full deployment walkthrough
- `ROBUSTNESS-IMPROVEMENTS.md` - **Critical gaps and how to fix them**
- `FORGE-SETUP-GUIDE.md` - Laravel Forge integration guide
- `9-wordpress-lightsail-setup-guide.md` - WordPress on Lightsail
- `AWS-COMMAND-REFERENCE.md` - Quick command reference
- `COST-OPTIMIZATION-GUIDE.md` - Save money on AWS
- `nodejs-deployment-guide.md` - Deploy Node.js apps with PM2

## 💰 Cost Estimate

| Configuration | Monthly Cost | Description |
|--------------|--------------|-------------|
| **Basic Setup** | ~$245/month | Core infrastructure only |
| **+ Phase 1 Improvements** | ~$277/month | Adds NLB, WAF, SSM, S3, Secrets ($32 extra) |
| **+ Phase 2 (High Availability)** | ~$319/month | Adds Multi-AZ RDS, CloudFront ($42 extra) |
| **With Reserved Instances** | ~$260/month | 40% savings on compute |
| **Fully Optimized** | ~$133/month | After all optimizations |

**Our Budget:** $380/month → **Phase 1+2 costs $319/month** = $61/month buffer! 🚀

**Recommended:** Deploy basic ($245), then add Phase 1 improvements ($277 total) for production-grade reliability.

## 🚀 Quick Start

### Prerequisites

1. AWS Account with credentials configured
2. AWS CLI installed and working
3. Terminal access (Linux/Mac or WSL on Windows)

### Deployment (30 minutes)

```bash
# 1. Clone or download all files to a directory
cd mysos-aws-deployment

# 2. Make master script executable
chmod +x 0-MASTER-DEPLOY-ALL.sh

# 3. Run the master deployment script
./0-MASTER-DEPLOY-ALL.sh

# This will:
# - Create all AWS infrastructure
# - Launch EC2 instances
# - Setup database and Redis
# - Configure load balancing
# - Enable monitoring
```

That's it! The script handles everything.

### After Deployment

1. **Setup SSL Certificates** (15 min)
   - Request certificate in AWS Certificate Manager
   - Add DNS validation records
   - Create HTTPS listener

2. **Migrate Database** (30 min)
   ```bash
   ./database-migration-tool.sh
   ```

3. **Deploy Laravel Apps** (2 hours)
   - Follow `FORGE-SETUP-GUIDE.md` (recommended)
   - Or deploy manually via SSH

4. **Deploy Node.js Apps** (1 hour)
   - Follow `nodejs-deployment-guide.md`

5. **Setup WordPress** (1 hour)
   - Follow `9-wordpress-lightsail-setup-guide.md`

**Total Setup Time:** ~5-6 hours

## 📋 Architecture Overview

```
                        Internet
                           |
                      [Route 53 DNS]
                           |
              ┌────────────┴────────────┐
              |                         |
         mysos.co.za              *.mysos.co.za
              |                         |
        [Lightsail]              [ALB + SSL]
        WordPress                      |
                         ┌─────────────┴─────────────┐
                         |                           |
                   [EC2 Laravel]               [EC2 Node.js]
                   Forge Managed               PM2 Managed
                   - cortex.mysos              - 10 TCP Apps
                   - apex.mysos                - Port 4000-4009
                   - console.mysos
                   - app.mysos
                   - web.mysos
                   - sockets.mysos
                         |                           |
                         └─────────┬─────────────────┘
                                   |
                    ┌──────────────┼──────────────┐
                    |              |              |
              [RDS MySQL]    [ElastiCache]    [S3 Assets]
                5.5GB           Redis          Backups
```

## 🎨 Key Features

### ✅ High Availability
- Multi-AZ networking
- Load balancer with health checks
- Automatic failover

### ✅ Scalability
- Easy to add more EC2 instances
- Auto-scaling ready
- Horizontal and vertical scaling

### ✅ Security
- VPC with public/private subnets
- Security groups (least privilege)
- SSL/TLS encryption
- Private database access only

### ✅ Monitoring
- CloudWatch dashboard
- Email alerts for:
  - High CPU usage
  - Instance failures
  - Database issues
  - Error rates
  - Slow responses

### ✅ Backup & Recovery
- Automated RDS backups (7 days)
- Manual snapshots support
- Database migration tool included
- Easy rollback capabilities

### ✅ Cost Optimized
- Right-sized instances
- Reserved Instance recommendations
- Cost monitoring and alerts
- Budget remaining for growth

## 📚 Documentation Structure

### For First-Time Setup
1. Read this README
2. Follow `COMPLETE-DEPLOYMENT-GUIDE.md`
3. Use `FORGE-SETUP-GUIDE.md` for Laravel
4. Reference `AWS-COMMAND-REFERENCE.md` as needed

### For Daily Operations
- `AWS-COMMAND-REFERENCE.md` - Common tasks
- Forge dashboard - Deploy apps
- AWS Console - Monitor resources

### For Optimization
- `COST-OPTIMIZATION-GUIDE.md` - Reduce costs
- AWS Cost Explorer - Track spending
- CloudWatch - Performance metrics

## 🔧 Common Tasks

### Deploy Code Changes
```bash
# Via Forge (recommended)
1. Push to Git
2. Forge auto-deploys

# Or manually
ssh -i mysos-titan-key.pem ubuntu@$LARAVEL_PUBLIC_IP
cd /home/forge/cortex.mysos.co.za
git pull
composer install
php artisan migrate
```

### Check Server Status
```bash
source aws-resources.env
./daily-health-check.sh
```

### View Logs
```bash
# Laravel
ssh -i mysos-titan-key.pem ubuntu@$LARAVEL_PUBLIC_IP
tail -f /home/forge/cortex.mysos.co.za/storage/logs/laravel.log

# Node.js
ssh -i mysos-titan-key.pem ubuntu@$NODEJS_PUBLIC_IP
pm2 logs
```

### Database Backup
```bash
mysqldump -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME > backup.sql
```

### Scale Up (Add Instance)
```bash
# Launch new Laravel instance
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.large \
  --key-name mysos-titan-key \
  --security-group-ids $LARAVEL_SG \
  --subnet-id $PUBLIC_SUBNET_2

# Register with target groups
# ALB automatically distributes traffic
```

## 🆘 Troubleshooting

### Can't Connect to Server
```bash
# Check instance status
aws ec2 describe-instance-status --instance-ids $LARAVEL_INSTANCE

# Check security group allows SSH from our IP
aws ec2 describe-security-groups --group-ids $LARAVEL_SG
```

### Database Connection Issues
```bash
# Test from Laravel instance
mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD

# Verify security group allows MySQL
aws ec2 describe-security-groups --group-ids $RDS_SG
```

### High Costs
```bash
# Check what's costing money
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# See COST-OPTIMIZATION-GUIDE.md
```

### Apps Not Responding
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn $TG_CORTEX

# SSH to server and check logs
ssh -i mysos-titan-key.pem ubuntu@$LARAVEL_PUBLIC_IP
sudo systemctl status nginx php8.4-fpm
```

## 🔐 Security Best Practices

1. **Restrict SSH Access**
   - Update security groups to allow only our office IP
   - Use SSH keys, never passwords

2. **Enable MFA**
   - Enable MFA on AWS root account
   - Enable MFA on IAM users

3. **Regular Updates**
   - Forge handles security updates automatically
   - Review AWS Security Hub recommendations

4. **Secure Credentials**
   - Never commit `.pem` files to Git
   - Store passwords in password manager
   - Rotate credentials regularly

5. **Monitor Access**
   - Review CloudTrail logs
   - Enable AWS GuardDuty for threat detection

## 📊 Performance Monitoring

### CloudWatch Dashboard
https://console.aws.amazon.com/cloudwatch

Monitor:
- CPU utilization
- Memory usage
- Network traffic
- Request counts
- Response times
- Error rates

### Forge Monitoring
For each Laravel site:
- CPU usage
- Memory usage
- Disk space
- Queue workers

### Cost Monitoring
https://console.aws.amazon.com/cost-management

Track:
- Daily costs
- Month-over-month trends
- Service breakdown
- Budget alerts

## 🎓 Learning Resources

### AWS Services We Use
- **EC2:** https://docs.aws.amazon.com/ec2/
- **RDS:** https://docs.aws.amazon.com/rds/
- **ALB:** https://docs.aws.amazon.com/elasticloadbalancing/
- **VPC:** https://docs.aws.amazon.com/vpc/

### Tools We Use
- **Laravel Forge:** https://forge.laravel.com/docs
- **PM2:** https://pm2.keymetrics.io/docs/
- **AWS CLI:** https://docs.aws.amazon.com/cli/

## 🚨 Emergency Procedures

### Complete Infrastructure Failure
1. Restore RDS from latest snapshot
2. Launch new EC2 from AMI backups
3. Update DNS records
4. Redeploy applications

### Database Corruption
1. Stop all applications
2. Restore RDS from snapshot
3. Update Laravel .env files
4. Restart applications

### Need to Rollback Everything
```bash
./CLEANUP-destroy-all.sh
# Creates final snapshots before deletion
# Can restore from these snapshots later
```

## 📞 Support

### AWS Support
- Console: https://console.aws.amazon.com/support
- Documentation: https://docs.aws.amazon.com

### Laravel Forge Support
- Email: support@laravel.com
- Docs: https://forge.laravel.com/docs

### This Deployment Package
- All scripts include helpful error messages
- Documentation includes examples
- AWS-COMMAND-REFERENCE.md for quick tasks

## 📝 Maintenance Schedule

### Daily
- Monitor CloudWatch alarms (automatic emails)
- Check Forge deployment status

### Weekly
- Review cost reports
- Check instance utilization
- Review application logs for errors

### Monthly
- Apply security updates (Forge automatic)
- Review and optimize costs
- Test backup restoration
- Review CloudWatch metrics

### Quarterly
- Update documentation
- Review and optimize architecture
- Test disaster recovery procedures
- Review security posture

## ✨ What Makes This Setup Great

1. **Production-Ready:** Built with best practices from day one
2. **Scalable:** Easy to add capacity as we grow
3. **Cost-Effective:** Well under budget with room to spare
4. **Well-Documented:** Everything is explained clearly
5. **Easy to Manage:** Forge + AWS Console + scripts
6. **Secure:** VPC, security groups, SSL, monitoring
7. **Reliable:** Automated backups, monitoring, alerts
8. **Flexible:** Can easily modify or expand

## 🎉 Success Metrics

After deployment, we'll have:
- ✅ 7 Laravel apps running smoothly
- ✅ 10 Node.js TCP servers operational
- ✅ WordPress site migrated
- ✅ 5.5GB database on RDS
- ✅ Redis caching working
- ✅ SSL on all domains
- ✅ Load balancing active
- ✅ Monitoring and alerts configured
- ✅ Automated backups running
- ✅ Cost tracking enabled
- ✅ Budget under control ($245 of $380)

## 🚀 Next Steps After Deployment

1. ✅ Test all applications thoroughly
2. ✅ Monitor for 24-48 hours before DNS cutover
3. ✅ Set up staging environment (optional)
4. ✅ Configure CI/CD pipelines
5. ✅ Train team on new infrastructure
6. ✅ Document any custom configurations
7. ✅ Schedule regular backup tests
8. ✅ Review and optimize after 1 month

## 📄 License & Credits

Created for Mackor (Pty) Ltd by Mac.

All AWS services are billed directly by Amazon Web Services.
Forge subscription is billed by Laravel LLC.

---

**Ready to deploy? Run `./0-MASTER-DEPLOY-ALL.sh` and let's go! 🚀**

For questions or issues, refer to COMPLETE-DEPLOYMENT-GUIDE.md or AWS documentation.
