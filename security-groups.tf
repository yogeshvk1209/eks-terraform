resource "aws_security_group" "app_test_worker_mgmt" {
  name_prefix = "app_test_worker_management"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "app_test_worker_mgmt_ingress" {
  description       = "allow inbound traffic from eks"
  from_port         = 0
  protocol          = "-1"
  to_port           = 0
  security_group_id = aws_security_group.app_test_worker_mgmt.id
  type              = "ingress"
  cidr_blocks = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
  ]
}

# SSH access for debugging
resource "aws_security_group_rule" "app_test_worker_mgmt_ssh" {
  description       = "allow SSH access for debugging"
  from_port         = 22
  protocol          = "tcp"
  to_port           = 22
  security_group_id = aws_security_group.app_test_worker_mgmt.id
  type              = "ingress"
  cidr_blocks       = ["10.0.0.0/8"]
}

# Allow LoadBalancer health checks and traffic
resource "aws_security_group_rule" "app_test_worker_mgmt_lb_http" {
  description       = "allow HTTP traffic from LoadBalancer"
  from_port         = 80
  protocol          = "tcp"
  to_port           = 80
  security_group_id = aws_security_group.app_test_worker_mgmt.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "app_test_worker_mgmt_lb_grafana" {
  description       = "allow Grafana port for LoadBalancer health checks"
  from_port         = 3000
  protocol          = "tcp"
  to_port           = 3000
  security_group_id = aws_security_group.app_test_worker_mgmt.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow NodePort range for LoadBalancer services
resource "aws_security_group_rule" "app_test_worker_mgmt_nodeport" {
  description       = "allow NodePort range for LoadBalancer services"
  from_port         = 30000
  protocol          = "tcp"
  to_port           = 32767
  security_group_id = aws_security_group.app_test_worker_mgmt.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "app_test_worker_mgmt_egress" {
  description       = "allow outbound traffic to anywhere"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.app_test_worker_mgmt.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}