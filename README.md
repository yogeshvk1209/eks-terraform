# EKS Terraform Infrastructure

This repository contains Terraform configurations to set up a production-ready Amazon EKS (Elastic Kubernetes Service) cluster with associated infrastructure.

## Features

- VPC with public and private subnets across multiple availability zones
- EKS cluster with managed node groups
- Cost optimization with Spot instances
- Security groups with least privilege access
- Proper tagging for resource management
- Auto-scaling configuration
- IAM roles and policies for secure access

## Prerequisites

Before you begin, ensure you have:

- [AWS CLI](https://aws.amazon.com/cli/) installed and configured
- [Terraform](https://www.terraform.io/downloads.html) (v1.2.0 or newer)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed
- AWS credentials with appropriate permissions

## Infrastructure Components

- **VPC Configuration**
  - CIDR: 10.0.0.0/16
  - Public and Private Subnets
  - NAT Gateway
  - Internet Gateway

- **EKS Cluster**
  - Kubernetes version: 1.32
  - IRSA (IAM Roles for Service Accounts) enabled
  - Managed Node Groups with Spot instances

- **Node Groups**
  - Instance Types: t4g.medium, m6g.medium (ARM-based)
  - Auto-scaling (min: 1, max: 3)
  - Spot instances for cost optimization

## Quick Start

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd eks-terraform
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review the plan:
   ```bash
   terraform plan
   ```

4. Apply the configuration:
   ```bash
   terraform apply
   ```

   Or use the monitoring script:
   ```bash
   ./monitor_and_destroy.sh
   ```

5. Configure kubectl:
   ```bash
   aws eks update-kubeconfig --region <your-region> --name <cluster-name>
   ```

## Directory Structure

```
.
├── eks-cluster.tf     # EKS cluster configuration
├── main.tf           # Provider and backend configuration
├── outputs.tf        # Output definitions
├── security-groups.tf # Security group configurations
├── variables.tf      # Variable definitions
└── vpc.tf           # VPC configuration
```

## Important Notes

1. **Cost Management**
   - The cluster uses Spot instances for cost optimization
   - NAT Gateway and EKS cluster will incur costs
   - Remember to destroy resources when not in use

2. **Security**
   - IRSA is enabled for better security
   - Security groups are configured with least privilege access
   - Private subnets are used for node groups

3. **Monitoring**
   - A monitoring script is included to watch for errors during provisioning
   - Auto-destroy functionality if errors occur

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details!!! Enjoy!!!
