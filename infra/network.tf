# The network foundation: one VPC, one public and one private subnet, an
# internet gateway and route tables. No NAT gateway (it bills by the hour and
# the lab has nothing in the private subnet that needs outbound internet).

# Flow logs need a persistent CloudWatch or S3 sink and an IAM role. The lab
# runs for a few minutes during a deploy/destroy check, so a standing flow-log
# sink is out of scope; this is an accepted risk for a throwaway lab, not a
# control we forgot.
# trivy:ignore:AVD-AWS-0178 flow-log sink out of scope for a minutes-long throwaway lab
resource "aws_vpc" "main" {
  # checkov:skip=CKV2_AWS_11:VPC flow logs need a persistent sink + IAM role; out of scope for a minutes-long throwaway lab.
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# The VPC's own default security group must deny all traffic. A default group
# that allows traffic is an open door nobody wrote a rule for.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress and no egress blocks: deny everything.

  tags = {
    Name = "${var.name_prefix}-default-sg-locked"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = var.availability_zone

  # The web server gets a routable address from an Elastic IP, not from the
  # subnet, so instances launched here are not public by default.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-public"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# The private route table has only the implicit local route: no path to the
# internet gateway, so the private subnet cannot reach or be reached from
# outside the VPC.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
