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
