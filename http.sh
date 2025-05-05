#!/bin/bash

# This step1 will update the server

echo "sudo yum update -y"

# This step2 will check and install httpd if not yet.

if rpm -q httpd &>/dev/null; then
    HTTPD_VERSION=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' httpd)
    echo "httpd is already installed (version: $HTTPD_VERSION)"
    echo "Checking if httpd service is running..."
else    
    sudo yum install httpd -y

fi    
  # Check service status

if systemctl is-active --quiet httpd; then
    echo "httpd service is running"
else
    echo "httpd service is not running."

systemctl start httpd
systemctl enable httpd 
systemctl status httpd
