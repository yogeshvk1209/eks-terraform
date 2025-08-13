# Requirements Document

## Introduction

This feature adds support for self-managed node groups to the existing EKS Terraform infrastructure. Currently, the infrastructure only supports EKS managed node groups. Self-managed node groups provide greater control over the underlying EC2 instances, allowing for custom AMIs, advanced networking configurations, and more granular control over node lifecycle management. This enhancement will give users the flexibility to choose between managed and self-managed node groups based on their specific requirements.

## Requirements

### Requirement 1

**User Story:** As a DevOps engineer, I want to configure self-managed node groups alongside existing managed node groups, so that I can have greater control over the underlying infrastructure while maintaining the flexibility to use both approaches.

#### Acceptance Criteria

1. WHEN a user configures self-managed node group variables THEN the system SHALL create EC2 instances that automatically join the EKS cluster
2. WHEN self-managed node groups are enabled THEN the system SHALL create appropriate IAM roles and policies for the worker nodes
3. WHEN self-managed node groups are created THEN the system SHALL apply the same security group configurations as managed node groups
4. IF both managed and self-managed node groups are configured THEN the system SHALL support both simultaneously without conflicts

### Requirement 2

**User Story:** As a platform administrator, I want to specify custom AMIs and instance configurations for self-managed nodes, so that I can use specialized or hardened images that meet my organization's security requirements.

#### Acceptance Criteria

1. WHEN a custom AMI ID is provided THEN the system SHALL use that AMI for self-managed node instances
2. WHEN no custom AMI is specified THEN the system SHALL default to the latest EKS-optimized AMI
3. WHEN instance types are specified for self-managed nodes THEN the system SHALL use those instance types
4. WHEN user data scripts are provided THEN the system SHALL execute them during instance initialization

### Requirement 3

**User Story:** As a cost-conscious operator, I want to configure auto-scaling parameters for self-managed node groups, so that I can optimize costs while ensuring adequate capacity for my workloads.

#### Acceptance Criteria

1. WHEN min_size, max_size, and desired_size are specified THEN the system SHALL create an Auto Scaling Group with those parameters
2. WHEN scaling policies are defined THEN the system SHALL apply them to the Auto Scaling Group
3. WHEN spot instances are enabled THEN the system SHALL configure mixed instance policies for cost optimization
4. IF capacity type is set to SPOT THEN the system SHALL handle spot instance interruptions gracefully

### Requirement 4

**User Story:** As a security engineer, I want self-managed nodes to have proper IAM permissions and security configurations, so that they can securely communicate with the EKS control plane and AWS services.

#### Acceptance Criteria

1. WHEN self-managed node groups are created THEN the system SHALL create IAM instance profiles with required EKS worker node policies
2. WHEN nodes join the cluster THEN the system SHALL ensure they have AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, and AmazonEC2ContainerRegistryReadOnly policies
3. WHEN additional IAM policies are specified THEN the system SHALL attach them to the worker node role
4. WHEN security groups are configured THEN the system SHALL apply them to allow proper cluster communication

### Requirement 5

**User Story:** As a system administrator, I want to configure networking and storage options for self-managed nodes, so that I can optimize performance and meet specific application requirements.

#### Acceptance Criteria

1. WHEN subnet IDs are specified THEN the system SHALL deploy self-managed nodes in those subnets
2. WHEN no subnets are specified THEN the system SHALL use the same private subnets as the EKS cluster
3. WHEN EBS volume configurations are provided THEN the system SHALL create instances with those storage specifications
4. WHEN network interfaces are configured THEN the system SHALL apply those settings to the instances

### Requirement 6

**User Story:** As a DevOps engineer, I want the self-managed node group configuration to be optional and backward compatible, so that existing infrastructure continues to work without modifications.

#### Acceptance Criteria

1. WHEN self-managed node group variables are not defined THEN the system SHALL continue to work with only managed node groups
2. WHEN upgrading existing infrastructure THEN the system SHALL not require changes to existing managed node group configurations
3. WHEN both node group types are disabled THEN the system SHALL create only the EKS control plane
4. IF invalid configurations are provided THEN the system SHALL provide clear error messages during terraform plan