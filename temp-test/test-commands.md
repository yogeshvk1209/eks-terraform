# Test Commands for Self-Managed Node Groups

## Quick Test Commands

### 1. Basic Configuration Test
```bash
terraform plan -var-file=configs/tfvars/basic-test.tfvars
```

### 2. Spot Instance Configuration Test
```bash
terraform plan -var-file=configs/tfvars/spot-test.tfvars
```

### 3. Custom AMI Configuration Test
```bash
terraform plan -var-file=configs/tfvars/custom-ami-test.tfvars
```

### 4. Hybrid Configuration Test (Both Managed + Self-Managed)
```bash
terraform plan -var-file=configs/tfvars/hybrid-test.tfvars
```

### 5. Disabled Configuration Test
```bash
terraform plan -var-file=configs/tfvars/disabled-test.tfvars
```

## Validation Tests

### Test Terraform Syntax
```bash
terraform validate
```

### Test Variable Validation (Should Fail)
```bash
# Test invalid capacity type
cat > temp-test/invalid-test.tfvars <<EOF
enable_self_managed_node_groups = true
self_managed_node_groups = {
  invalid = {
    instance_types = ["t4g.small"]
    capacity_type = "INVALID"
  }
}
EOF

terraform plan -var-file=temp-test/invalid-test.tfvars
# This should fail with validation error
```

### Test Scaling Validation (Should Fail)
```bash
# Test invalid scaling configuration
cat > temp-test/invalid-scaling.tfvars <<EOF
enable_self_managed_node_groups = true
self_managed_node_groups = {
  invalid = {
    instance_types = ["t4g.small"]
    min_size = 5
    max_size = 3
    desired_size = 4
  }
}
EOF

terraform plan -var-file=temp-test/invalid-scaling.tfvars
# This should fail with validation error
```

## Output Tests

### Check Outputs
```bash
terraform plan -var-file=temp-test/basic-test.tfvars -out=test.tfplan
terraform show -json test.tfplan | jq '.planned_values.outputs'
```

### Verify Resource Creation
```bash
terraform plan -var-file=temp-test/basic-test.tfvars -out=test.tfplan
terraform show -json test.tfplan | jq -r '.planned_values.root_module.resources[].address' | grep self_managed
```

## Cleanup
```bash
rm -f temp-test/invalid-*.tfvars
rm -f test.tfplan
```