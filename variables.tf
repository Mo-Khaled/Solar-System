# AWS Region
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

# General Tags
variable "project_tag" {
  description = "Project name tag"
  type        = string
  default     = "TwoTierNginxASG"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Subnet CIDR blocks across two availability zones
variable "public_subnets_cidr" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets_cidr" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# Instance Configuration
variable "instance_type" {
  description = "EC2 Instance type for ASG"
  type        = string
  default     = "t2.micro"
}

# ASG Configuration
variable "asg_desired_capacity" {
  description = "Desired capacity for the NGINX ASG"
  type        = number
  default     = 1
}

variable "asg_min_capacity" {
  description = "Minimum capacity for the NGINX ASG"
  type        = number
  default     = 1
}

variable "asg_max_capacity" {
  description = "Maximum capacity for the NGINX ASG"
  type        = number
  default     = 2
}