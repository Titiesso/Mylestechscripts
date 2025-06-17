#!/bin/bash

# This step1 will update the server
echo "Updating the server..."
sudo yum update -y

# This step2 will check and install httpd if not yet installed
if rpm -q httpd &>/dev/null; then
    HTTPD_VERSION=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' httpd)
    echo "httpd is already installed (version: $HTTPD_VERSION)"
else    
    echo "httpd is not installed. Installing httpd..."
    sudo yum install httpd -y
fi    

# Check service status and start if needed
echo "Checking if httpd service is running..."
if systemctl is-active --quiet httpd; then
    echo "httpd service is already running"
else
    echo "httpd service is not running. Starting httpd service..."
    sudo systemctl start httpd
    sudo systemctl enable httpd 
    echo "httpd service status:"
    sudo systemctl status httpd --no-pager
fi

# Configure firewall for HTTP traffic
echo "Configuring firewall for HTTP traffic..."
if systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --reload
    echo "Firewall configured to allow HTTP traffic"
else
    echo "Firewalld is not running - skipping firewall configuration"
fi

echo "Script completed successfully!"
