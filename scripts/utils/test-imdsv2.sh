#!/bin/bash

# Test script to verify IMDSv2 is working
echo "Testing IMDSv2 access..."

# Get token
echo "Getting IMDSv2 token..."
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)

if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to get IMDSv2 token"
    exit 1
fi

echo "Token obtained successfully (length: ${#TOKEN})"

# Test metadata calls
echo "Testing metadata calls with IMDSv2..."
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_TYPE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-type)

echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"
echo "Instance Type: $INSTANCE_TYPE"

if [ -n "$INSTANCE_ID" ] && [ -n "$REGION" ] && [ -n "$INSTANCE_TYPE" ]; then
    echo "SUCCESS: IMDSv2 is working correctly"
else
    echo "ERROR: Some metadata values are empty"
    exit 1
fi