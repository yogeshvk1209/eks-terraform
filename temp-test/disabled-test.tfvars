# Test configuration with self-managed node groups disabled

enable_self_managed_node_groups = false

self_managed_node_groups = {}

# This should result in no self-managed resources being created
# Only the existing managed node groups should be deployed