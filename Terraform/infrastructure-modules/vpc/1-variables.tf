variable "project" {
    description = "The name of the project"
    type        = string
}

variable "environment" {
    description = "The environment"
    type        = string
}

variable "vpc_cidr_block" {
    description = "The CIDR block for the VPC"
    type        = string
    default     = "10.0.0.0/16"
}

variable "private-subnets" {
    description = "The CIDR blocks for the private subnets"
    type        = list(string)
   #default     = ["10.0.128.0/20", "10.0.144.0/20"]
}

variable "public-subnets" {
    description = "The CIDR blocks for the public subnets"
    type        = list(string)
    #default     = ["10.0.0.0/20", "10.0.16.0/20"]
}


variable "azs" {
    description = "The availability zones"
    type        = list(string)
    #default     = ["us-east-1a", "us-east-1b"]
}