#!/bin/bash

# Force cleanup script for stuck EKS resources
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Starting force cleanup of EKS resources...${NC}"

# Get cluster name from terraform state
CLUSTER_NAME=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.address=="random_string.suffix") | .values.result' 2>/dev/null || echo "")
if [ -n "$CLUSTER_NAME" ]; then
    FULL_CLUSTER_NAME="apptest-eks-${CLUSTER_NAME}"
    echo -e "${GREEN}Found cluster name: $FULL_CLUSTER_NAME${NC}"
else
    echo -e "${YELLOW}Could not determine cluster name from state, using pattern matching${NC}"
    FULL_CLUSTER_NAME=$(aws eks list-clusters --query 'clusters[?contains(@, `apptest-eks`)]' --output text | head -1)
fi

# Function to delete resources with retry
delete_with_retry() {
    local resource_type=$1
    local resource_id=$2
    local max_attempts=3
    
    for i in $(seq 1 $max_attempts); do
        echo "Attempting to delete $resource_type: $resource_id (attempt $i/$max_attempts)"
        if aws $resource_type delete-$resource_type --${resource_type}-id $resource_id 2>/dev/null; then
            echo -e "${GREEN}Successfully deleted $resource_type: $resource_id${NC}"
            return 0
        else
            echo -e "${YELLOW}Failed to delete $resource_type: $resource_id (attempt $i)${NC}"
            sleep 10
        fi
    done
    echo -e "${RED}Failed to delete $resource_type: $resource_id after $max_attempts attempts${NC}"
}

# 1. Delete Auto Scaling Groups
echo -e "${YELLOW}Deleting Auto Scaling Groups...${NC}"
ASG_NAMES=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'apptest-eks')].AutoScalingGroupName" --output text)
for asg in $ASG_NAMES; do
    echo "Deleting ASG: $asg"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asg --min-size 0 --desired-capacity 0 --max-size 0
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $asg --force-delete
done

# 2. Delete Launch Templates
echo -e "${YELLOW}Deleting Launch Templates...${NC}"
LT_IDS=$(aws ec2 describe-launch-templates --query "LaunchTemplates[?contains(LaunchTemplateName, 'apptest-eks')].LaunchTemplateId" --output text)
for lt in $LT_IDS; do
    echo "Deleting Launch Template: $lt"
    aws ec2 delete-launch-template --launch-template-id $lt
done

# 3. Wait for instances to terminate
echo -e "${YELLOW}Waiting for instances to terminate...${NC}"
sleep 30

# 4. Delete EKS Cluster
if [ -n "$FULL_CLUSTER_NAME" ]; then
    echo -e "${YELLOW}Deleting EKS Cluster: $FULL_CLUSTER_NAME${NC}"
    aws eks delete-cluster --name $FULL_CLUSTER_NAME || echo "Cluster may already be deleted"
    
    # Wait for cluster deletion
    echo "Waiting for cluster deletion to complete..."
    aws eks wait cluster-deleted --name $FULL_CLUSTER_NAME || echo "Cluster deletion wait timed out"
fi

# 5. Delete Network Interfaces
echo -e "${YELLOW}Deleting stuck network interfaces...${NC}"
ENI_IDS=$(aws ec2 describe-network-interfaces --filters "Name=description,Values=*eks*" --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text)
for eni in $ENI_IDS; do
    echo "Deleting ENI: $eni"
    aws ec2 delete-network-interface --network-interface-id $eni || echo "Failed to delete ENI: $eni"
done

# 6. Clean up Terraform state
echo -e "${YELLOW}Cleaning up Terraform state...${NC}"
terraform state rm 'module.eks.aws_security_group_rule.node["ingress_cluster_443"]' 2>/dev/null || echo "Rule not in state"
terraform state rm 'module.eks' 2>/dev/null || echo "EKS module not in state"

# 7. Final terraform destroy
echo -e "${YELLOW}Running final terraform destroy...${NC}"
terraform destroy -auto-approve

echo -e "${GREEN}Cleanup completed!${NC}"
echo -e "${YELLOW}Note: Some resources may take additional time to fully delete in AWS${NC}"