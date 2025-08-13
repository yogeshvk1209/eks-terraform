# Implementation Plan

- [x] 1. Add self-managed node group variables to variables.tf
  - Create variable definitions for enabling self-managed node groups
  - Define variable structure for node group configurations including AMI, instance types, scaling parameters
  - Add variables for IAM policies, security groups, and EBS configurations
  - _Requirements: 1.1, 2.1, 3.1, 6.1_

- [x] 2. Create IAM resources for self-managed nodes
  - Implement IAM role for self-managed worker nodes with EC2 assume role policy
  - Attach required AWS managed policies (AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly)
  - Create IAM instance profile for EC2 instances
  - Add support for additional custom IAM policies
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 3. Implement AMI data source and validation
  - Create data source to fetch latest EKS-optimized AMI for the specified Kubernetes version
  - Add logic to use custom AMI when provided or fallback to latest EKS AMI
  - Implement AMI validation to ensure compatibility with EKS
  - _Requirements: 2.1, 2.2_

- [x] 4. Create user data template for node bootstrapping
  - Write user data script template that configures nodes to join the EKS cluster
  - Include cluster endpoint, CA certificate, and bootstrap arguments configuration
  - Add support for custom bootstrap arguments and additional user data
  - Implement error handling and logging in the bootstrap script
  - _Requirements: 1.1, 2.4_

- [x] 5. Implement launch template resource
  - Create launch template with configurable AMI, instance type, and security groups
  - Configure IAM instance profile and user data script
  - Add EBS block device mapping configuration with encryption support
  - Include network interface configuration and security group assignments
  - _Requirements: 2.1, 2.3, 5.3, 5.4_

- [x] 6. Create auto scaling group for self-managed nodes
  - Implement auto scaling group with configurable min/max/desired capacity
  - Configure deployment across private subnets with proper AZ distribution
  - Add required tags for EKS cluster integration and Kubernetes node discovery
  - Include health check configuration and termination policies
  - _Requirements: 1.1, 3.1, 3.2, 5.1, 5.2_

- [x] 7. Add support for mixed instance types and spot instances
  - Extend launch template to support multiple instance types
  - Implement mixed instances policy for cost optimization
  - Add spot instance configuration with interruption handling
  - Configure on-demand and spot instance ratio settings
  - _Requirements: 3.3, 3.4_

- [x] 8. Create conditional resource deployment logic
  - Add conditional logic to only create self-managed resources when enabled
  - Ensure backward compatibility with existing managed node group configurations
  - Implement validation to prevent conflicts between managed and self-managed configurations
  - _Requirements: 1.4, 6.1, 6.2, 6.3_

- [x] 9. Add outputs for self-managed node group information
  - Create outputs for auto scaling group ARNs and names
  - Add outputs for launch template IDs and IAM role ARNs
  - Include node group status and configuration details in outputs
  - _Requirements: 1.1_

- [x] 10. Implement security group integration
  - Ensure self-managed nodes use existing security groups for cluster communication
  - Add any additional security group rules specific to self-managed nodes if needed
  - Validate security group configurations allow proper EKS cluster communication
  - _Requirements: 1.3, 4.4_

- [x] 11. Add comprehensive variable validation
  - Implement validation rules for instance types, AMI IDs, and scaling parameters
  - Add validation for subnet IDs and security group IDs
  - Create validation for capacity types and mixed instance configurations
  - Include clear error messages for invalid configurations
  - _Requirements: 6.4_

- [x] 12. Create example configuration and documentation
  - Write example terraform.tfvars showing self-managed node group configuration
  - Create documentation explaining the differences between managed and self-managed nodes
  - Add migration guide for converting from managed to self-managed nodes
  - Include troubleshooting guide for common issues
  - _Requirements: 6.1, 6.2_

- [x] 13. Write integration tests for the complete solution
  - Create test configuration that deploys both managed and self-managed node groups
  - Write tests to verify nodes successfully join the cluster and become ready
  - Add tests for scaling operations and node replacement scenarios
  - Include tests for spot instance handling and mixed instance policies
  - _Requirements: 1.1, 1.4, 3.1, 3.3_