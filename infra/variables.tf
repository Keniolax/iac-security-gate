variable "region" {
  description = "AWS region for the lab."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for every resource name, so the lab is easy to find and delete by hand."
  type        = string
  default     = "seceng-iac-gate"
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (holds the web server)."
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (no route to the internet)."
  type        = string
  default     = "10.20.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone for both subnets."
  type        = string
  default     = "us-east-1a"
}
