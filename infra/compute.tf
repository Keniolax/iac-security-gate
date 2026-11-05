# Add the web server. (This is the INSECURE version proposed in PR A; the gate
# should reject it.)

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_security_group" "web" {
  name        = "${var.name_prefix}-web-sg"
  description = "web server access"
  vpc_id      = aws_vpc.main.id

  # SSH open to the whole internet.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-web-sg"
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  # IMDSv1 left on.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  # Root volume not encrypted.
  root_block_device {
    encrypted = false
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y httpd
    echo "hello" > /var/www/html/index.html
    systemctl enable --now httpd
  EOF

  tags = {
    Name = "${var.name_prefix}-web"
  }
}
