You can view your deployed AWS resources in several places in the AWS Console:

  Main Places to View Your Infrastructure:

  1. EC2 Dashboard (Most Important)

  - URL: https://af-south-1.console.aws.amazon.com/ec2/home?region=af-south-1
  - What you'll see:
    - Instances: Your 2 EC2 servers (Laravel t3.large, Node.js t3.medium)
    - Elastic IPs: Your 2 public IP addresses (13.245.247.128, 13.245.88.195)
    - Security Groups: All firewall rules created
    - Key Pairs: Your SSH key (mysos-titan-key)
    - Load Balancers: Your Application Load Balancer
    - Target Groups: 6 target groups (one for each Laravel app)

  2. RDS Dashboard (Database)

  - URL: https://af-south-1.console.aws.amazon.com/rds/home?region=af-south-1
  - What you'll see:
    - Database instance: mysos-titan-db (MySQL 8.0.43, db.t3.small)
    - Endpoint: mysos-titan-db.c7coqesk2kne.af-south-1.rds.amazonaws.com
    - Status, backups, monitoring

  3. ElastiCache Dashboard (Redis)

  - URL: https://af-south-1.console.aws.amazon.com/elasticache/home?region=af-south-1
  - What you'll see:
    - Redis cluster: mysos-titan-redis
    - Endpoint: mysos-titan-redis.mythzx.0001.afs1.cache.amazonaws.com
    - Cache nodes, monitoring

  4. VPC Dashboard (Networking)

  - URL: https://af-south-1.console.aws.amazon.com/vpc/home?region=af-south-1
  - What you'll see:
    - Your VPC (vpc-0efa5c3ac9425b8d0)
    - Subnets (public and private in 2 availability zones)
    - Internet Gateway
    - Route Tables
    - Security Groups

  5. CloudWatch Dashboard (Monitoring)

  - URL: https://af-south-1.console.aws.amazon.com/cloudwatch/home?region=af-south-1
  - What you'll see:
    - Alarms (9 alarms for CPU, disk, database, Redis)
    - Metrics for all your resources
    - Logs from your instances

  6. SNS Dashboard (Alerts)

  - URL: https://af-south-1.console.aws.amazon.com/sns/home?region=af-south-1
  - What you'll see:
    - SNS Topic: mysos-titan-alerts
    - Email subscription (awsadmin@mysos.co.za)

  Quick View: Resource Groups

  For a consolidated view of everything, you can create a Resource Group:

  1. Go to: https://af-south-1.console.aws.amazon.com/resource-groups/home?region=af-south-1
  2. Create a new group with tag: Project=mysos-titan
  3. This will show all resources in one place

  Your Deployed Resources Summary:

  Region: af-south-1 (Africa - Cape Town)

  EC2 Instances:
  - Laravel: 13.245.247.128 (t3.large, Ubuntu 24.04)
  - Node.js: 13.245.88.195 (t3.medium, Ubuntu 22.04)

  Database:
  - RDS MySQL 8.0.43: mysos-titan-db.c7coqesk2kne.af-south-1.rds.amazonaws.com

  Cache:
  - ElastiCache Redis 7.1.0: mysos-titan-redis.mythzx.0001.afs1.cache.amazonaws.com

  Load Balancer:
  - ALB: mysos-titan-alb-358805960.af-south-1.elb.amazonaws.com
  - 6 Target Groups (cortex, apex, console, app, web, sockets)

  Networking:
  - VPC: vpc-0efa5c3ac9425b8d0
  - 4 Subnets (2 public, 2 private)
  - 5 Security Groups

  Monitoring:
  - 9 CloudWatch Alarms
  - SNS alerts to: awsadmin@mysos.co.za

  Important: Make sure you're always viewing the af-south-1 region in the AWS Console (check the region selector in the top-right corner).