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
   terraform plan -var-file=configs/tfvars/deploy.tfvars
   ```

4. Apply the configuration:
   ```bash
   terraform apply -var-file=configs/tfvars/deploy.tfvars
   ```

   Or use the monitoring script:
   ```bash
   ./scripts/utils/monitor_and_destroy.sh
   ```

5. Configure kubectl:
   ```bash
   aws eks update-kubeconfig --region <your-region> --name <cluster-name>
   ```

## Directory Structure

```
.
├── configs/                    # Configuration files
│   ├── tfvars/                # Terraform variable files
│   └── README.md              # Configuration documentation
├── scripts/                   # Scripts and utilities
│   ├── user-data/            # Bootstrap scripts for EKS nodes
│   ├── utils/                # Deployment and management utilities
│   └── README.md             # Scripts documentation
├── temp-test/                # Test configurations and commands
├── eks-cluster.tf            # EKS cluster configuration
├── eks-addons.tf             # EKS add-ons configuration
├── main.tf                   # Provider and backend configuration
├── outputs.tf                # Output definitions
├── security-groups.tf        # Security group configurations
├── self-managed-nodes.tf     # Self-managed node groups
├── variables.tf              # Variable definitions
└── vpc.tf                    # VPC configuration
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

## Self-Managed Node Groups

This EKS configuration supports both managed and self-managed node groups, with self-managed nodes providing greater control and cost optimization opportunities.

### Key Differences: Managed vs Self-Managed Node Groups

| Feature | Managed Node Groups | Self-Managed Node Groups |
|---------|-------------------|-------------------------|
| **Management** | Fully managed by AWS | You manage the EC2 instances |
| **AMI Control** | Limited to EKS-optimized AMIs | Full control over AMI selection |
| **Instance Types** | AWS manages instance selection | Full control over instance types |
| **Spot Instances** | Limited spot support | Advanced spot configuration |
| **Custom User Data** | Limited customization | Full user data control |
| **Scaling** | AWS handles scaling | You configure Auto Scaling Groups |
| **Updates** | Automated updates available | Manual update management |
| **Cost** | Higher cost, easier management | Lower cost, more complexity |

### Configuration Examples

#### Basic Self-Managed Node Group
```hcl
enable_self_managed_node_groups = true
self_managed_node_groups = {
  general = {
    instance_types = ["t4g.medium"]
    min_size      = 1
    max_size      = 3
    desired_size  = 2
    capacity_type = "ON_DEMAND"
  }
}
```

#### Spot Instances for Cost Optimization
```hcl
self_managed_node_groups = {
  spot-workers = {
    instance_types = ["t4g.medium", "t4g.large"]
    capacity_type  = "SPOT"
    mixed_instances_policy = {
      instances_distribution = {
        spot_allocation_strategy = "diversified"
        spot_max_price          = "0.05"
      }
    }
  }
}
```

#### Custom AMI Configuration
```hcl
self_managed_node_groups = {
  custom-nodes = {
    ami_id = "ami-0123456789abcdef0"
    instance_types = ["m6g.large"]
    additional_iam_policies = [
      "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    ]
    block_device_mappings = [{
      device_name = "/dev/xvda"
      ebs = {
        volume_size = 100
        volume_type = "gp3"
        encrypted   = true
      }
    }]
  }
}
```

### Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_self_managed_node_groups` | bool | false | Enable/disable self-managed node groups |
| `ami_id` | string | "" | Custom AMI ID (empty = use latest EKS AMI) |
| `instance_types` | list(string) | ["t3.medium"] | EC2 instance types |
| `min_size` | number | 1 | Minimum number of nodes |
| `max_size` | number | 3 | Maximum number of nodes |
| `desired_size` | number | 2 | Desired number of nodes |
| `capacity_type` | string | "ON_DEMAND" | "ON_DEMAND" or "SPOT" |
| `bootstrap_arguments` | string | "" | Additional kubelet bootstrap arguments |
| `additional_iam_policies` | list(string) | [] | Additional IAM policy ARNs |
| `mixed_instances_policy` | object | null | Mixed instances policy for cost optimization |

## Troubleshooting

### Common Issues

1. **Nodes not joining cluster:**
   - Check IAM permissions and security group rules
   - Review bootstrap logs: `sudo cat /var/log/eks-bootstrap.log`
   - Verify IMDSv2 configuration

2. **CoreDNS addon stuck:**
   - Ensure nodes are ready before addon installation
   - Check node status: `kubectl get nodes`

3. **Spot instance interruptions:**
   - Use diverse instance types in mixed instances policy
   - Monitor spot pricing and availability

### Debugging Commands

```bash
# Check cluster and node status
kubectl get nodes
kubectl get pods -n kube-system

# View node details
kubectl describe node <node-name>

# Check bootstrap logs on instances
aws ssm start-session --target <instance-id>
sudo tail -f /var/log/eks-bootstrap.log
sudo journalctl -u kubelet -f
```

## Testing containers and other internal k8s stuff
Use git repo - https://github.com/yogeshvk1209/microservice_k8s to test out K8S deployments

## Best Practices

1. **Security:**
   - Use IMDSv2 for enhanced security
   - Regularly update AMIs and security patches
   - Use encrypted EBS volumes
   - Implement least-privilege IAM policies

2. **Cost Optimization:**
   - Use spot instances for non-critical workloads
   - Right-size instance types based on usage
   - Implement cluster autoscaling
   - Use ARM-based instances (Graviton) for better price/performance

3. **Reliability:**
   - Use multiple instance types for better availability
   - Implement proper monitoring and alerting
   - Test configurations in development first
   - Use diverse availability zones

## Cleanup

To destroy all resources:

```bash
terraform destroy -auto-approve

# If resources get stuck, use the force cleanup script
./scripts/utils/force-cleanup.sh
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details!!! Enjoy!!!
