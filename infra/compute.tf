# One t3.micro web server in the public subnet. It serves a one-line page over
# HTTP. There is no SSH: the only way in is AWS Systems Manager Session Manager,
# which needs no open port and no key pair.

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "web" {
  name        = "${var.name_prefix}-web-sg"
  description = "Allow inbound HTTP from the internet and outbound HTTPS only."
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-web-sg"
  }
}

# A public web server must accept HTTP from anywhere. This is the one ingress
# the design intends; it is reviewed and accepted, not an oversight.
resource "aws_vpc_security_group_ingress_rule" "web_http" {
  # checkov:skip=CKV_AWS_260:A public web server must accept HTTP (80) from the internet; this is the app's purpose.
  security_group_id = aws_security_group.web.id
  description       = "HTTP from the internet to the web server"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Outbound HTTPS only: the SSM agent and package updates need it. AWS service
# endpoints have no fixed IP range small enough to allowlist, so the
# destination is 0.0.0.0/0 but the port is limited to 443.
# trivy:ignore:AVD-AWS-0104 egress is limited to HTTPS (443) for the SSM agent and dnf updates; AWS endpoints have no stable IP allowlist
resource "aws_vpc_security_group_egress_rule" "web_https_out" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS out for the SSM agent and package updates"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# IAM role so the instance can be reached through SSM Session Manager.
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.name_prefix}-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Name = "${var.name_prefix}-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name_prefix}-ssm-profile"
  role = aws_iam_role.ssm.name
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  monitoring             = true
  ebs_optimized          = true

  # Require IMDSv2: a session token is mandatory, which blocks the SSRF-to-
  # credential-theft path that plain IMDSv1 allows.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y httpd
    echo "seceng-iac-gate week 12: IaC caught before it shipped" > /var/www/html/index.html
    systemctl enable --now httpd
  EOF

  user_data_replace_on_change = true

  tags = {
    Name = "${var.name_prefix}-web"
  }
}

# An Elastic IP gives the web server a stable public address without making the
# whole subnet assign public IPs.
resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  tags = {
    Name = "${var.name_prefix}-web-eip"
  }
}

output "web_url" {
  description = "HTTP URL of the web server."
  value       = "http://${aws_eip.web.public_ip}/"
}

output "web_public_ip" {
  description = "Public IP of the web server."
  value       = aws_eip.web.public_ip
}

output "web_instance_id" {
  description = "ID of the web server instance."
  value       = aws_instance.web.id
}
