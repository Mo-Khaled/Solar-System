# Configuration for AWS Provider
provider "aws" {
  region = var.aws_region
}

# --- 1. VPC, Subnets, and Networking ---

# VPC
resource "aws_vpc" "lab_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_tag}-VPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "${var.project_tag}-IGW"
  }
}

# Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Public Subnets (2)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = var.public_subnets_cidr[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # Critical for the NGINX instances to access the internet via IGW

  tags = {
    Name = "PublicSubnet-${count.index + 1}"
  }
}

# Private Subnets (2)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.lab_vpc.id
  cidr_block        = var.private_subnets_cidr[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "PrivateSubnet-${count.index + 1}"
  }
}

# EIP for NAT Gateway (Must be in a Public Subnet)
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.project_tag}-NATEIP"
  }
}

# NAT Gateway (Deployed in the first Public Subnet)
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_tag}-NATGW"
  }
}

# Public Route Table (IGW Route)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_tag}-Public-RT"
  }
}

# Private Route Table (NAT Route)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "${var.project_tag}-Private-RT"
  }
}

# Associate Public Subnets with Public RT
resource "aws_route_table_association" "public_rt_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Associate Private Subnets with Private RT
resource "aws_route_table_association" "private_rt_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# --- 2. Security Groups (SGs) ---

# SG for Public ALB Access (Internet to ALB)
resource "aws_security_group" "alb_access" {
  name        = "SG-ALB-Access-${var.project_tag}"
  description = "Allow HTTP from the internet to the ALB"
  vpc_id      = aws_vpc.lab_vpc.id

  ingress {
    description = "HTTP from Internet"
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
}

# SG for NGINX Web Tier (ALB to EC2)
resource "aws_security_group" "web_nginx_tier" {
  name        = "SG-Web-NGINX-Tier-${var.project_tag}"
  description = "Allow HTTP from ALB and SSH access"
  vpc_id      = aws_vpc.lab_vpc.id

  # Rule 1: Allow HTTP from the ALB SG
  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_access.id]
  }

  # Rule 2: Allow SSH for management (restrict source as needed)
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Change to your IP for production
  }

  # Egress for updates/downloads (via NAT GW)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG for Internal NLB Target (App Tier Placeholder)
resource "aws_security_group" "internal_nlb" {
  name        = "SG-Internal-NLB-${var.project_tag}"
  description = "Allows traffic from VPC to the internal NLB targets"
  vpc_id      = aws_vpc.lab_vpc.id

  ingress {
    description = "Allow HTTP from VPC CIDR"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 3. Launch Template (NGINX Automation) ---

# Data source for the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-minimal-*x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Launch Template for NGINX instances
resource "aws_launch_template" "nginx_web_tier" {
  name_prefix   = "LT-NGINX-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
      volume_type = "gp3"
    }
  }

  # Use file() function to embed the bash script as User Data
  user_data = base64encode(file("nginx_install.sh"))

  vpc_security_group_ids = [aws_security_group.web_nginx_tier.id]

  # Optional: Replace with your key pair name if needed for debugging
  # key_name = "your-key-pair-name"

  tags = {
    Name = "NGINX-Web-Template"
  }
}

# --- 4. Public Application Load Balancer (ALB) ---

# Target Group for the NGINX Web Tier
resource "aws_lb_target_group" "nginx_web_tg" {
  name     = "TG-NGINX-Web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.lab_vpc.id

  health_check {
    path = "/"
    protocol = "HTTP"
  }

  tags = {
    Name = "TG-NGINX-Web"
  }
}

# Public ALB
resource "aws_lb" "public_alb" {
  name               = "ALB-Public-Web"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_access.id]
  subnets            = aws_subnet.public[*].id # Deployed to Public Subnets

  tags = {
    Name = "ALB-Public-Web"
  }
}

# ALB Listener (Listens on port 80 and forwards to Target Group)
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.public_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_web_tg.arn
  }
}

# --- 5. Auto Scaling Group (ASG) ---

resource "aws_autoscaling_group" "nginx_asg" {
  name                      = "ASG-NGINX-Web-Tier"
  desired_capacity          = var.asg_desired_capacity
  min_size                  = var.asg_min_capacity
  max_size                  = var.asg_max_capacity
  vpc_zone_identifier       = aws_subnet.public[*].id # Deploy to Public Subnets
  target_group_arns         = [aws_lb_target_group.nginx_web_tg.arn]

  launch_template {
    id      = aws_launch_template.nginx_web_tier.id
    version = "$Latest"
  }

  # Health Check configuration
  health_check_type          = "ELB"
  health_check_grace_period  = 300 # Give instances 5 minutes to boot and pass health check

  tags = [
    {
      key                 = "Name"
      value               = "NGINX-ASG-Instance"
      propagate_at_launch = true
    },
  ]
}

# Optional: ASG Scaling Policy
resource "aws_autoscaling_policy" "cpu_scale_out" {
  name                   = "ScaleOut-CPU-50-Percent"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.nginx_asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0 # Target 50% CPU utilization
  }
}

# --- 6. Internal Network Load Balancer (NLB) ---

# Target Group for the Internal App Tier Placeholder
resource "aws_lb_target_group" "internal_app_tg" {
  name     = "TG-Internal-App"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.lab_vpc.id

  # Health check for the NLB target group
  health_check {
    protocol = "TCP"
    port     = 80
    healthy_threshold = 3
    unhealthy_threshold = 3
    timeout = 5
    interval = 10
  }

  tags = {
    Name = "TG-Internal-App"
  }
}

# Internal NLB
resource "aws_lb" "internal_nlb" {
  name               = "NLB-Internal-App"
  internal           = true # Internal ELB
  load_balancer_type = "network"
  subnets            = aws_subnet.private[*].id # Deployed to Private Subnets

  tags = {
    Name = "NLB-Internal-App"
  }
}

# NLB Listener (Listens on TCP 80 and forwards to Internal Target Group)
resource "aws_lb_listener" "internal_listener" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal_app_tg.arn
  }
}

# --- 7. Outputs ---

output "public_alb_dns_name" {
  description = "The DNS name of the Public Application Load Balancer"
  value       = aws_lb.public_alb.dns_name
}

output "internal_nlb_dns_name" {
  description = "The DNS name of the Internal Network Load Balancer"
  value       = aws_lb.internal_nlb.dns_name
}